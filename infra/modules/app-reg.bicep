extension graphBeta

param appName string
param appDescription string 
param preAuthorizedApplication string = ''
param permission string
param redirectUris array = []

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
