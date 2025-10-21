// Creates an Azure AI resource with proxied endpoints for the Azure AI services provider

@description('Azure region of the deployment')
param location string

@description('AI Foundry name')
param aiFoundryName string

@description('AI Project name')
param aiProjectName string

@description('AI Project display name')
param aiProjectFriendlyName string = aiProjectName

@description('AI Project description')
param aiProjectDescription string

param applicationInsightsName string

param customKey object = {
  name: 'xxxx'
  target: 'https://api.xxxx.com/'
  authKey: ''
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-07-01-preview' existing = {
  name: aiFoundryName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-07-01-preview' = {
  parent: aiFoundry
  name: aiProjectName
  location: location
  properties: {
    description: aiProjectFriendlyName
    displayName: aiProjectDescription
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource connectionAppInsight 'connections' = {
    name: 'appinsights-connection'
    properties: {
      category: 'AppInsights'
      target: applicationInsights.id
      authType: 'ApiKey'
      //isSharedToAll: true
      credentials: {
        key: applicationInsights.properties.ConnectionString
      }
      metadata: {
        ApiType: 'Azure'
        ResourceId: applicationInsights.id
      }
    }
  }
}

resource connectionCustom 'Microsoft.CognitiveServices/accounts/connections@2025-07-01-preview' = {
  name: '${customKey.name}-customkey-connection'
  parent: aiFoundry
  properties: {
    category: 'CustomKeys'
    target: customKey.target
    authType: 'CustomKeys'
    //isSharedToAll: true
    credentials: {
      keys: {
        'x-api-key': customKey.authKey
      }
    }
    metadata: {}
  }
}

resource currentUserIsAiProjectUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(project.id, deployer().objectId, azureAIUserRoleDefinitionId)
  scope: project
  properties: {
    principalId: deployer().objectId
    roleDefinitionId: azureAIUserRoleDefinitionId
    principalType: 'User' // 'ServicePrincipal' // should be a variable
    description: 'The current user is able to manage the AI Foundry Project; such as creating agents.'
  }
}

var azureAIUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d'
)

output projectName string = project.name
output projectId string = project.id
output projectIdentityPrincipalId string = project.identity.principalId
output projectEndpoint string = project.properties.endpoints['AI Foundry API']
