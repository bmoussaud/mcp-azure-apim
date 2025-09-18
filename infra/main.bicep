@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'francecentral'

@description('Location for AI Foundry resources.')
param aiFoundryLocation string = 'switzerlandnorth' //'westus' 'switzerlandnorth' swedencentral

@description('Name of the resource group to deploy to.')
param rootname string = 'mcp-azure-apim'

@description('Credential end date/time for the application (defaults to two years from deployment time).')
param credentialEndDateTime string = dateTimeAdd(utcNow(), 'P2Y')

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

module setlistfmApiKeyNV 'modules/apim/v1/named-value.bicep' = {
  name: 'setlistfm-api-key-nv'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'setlisfm-api-key'
    namedValueValue: '4b15bd76-3455-4f06-b606-293848fbad49'
    namedValueIsSecret: true
  }
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

extension graphBeta

var appName = '${rootname}-app'
param today string = utcNow()
resource application 'Microsoft.Graph/applications@beta' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADMyOrg'
  owners: {
    relationships: [deployer().objectId]
  }
  passwordCredentials: [
    {
      displayName: 'MyClientSecret'
      endDateTime: dateTimeAdd(today, 'P1Y')
    }
  ]
  api: {
    oauth2PermissionScopes: [
      {
        id: guid(subscription().id, '${rootname}-app', 'access_as_user')
        adminConsentDescription: 'Allows the app to access setlistfm as the signed-in user.'
        adminConsentDisplayName: 'Access setlistfm as user'
        isEnabled: true
        type: 'User'
        value: 'access_as_user'
        userConsentDescription: 'Allow the application to access setlistfm on your behalf.'
        userConsentDisplayName: 'Access setlistfm'
      }
    ]
    preAuthorizedApplications: [
      {
        appId: '04b07795-8ddb-461a-bbee-02f9e1bf7b46' // Azure CLI
        permissionIds: [
          guid(subscription().id, '${rootname}-app', 'access_as_user')
        ]
      }
    ]
  }
  /* sAMPLE
  appRoles: [
    {
      id: guid(subscription().id, 'apim-auth-api', 'APIMAuth.Members')
      displayName: 'APIMAuth.Members'
      description: 'Allow users to access members permissions of API, whitch is: Can call "Get random color" operation'
      value: 'APIMAuth.Members'
      allowedMemberTypes: [
        'User'
        'Application'
      ]
      isEnabled: true
    }
    {
      id: guid(subscription().id, 'apim-auth-api', 'APIMAuth.Admins')
      displayName: 'APIMAuth.Admins'
      description: 'Allow users to access admin permissions of API, whicth is can Post "Reset colors" operation'
      value: 'APIMAuth.Admins'
      allowedMemberTypes: [
        'User'
        'Application'
      ]
      isEnabled: true
    }
  ]
    */
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@beta' = {
  appId: application.appId
  accountEnabled: true
  servicePrincipalType: 'Application'
}

resource applicationOveride 'Microsoft.Graph/applications@beta' = {
  uniqueName: appName
  displayName: appName
  signInAudience: application.signInAudience
  api: application.api

  // Application ID URI from "Expose an API"
  identifierUris: [
    'api://${application.appId}'
  ]
}

output PROJECT_ENDPOINT string = aiFoundryProject.outputs.projectEndpoint
output AZURE_AI_INFERENCE_ENDPOINT string = aiFoundry.outputs.aiFoundryInferenceEndpoint
output AZURE_AI_INFERENCE_API_KEY string = aiFoundry.outputs.aiFoundryInferenceKey
output MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_LOG_LEVEL string = 'DEBUG'

output APIM_NAME string = apiManagement.outputs.name
output SETLISTAPI_ENDPOINT string = 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}'
output SETLISTAPI_SUBSCRIPTION_KEY string = setlistFmApi.outputs.subscriptionPrimaryKey
output SETLISTAPI_MCP_ENDPOINT string = 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}-mcp/mcp'
output AZURE_AI_AGENT_ENDPOINT string = aiFoundryProject.outputs.projectEndpoint
output AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output AZURE_AI_AGENT_API_VERSION string = '2024-02-15-preview'
output OAUTH_APP_ID string = applicationOveride.appId
output OAUTH_TENANT_ID string = tenant().tenantId
output OAUTH_CLIENT_SECRET string = application.passwordCredentials[0].secretText
