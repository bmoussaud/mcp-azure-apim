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
  uriTemplate: '/api/mcp'
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

resource mcpApi  'Microsoft.ApiManagement/service/apis@2024-10-01-preview' = {
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
      transportType: 'streamable'
      endpoint: {
        mcp: {
          uriTemplate: mcp.uriTemplate
        }
      }
    }
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    isCurrent: true
    

  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = if (contains(mcp, 'policyXml') && !empty(mcp.policyXml)) {
  name: 'policy'
  parent: mcpApi
  properties: {
    format: 'rawxml' // only use 'rawxml' for policies as it's what APIM expects and means we don't need to escape XML characters
    value: mcp.policyXml
  }
}




// Create the PRM (Protected Resource Metadata) endpoint within MCP server
resource mcpPrmOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: mcpApi
  name: 'mcp-prm-operation'
  properties: {
    displayName: 'Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource'
    description: 'Protected Resource Metadata endpoint (RFC 9728)'
  }
}


resource mcpPrmOperationPolicy  'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = if (contains(mcp, 'prmPolicyXml') && !empty(mcp.prmPolicyXml)) {
  name: 'policy'
  parent: mcpPrmOperation
  properties: {
    format: 'rawxml' // only use 'rawxml' for policies as it's what APIM expects and means we don't need to escape XML characters
    value: mcp.prmPolicyXml
  }
}


resource dynamicDiscovery 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: 'mcp-prm-dynamic-discovery'
  properties: {
    displayName: 'Dynamic Discovery Endpoint'
    description: 'Model Context Protocol Dynamic Discovery Endpoint'
    subscriptionRequired: false
    path: '/.well-known/oauth-protected-resource'
    protocols: [
      'https'
    ]
  }
}


// Create the PRM (Protected Resource Metadata in the global discovery) endpoint - RFC 9728
resource mcpPrmDiscoveryOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: dynamicDiscovery
  name: 'mcp-prm-discovery-operation'
  properties: {
    displayName: 'Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/${mcp.path}'
    description: 'Protected Resource Metadata endpoint (RFC 9728)'
  }
}

// Apply specific policy for the PRM endpoint (anonymous access)
resource mcpPrmGlobalPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = if (contains(mcp, 'prmPolicyXml') && !empty(mcp.prmPolicyXml)) {
  parent: mcpPrmDiscoveryOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: mcp.prmPolicyXml
  }
}

output mcpName string = mcpApi.properties.displayName
output mcpResourceId string = mcpApi.id
output mcpPath string = mcpApi.properties.path
