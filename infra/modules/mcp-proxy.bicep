@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apimName string

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

param mcp object = {
  name: 'bicep-mslearn-mcp'
  description: 'bla bla'
  displayName: ''
  path: 'bicep-setlistfm-mcp-path'
  url: 'https://learn.microsoft.com'
  uriTemaplate: '/api/mcp'
}


resource mcpBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: mcp.name
  parent: apimService
  properties: {
    description: 'Backend for ${mcp.name}'
    url: mcp.url
    protocol: 'http'
  }
}

resource apimApi 'Microsoft.ApiManagement/service/apis@2024-10-01-preview' = {
  name: mcp.name
  parent: apimService
  properties: {
    description: mcp.description
    displayName: mcp.name
    path: mcp.path
    protocols: [
      'https'
    ]
    type: 'mcp'
    backendId: mcpBackend.name
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'Ocp-Apim-Subscription-Key'
    }
    subscriptionRequired: false
    mcpProperties: {
          endpoint: {
            mcp: {
              uriTemplate: mcp.uriTemaplate
            }
          }
        }
    

  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = if (contains(mcp, 'policyXml') && !empty(mcp.policyXml)) {
  name: 'policy'
  parent: apimApi
  properties: {
    format: 'rawxml' // only use 'rawxml' for policies as it's what APIM expects and means we don't need to escape XML characters
    value: mcp.policyXml
  }
}

output mcpName string = apimApi.properties.displayName
output mcpResourceId string = apimApi.id
output mcpPath string = apimApi.properties.path
