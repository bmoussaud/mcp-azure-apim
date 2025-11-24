@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apimName string

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

param mcp object = {
  name: 'bicep-setlistfm-mcp'
  description: 'bla bla'
  displayName: ''
  path: 'bicep-setlistfm-mcp-path'
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
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'Ocp-Apim-Subscription-Key'
    }
    subscriptionRequired: false
    mcptools: [
      {
        name:'searchForArtists'
        description:'Search for artists'
        operationId:'/subscriptions/9479b396-5d3e-467a-b89f-ba8400aeb7dd/resourceGroups/rg-mcp-apim-dev/providers/Microsoft.ApiManagement/service/apim-7ephb7ltz2uu2/apis/setlistfm/operations/resource__1-0_search_artists_getArtists_GET'
      }
    ]

  }
}
