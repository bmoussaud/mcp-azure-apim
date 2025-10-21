extension graphBeta

param appName string
param today string = utcNow()

resource application 'Microsoft.Graph/applications@beta' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADMyOrg'
  owners: {
    relationships: [deployer().objectId]
  }
  // // BadRequest: New password credentials must be generated using service actions. Graph client request id:
  // passwordCredentials: [
  //   {
  //     displayName: 'default'
  //     endDateTime: dateTimeAdd(today, 'P10D') // 10 days
  //   }
  // ]
  api: {
    oauth2PermissionScopes: [
      {
        id: guid(subscription().id, appName, 'access_as_user')
        adminConsentDescription: 'Allows the app to access setlistfm as the signed-in user.'
        adminConsentDisplayName: 'Access setlistfm as user'
        isEnabled: true
        type: 'User'
        value: 'access_as_user'
        userConsentDescription: 'Allow the application to access setlistfm on your behalf.'
        userConsentDisplayName: 'Access setlistfm'
      }
    ]
    preAuthorizedApplications: [
      {
        appId: '04b07795-8ddb-461a-bbee-02f9e1bf7b46' // Azure CLI
        permissionIds: [
          guid(subscription().id, appName, 'access_as_user')
        ]
      }
    ]
  }
  /* sAMPLE
  appRoles: [
    {
      id: guid(subscription().id, 'apim-auth-api', 'APIMAuth.Members')
      displayName: 'APIMAuth.Members'
      description: 'Allow users to access members permissions of API, whitch is: Can call "Get random color" operation'
      value: 'APIMAuth.Members'
      allowedMemberTypes: [
        'User'
        'Application'
      ]
      isEnabled: true
    }
    {
      id: guid(subscription().id, 'apim-auth-api', 'APIMAuth.Admins')
      displayName: 'APIMAuth.Admins'
      description: 'Allow users to access admin permissions of API, whicth is can Post "Reset colors" operation'
      value: 'APIMAuth.Admins'
      allowedMemberTypes: [
        'User'
        'Application'
      ]
      isEnabled: true
    }
  ]
    */
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

  // Application ID URI from "Expose an API"
  identifierUris: [
    'api://${application.appId}'
  ]
}

output appId string = application.appId
output appObjectId string = application.id
output servicePrincipalId string = servicePrincipal.id
// Note: App secret must be created manually or via deployment script due to Graph API restrictions
// output appSecret string = 'Create manually via Azure CLI: az ad app credential reset --id ${application.appId}'
