@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'francecentral'

@description('Location for AI Foundry resources.')
param aiFoundryLocation string = 'swedencentral' //'westus' 'switzerlandnorth' swedencentral

@description('Name of the resource group to deploy to.')
param rootname string = 'mcp-azure-apim'

@description('SetlistFM API Key for MCP SetlistFM microservice.')
@secure()
param setlistfmApiKey string

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

module setlistFmApi 'modules/apim/v1/api.bicep' = {
  name: 'setlistfm-api'
  params: {
    apimName: apiManagement.outputs.name
    appInsightsId: applicationInsights.outputs.aiId
    appInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    api: {
      name: 'setlistfm'
      description: 'SetlistFM API'
      displayName: 'SetlistFM API'
      path: '/setlistfm'
      serviceUrl: 'https://api.setlist.fm/rest'
      subscriptionRequired: true
      tags: ['setlistfm', 'api', 'music', 'setlist']
      policyXml: loadTextContent('../src/apim/setlistfm/policy-setlistfm.xml')
      openApiJson: loadTextContent('../src/apim/setlistfm/openapi-setlistfm.json') // Ensure this file exists at the specified path or update the path accordingly
    }
  }
}
@description('This is the built-in Key Vault Secrets Officer role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user')
resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}
@description('Assigns the API Management service the role to browse and read the keys of the Key Vault to the APIM')
resource keyVaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, apiManagement.name, keyVaultSecretsUserRoleDefinition.id)
  scope: kv
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
  }
}

module setlistFmNvApiKey 'modules/nvkv.bicep' = {
  name: 'setlisfm-api-key'
  params: {
    apimName: apiManagement.outputs.name
    keyName: 'setlisfm-api-key'
    keyVaultName: kv.name
    secretName: secretSetlistFMApiKey.name
  }
  dependsOn: [
    keyVaultSecretUserRoleAssignment //this role assignment is needed to allow the API Management service to access the Key Vault
  ]
}

module applicationInsights 'modules/app-insights.bicep' = {
  name: 'application-insights'
  params: {
    location: location
    workspaceName: logAnalyticsWorkspace.outputs.name
    applicationInsightsName: '${rootname}-app-insights'
  }
}

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    location: location
    logAnalyticsName: '${rootname}-log-analytics'
  }
}

module eventHub 'modules/event-hub.bicep' = {
  name: 'event-hub'
  params: {
    location: location
    eventHubNamespaceName: '${rootname}-ehn-${uniqueString(resourceGroup().id)}'
    eventHubName: '${rootname}-eh-${uniqueString(resourceGroup().id)}'
  }
}

@description('Creates an Azure Key Vault.')
resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: 'kv${uniqueString(rootname, resourceToken)}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    //publicNetworkAccess: 'Enabled'
  }
}

@description('Creates an Azure Key Vault Secret APPLICATIONINSIGHTS-CONNECTION-STRING.')
resource secretAppInsightCS 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: kv
  name: 'APPLICATIONINSIGHTS-CONNECTIONSTRING'
  properties: {
    value: applicationInsights.outputs.connectionString
  }
}

@description('Creates an Azure Key Vault Secret APPINSIGHTS-INSTRUMENTATIONKEY.')
resource secretAppInsightInstKey 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: kv
  name: 'APPINSIGHTS-INSTRUMENTATIONKEY'
  properties: {
    value: applicationInsights.outputs.instrumentationKey
  }
}

@description('Creates an Azure Key Vault Secret SetListFM API KEY.')
resource secretSetlistFMApiKey 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: kv
  name: 'SETLISTFM-API-KEY'
  properties: {
    value: setlistfmApiKey
  }
}

module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'aiFoundryModel'
  params: {
    name: 'foundry-${rootname}-${aiFoundryLocation}-${environmentName}'
    location: aiFoundryLocation
    modelDeploymentsParameters: [
      {
        name: '${rootname}-gpt-4.1-mini'
        model: 'gpt-4.1-mini'
        capacity: 1000
        deployment: 'GlobalStandard'
        version: '2025-04-14'
        format: 'OpenAI'
      }
    ]
  }
}

module aiFoundryProject 'modules/ai-foundry-project.bicep' = {
  name: 'aiFoundryProject'
  params: {
    location: aiFoundryLocation
    aiFoundryName: aiFoundry.outputs.aiFoundryName
    aiProjectName: 'prj-${rootname}-${aiFoundryLocation}-${environmentName}'
    aiProjectFriendlyName: 'Setlistfy Project ${environmentName}'
    aiProjectDescription: 'Agents to help to manage setlist and music events.'

    applicationInsightsName: applicationInsights.outputs.name

    customKey: {
      name: setlistFmApi.outputs.apiName
      target: 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}'
      authKey: setlistFmApi.outputs.subscriptionPrimaryKey
    }
  }
}

module apiManagement 'modules/api-management.bicep' = {
  name: 'api-management'
  params: {
    location: location
    serviceName: '${rootname}-api-management-${environmentName}'
    publisherName: 'Setlistfy Apps'
    publisherEmail: '${rootname}@contososuites.com'
    skuName: 'Basicv2'
    skuCount: 1
    aiName: applicationInsights.outputs.aiName
  }
  dependsOn: [
    eventHub
  ]
}

output PROJECT_ENDPOINT string = aiFoundryProject.outputs.projectEndpoint
output AZURE_AI_INFERENCE_ENDPOINT string = aiFoundry.outputs.aiFoundryInferenceEndpoint
output AZURE_AI_INFERENCE_API_KEY string = aiFoundry.outputs.aiFoundryInferenceKey
output MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_LOG_LEVEL string = 'DEBUG'
output SETLISTFM_API_KEY string = setlistfmApiKey
output APIM_NAME string = apiManagement.outputs.name
output SETLISTAPI_ENDPOINT string = 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}'
output SETLISTAPI_SUBSCRIPTION_KEY string = setlistFmApi.outputs.subscriptionPrimaryKey
