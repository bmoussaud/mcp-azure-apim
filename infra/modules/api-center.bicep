@description('The location into which the API Center resources should be deployed.')
param location string

@description('The name of the API Center instance to create.')
param apiCenterName string

@description('The name of the API Management service to link to the API Center.')
param apimServiceName string

@description('The resource ID of the API Management service.')
param apimResourceId string

param tags object = {}

resource apiCenterService  'Microsoft.ApiCenter/services@2024-06-01-preview'= {
  name: apiCenterName
  location: location
  tags: tags
  properties: {}
  identity: {
    type: 'SystemAssigned'
  }
}

// Azure RBAC role definition IDs for API Center access
var apiCenterReaderRoleId = '71522526-b88f-4d52-b57f-d31fc3546d0d'
var apiCenterContributorRoleId = '6cba8790-29c5-48e5-bab1-c7541b01cb04'

var roles = [
  apiCenterReaderRoleId
  apiCenterContributorRoleId
]

@description('Role assignments for API Center service principal - Grants necessary permissions for API inventory operations')
resource apimRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(subscription().id, resourceGroup().id, resourceGroup().name, apiCenterService.id, apiCenterService.name, role)
    scope: resourceGroup()
    properties: {
      principalId: apiCenterService.identity.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    }
  }
]


@description('Default workspace for API Center - Organizes APIs and provides collaboration space')
resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  parent: apiCenterService
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace'
  }
}

@description('API source integration - Links API Management service to API Center for automated inventory')
resource apiResource 'Microsoft.ApiCenter/services/workspaces/apiSources@2024-06-01-preview' = {
  name: apimServiceName
  parent: apiCenterWorkspace
  properties: {
    azureApiManagementSource: {
      resourceId: apimResourceId
    }
    importSpecification: 'always'
  }
  dependsOn: [
    apimRoleAssignments
  ]
}

/* resource apimEnv 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: 'azure-api-management'
  properties: {
    title: 'API Management Environment'
    description: 'Environment for APIs from ${apimServiceName}'
    kind: 'Production'
    server: { 
      type: 'Azure API Management'
    }
  }
}  */
/* 
resource apimMetadataSchema 'Microsoft.ApiCenter/services/metadataSchemas@2024-03-01' = {
  name: 'apim-source'
  parent: apiCenterService
  properties: {
    assignedTo: [
      {
        entity: 'api'
        required: false
        deprecated: false
      }
    ]
    schema: '''
    {
      "type": "object",
      "properties": {
        "apimServiceName": {
          "type": "string",
          "title": "APIM Service Name"
        },
        "apimResourceId": {
          "type": "string",
          "title": "APIM Resource ID"
        }
      }
    }
    '''
  }
}

 */
output apiCenterName string = apiCenterService.name
output apiCenterId string = apiCenterService.id
output apiCenterRuntimeEndpoint string = apiCenterService.properties.provisioningState == 'Succeeded' ? 'https://${apiCenterService.name}.data.${location}.azure-apicenter.ms' : ''
output apiCenterPortalEndpoint string = apiCenterService.properties.provisioningState == 'Succeeded' ? 'https://${apiCenterService.name}.portal.${location}.azure-apicenter.ms' : ''
