extension graphBeta

param appName string
param appDescription string 
param preAuthorizedApplication string = ''
param permission string
param redirectUris array = []

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

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
        id: guid(subscription().id, appName, permission)
        adminConsentDescription: 'Allows access to the ${appDescription} as the signed-in user.'
        adminConsentDisplayName: 'Access ${appDescription}'
        isEnabled: true
        type: 'User'
        value: permission
        userConsentDescription: 'Allow access to the ${appDescription} on your behalf'
        userConsentDisplayName: 'Access ${appDescription}'
      }
    ]
    
    preAuthorizedApplications:  (preAuthorizedApplication != '')? [
      {
        appId: preAuthorizedApplication // VS code
        //appId: '04b07795-8ddb-461a-bbee-02f9e1bf7b46' // Azure CLI
        //appId: ''aebc6443-996d-45c2-90f0-388ff96faa56' // VS Code
        permissionIds: [
          guid(subscription().id, appName, permission)
        ]
      }
    ] : []
  }
  web: {
    redirectUris: redirectUris
    implicitGrantSettings: {
      enableIdTokenIssuance: false
      enableAccessTokenIssuance: false
    }
  }
}

//define the service principal for the application and assign ownership to the deployer
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
output mcpAppTenantId string = tenantId
// Note: App secret must be created manually or via deployment script due to Graph API restrictions
// output appSecret string = 'Create manually via Azure CLI: az ad app credential reset --id ${application.appId}'
