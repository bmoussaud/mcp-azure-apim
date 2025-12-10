param name string
param location string

@description('Model deployments for OpenAI')
param modelDeploymentsParameters array

param tags object = {}

@description('Optional: Role Definition ID (GUID) for the Azure AI User (or equivalent) role. Leave empty to skip automatic role assignment. Example (preview – verify in your tenant): Azure AI User role id.')
param azureAiUserRoleDefinitionId string = ''

// Generate a deterministic GUID for the role assignment (only if a role id is provided)
var azureAiUserRoleAssignmentName = empty(azureAiUserRoleDefinitionId) ? '' : guid(name, 'azure-ai-user', deployer().objectId)

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-09-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true
    // Defines developer API endpoint subdomain
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    //disableLocalAuth: true
  }

  @batchSize(1)
  resource modelDeployments 'deployments' = [
    for deployment in modelDeploymentsParameters: {
      name: deployment.name
      sku: {
        capacity: deployment.capacity
        name: deployment.deployment
      }
      properties: {
        model: {
          format: deployment.format
          name: deployment.model
          version: deployment.version
        }
      }
    }
  ]
}

output aiFoundryId string = aiFoundry.id

output modelDeploymentsName string = modelDeploymentsParameters[0].name
output aiFoundryName string = aiFoundry.name
output aiFoundryEndpoint string = aiFoundry.properties.endpoint
output aiFoundryLocation string = aiFoundry.location
output aiFoundryInferenceEndpoint string = '${aiFoundry.properties.endpoints['Azure AI Model Inference API']}models'
output defaultModelDeploymentName string = modelDeploymentsParameters[0].name
//output aiFoundryInferenceKey string = aiFoundry.listKeys().key1
// Output the role assignment name if created (empty string otherwise)
