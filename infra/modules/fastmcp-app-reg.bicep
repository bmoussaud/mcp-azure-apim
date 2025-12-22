extension graphBeta

param appName string
param today string = utcNow()

resource application  'Microsoft.Graph/applications@beta' = {
  uniqueName: appName
  displayName: appName
  
  signInAudience: 'AzureADMyOrg'
  owners: {
    relationships: [deployer().objectId]
  }
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: guid(subscription().id, appName, 'mcp-access')
        adminConsentDescription: 'Allows access to the FastMCP server as the signed-in user.'
        adminConsentDisplayName: 'Access FastMCP Server'
        isEnabled: true
        type: 'User'
        value: 'mcp-access'
        userConsentDescription: 'Allow access to the FastMCP server on your behalf'
        userConsentDisplayName: 'Access FastMCP Server'
      }
    ]
    
    preAuthorizedApplications: [
      {
        appId: 'd4f80fbc-bfc9-4c81-849f-16ced65f5f0f' // VS code
        //appId: '04b07795-8ddb-461a-bbee-02f9e1bf7b46' // Azure CLI
        permissionIds: [
          guid(subscription().id, appName, 'mcp-access')
        ]
      }
    ]
  }
  web: {
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
    implicitGrantSettings: {
      enableIdTokenIssuance: false
      enableAccessTokenIssuance: false
    }
  }
  
 
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@beta' = {
  appId: application.appId
  accountEnabled: true
  servicePrincipalType: 'Application'
  owners: {
    relationships: [deployer().objectId]
  }
}

resource applicationOveride 'Microsoft.Graph/applications@beta' = {
  uniqueName: appName
  displayName: appName
  signInAudience: application.signInAudience
  api: application.api

  // Application ID URI from 'Expose an API'
  identifierUris: [
    'api://${application.appId}'
  ]
}

output appId string = application.appId
output appObjectId string = application.id
output servicePrincipalId string = servicePrincipal.id
// Note: App secret must be created manually or via deployment script due to Graph API restrictions
// output appSecret string = 'Create manually via Azure CLI: az ad app credential reset --id ${application.appId}'
