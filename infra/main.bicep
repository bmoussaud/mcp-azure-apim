targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources but AI Foundry.')
param location string

@description('Location for AI Foundry resources.')
param aiFoundryLocation string

@description('Configure Setlist.fm MCP API.')
param configureSetListfmMCP bool = false

@description('Configure API Center.')
param configureAPICenter bool = false

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))

var tags = {
  'azd-env-name': environmentName
}

module mslearn 'modules/mcp-proxy.bicep' = {
  name: 'mslearn-mcp'
  params: {
    apimName: apiManagement.outputs.name
    mcp:  {
      name: 'mslearn-mcp'
      description: 'Proxy to Microsoft Learn API'
      displayName: 'Microsoft Learn API MCP'
      path: 'mslearn-mcp'
      url: 'https://learn.microsoft.com/api/mcp'
      policyXml: loadTextContent('../src/apim/mslearn/mcp-policy-mslearn.xml')
      prmPolicyXml: loadTextContent('../src/apim/mslearn/mcp-prm-policy-mslearn.xml')
      uriTemplate: '/api/mcp'
    }
  } 
  dependsOn: [
    mcpMSLearnApp
    mcpTenantIdNamedValue
    APIMGatewayURLNamedValue
  ]
}

module setlistFmMCP 'modules/mcp-api.bicep' = if (configureSetListfmMCP) {
  name: 'setlistfm-mcp'
  params: {
    apimName: apiManagement.outputs.name
    apiId: setlistFmApi.outputs.apiResourceId
    mcp:  {
      name: 'setlistfm-mcp'
      description: 'Setlist.fm MCP for concert details'
      displayName: 'Setlist.fm MCP'
      path: 'setlistfm-mcp'
      policyXml: loadTextContent('../src/apim/setlistfm/mcp-policy-setlistfm.xml')
      tools :[
          {
            name:'searchForArtists'
            operationName:'resource__1-0_search_artists_getArtists_GET'
          }
          {
            name:'searchForSetlists'
            operationName:'resource__1-0_search_setlists_getSetlists_GET'
          }
        ]
    }
  }
}

module setlistFmApi 'modules/api.bicep' = {
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
      value: 'https://api.setlist.fm/docs/1.0/ui/swagger.json'
    }
  } 
  dependsOn: [ 
    setlistfmApiKeyNV
  ]
}

module spotifyApi 'modules/apim/v1/api.bicep' = {
  name: 'spotify-api'
  params: {
    apimName: apiManagement.outputs.name
    appInsightsId: applicationInsights.outputs.aiId
    appInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    api: {
      name: 'spotify'
      description: 'Spotify API'
      displayName: 'Spotify API'
      path: '/spotify'
      serviceUrl: 'https://api.spotify.com/v1'
      subscriptionRequired: true
      tags: ['spotify', 'api', 'music', 'setlist']
      policyXml: loadTextContent('../src/apim/spotify/policy-spotify.xml')
      openApiJson: loadYamlContent('../src/apim/spotify/sonallux-spotify-open-api.yml')
    }
  }
}

module spotifyMCP 'modules/mcp-api.bicep' =  {
  name: 'spotify-mcp'
  params: {
    apimName: apiManagement.outputs.name
    apiId: spotifyApi.outputs.apiResourceId
    mcp:  {
      name: 'spotify-mcp'
      description: 'Spotify MCP for music details'
      displayName: 'Spotify MCP'
      path: 'spotify-mcp'
      policyXml: loadTextContent('../src/apim/spotify/mcp-policy-spotify.xml')  
      tools :[
          {
            name:'create-playlist'
            operationName:'create-playlist'
          }
          {
            name:'get-an-album'
            operationName:'get-an-album'
          }
          {
            name:'get-an-artist'
            operationName:'get-an-artist'
          }
          {
            name:'get-playlist'
            operationName:'get-playlist'  
          }
          {
            name:'search'
            operationName:'search'
          }
          
        ]
    }
  }
}

//user-read-private, user-top-read,  user-read-email,user-library-read,user-top-read,playlist-read-private, playlist-modify-public, playlist-modify-private, user-follow-read, user-follow-modify,streaming,
//https://global.consent.azure-apim.net/redirect/6c4502ea-e075-413a-8320-c94a49577029-spotifymcp
module setlistfmApiKeyNV 'modules/named-value.bicep' = {
  name: 'setlistfm-api-key-nv'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'setlistfm-api-key'
    namedValueValue: '4b15bd76-3455-4f06-b606-293848fbad49'
    namedValueIsSecret: true
  }
}

module applicationInsights 'modules/app-insights.bicep' = {
  name: 'application-insights'
  params: {
    location: location
    workspaceName: logAnalyticsWorkspace.outputs.name
    applicationInsightsName: 'app-insights-${resourceToken}'
    tags: tags
  }
}

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    location: location
    logAnalyticsName: 'log-analytics-${resourceToken}'
    tags: tags
  }
}

module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'aiFoundryModel'
  params: {
    name: 'foundry-${resourceToken}'
    location: aiFoundryLocation
    tags: tags
    modelDeploymentsParameters: [
      {
        name: 'gpt-4.1'
        model: 'gpt-4.1'
        capacity: 1
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
    aiProjectName: 'mcp-${environmentName}'
    aiProjectFriendlyName: 'MCP Project ${environmentName}'
    aiProjectDescription: 'Agents to demonstrate the usage of MCP servers.'
    applicationInsightsName: applicationInsights.outputs.name

    mcpConnection: {
      name: '${setlistFmApi.outputs.apiName}-mcp-connection'
      target: configureSetListfmMCP ? 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmMCP.outputs.mcpPath}/mcp' : 'http://localhost:3000/mcp'
      keys: {'Ocp-Apim-Subscription-Key': setlistFmApi.outputs.subscriptionPrimaryKey}
    }
  }
}

module apiManagement 'modules/api-management.bicep' = {
  name: 'api-management'
  params: {
    location: location
    tags: tags
    serviceName: 'apim-${resourceToken}'
    publisherName: 'Setlistfy Apps'
    publisherEmail: '${environmentName}@contososuites.com'
    skuName: 'Basicv2'
    skuCount: 1
    aiName: applicationInsights.outputs.aiName
  }
}

module apiCenter 'modules/api-center.bicep' = if (configureAPICenter) {
  name: 'api-center'
  params: {
    location: location
    tags: tags
    apiCenterName: 'mcp-demo-${resourceToken}'
    apimServiceName: apiManagement.outputs.name
    apimResourceId: apiManagement.outputs.apimId
  }
}

module setlistMcpApp 'modules/setlist-mcp-app-reg.bicep' = {
  name: 'setlist-mcp-app'
  params: {
    appName: 'benoit-setlist-mcp-app-${resourceToken}'
  }
}

module fastmcpApp 'modules/fastmcp-app-reg.bicep' = {
  name: 'fastmcp-app'
  params: {
    appName: 'benoit-fastmcp-app-${resourceToken}'
  }
}

module fastMCPClientApp 'modules/app-reg.bicep' = {
  name: 'fastmcp-client-app'
  params: {
    appName: 'fastmcp-client-app-${resourceToken}'
    appDescription: 'FastMCP Client'
    permission: 'mcp-access'
  }
}

module mcpMSLearnApp 'modules/app-reg.bicep' = {
  name: 'mcp-mslearn-app'
  params: {
    appName: 'mcp-proxy-mslearn'
    appDescription: 'MCP Learn resources'
    permission: 'user_impersonate'
    preAuthorizedApplication: 'aebc6443-996d-45c2-90f0-388ff96faa56' // VS Code
  }
}

module mcpTenantIdNamedValue  'modules/named-value.bicep' = {
  name: 'mcpTenantIdNamedValue'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'McpTenantId'
    namedValueValue: tenant().tenantId
    namedValueIsSecret: false
  }
}

module mcpClientIdNamedValue 'modules/named-value.bicep' = {
  name: 'mcpClientIdNamedValue'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'McpMSLearnClientId'
    namedValueValue: mcpMSLearnApp.outputs.appId
    namedValueIsSecret: false
  }
}

module APIMGatewayURLNamedValue   'modules/named-value.bicep' = {
  name: 'APIMGatewayURLNamedValue'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'APIMGatewayURL'
    namedValueValue: apiManagement.outputs.apiManagementGatewayUrl
    namedValueIsSecret: false
  }
}

module fastMCPServerApp 'modules/app-reg.bicep' = {
  name: 'fastmcp-server-app'
  params: {
    appName: 'fastmcp-server-app-${resourceToken}'
    appDescription: 'FastMCP Server'
    permission: 'mcp-access'
    preAuthorizedApplication: fastMCPClientApp.outputs.appId
    redirectUris: [
      'http://127.0.0.1:33427'
			'http://127.0.0.1:33426'
			'http://127.0.0.1:33425'
			'http://127.0.0.1:33424'
			'http://127.0.0.1:33423'
			'http://127.0.0.1:33422'
			'http://127.0.0.1:33421'
			'http://127.0.0.1:33420'
			'http://127.0.0.1:33419'
			'http://127.0.0.1:33418'
			'https://vscode.dev/redirect'
			'http://localhost:8000/auth/callback'
    ]
  }
}


output API_CENTER_RUNTIME_ENDPOINT string = configureAPICenter ? apiCenter.outputs.apiCenterRuntimeEndpoint : ''
output API_CENTER_NAME string = configureAPICenter ? apiCenter.outputs.apiCenterName : ''
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output APIM_NAME string = apiManagement.outputs.name
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_AI_AGENT_ENDPOINT string = aiFoundryProject.outputs.projectEndpoint
output AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output AZURE_AI_INFERENCE_ENDPOINT string = aiFoundry.outputs.aiFoundryInferenceEndpoint
output AZURE_AI_MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output AZURE_AI_PROJECT_ENDPOINT string = aiFoundryProject.outputs.projectEndpoint
output AZURE_LOG_LEVEL string = 'DEBUG'
output MODEL_DEPLOYMENT_NAME string = aiFoundry.outputs.defaultModelDeploymentName
output OAUTH_APP_ID string = setlistMcpApp.outputs.appId
output OAUTH_TENANT_ID string = tenant().tenantId
output AZURE_TENANT_ID string = tenant().tenantId
output SETLISTAPI_API_ID string = setlistFmApi.outputs.apiResourceId
output SETLISTAPI_ENDPOINT string = 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}'
output SETLISTAPI_MCP_ENDPOINT string = 'https://${apiManagement.outputs.apiManagementProxyHostName}/${setlistFmApi.outputs.apiPath}-mcp/mcp'
output SETLISTAPI_SUBSCRIPTION_KEY string = setlistFmApi.outputs.subscriptionPrimaryKey
output SUBSCRIPTION_ID string = subscription().subscriptionId
output ENTRA_PROXY_AZURE_CLIENT_ID string = fastmcpApp.outputs.appId
output SETLISTFM_API_KEY string = '4b15bd76-3455-4f06-b606-293848fbad49'

output FASTMCP_SERVER_APP_ID string = fastMCPServerApp.outputs.appId
output FASTMCP_CLIENT_APP_ID string = fastMCPClientApp.outputs.appId

output MCP_MSLEARN_GATEWAY_URL string = mslearn.outputs.mcpGatewayUrl
output MCP_MSLEARN_CLIENT_ID string = mcpMSLearnApp.outputs.appId
output MCP_MSLEARN_TENANT_ID string = tenant().tenantId
output MCP_MSLEARN_SCOPE string = 'api://${mcpMSLearnApp.outputs.appId}/user_impersonate'
