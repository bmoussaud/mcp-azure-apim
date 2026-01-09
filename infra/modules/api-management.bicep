@description('The location into which the API Management resources should be deployed.')
param location string

@description('The name of the API Management service instance to create. This must be globally unique.')
param serviceName string

@description('The name of the API publisher. This information is used by API Management.')
param publisherName string

@description('The email address of the API publisher. This information is used by API Management.')
param publisherEmail string

@description('The name of the Application Insights instance to use for logging and monitoring API Management. This must be an existing Application Insights resource.')
param aiName string

@description('The name of the SKU to use when creating the API Management service instance. This must be a SKU that supports virtual network integration.')
param skuName string

@description('The number of worker instances of your API Management service that should be provisioned.')
param skuCount int

param tags object = {}

resource aiParent 'Microsoft.Insights/components@2020-02-02' existing = {
  name: aiName
}

resource apiManagementService 'Microsoft.ApiManagement/service@2024-10-01-preview' = {
  name: serviceName
  location: location
  sku: {
    name: skuName
    capacity: skuCount
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
  }

  resource aiLogger 'loggers' = {
    name: 'apim-logger'
    properties: {
      loggerType: 'applicationInsights'
      description: 'Application Insights logger'
      credentials: {
        instrumentationKey: aiParent.properties.InstrumentationKey
      }
    }
  }

  //define a new product 'Starter' with a subscription required
  resource starterProduct 'products' = {
    name: 'Starter'
    properties: {
      displayName: 'Starter'
      description: 'Starter product'
      terms: 'Subscription is required for this product.'
    }
  }

  //define a new Product 'Unlimited' with no subscription required
  resource unlimitedProduct 'products' = {
    name: 'Unlimited'
    properties: {
      displayName: 'Unlimited'
      description: 'Unlimited product'
      terms: 'No subscription required for this product.'
    }
  }

  resource allAPIsSubscription 'subscriptions' = {
    name: 'allAPIs'
    properties: {
      allowTracing: false
      displayName: 'Built-in all-access subscription'
      //ownerId:
      state: 'active'
      scope: '/apis'
    }
  }

  //Allow the customs metrics at the application insight level.
  //https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-app-insights?tabs=rest#emit-custom-metrics
  resource applicationinsights 'diagnostics' = {
    name: 'applicationinsights'
    properties: {
      metrics: true
      loggerId: aiLogger.id
    }
  }
}

//output apiManagementInternalIPAddress string = apiManagementService.properties.publicIPAddresses[0]
output apiManagementIdentityPrincipalId string = apiManagementService.identity.principalId
output name string = apiManagementService.name
output apiManagementGatewayUrl string = apiManagementService.properties.gatewayUrl
output apiManagementProxyHostName string = apiManagementService.properties.hostnameConfigurations[0].hostName
//output apiManagementDeveloperPortalHostName string = replace(apiManagementService.properties.developerPortalUrl, 'https://', '')
output aiLoggerId string = apiManagementService::aiLogger.id
output aiLoggerName string = apiManagementService::aiLogger.name
output apimId string = apiManagementService.id
output apiAdminSubscriptionKey string = apiManagementService::allAPIsSubscription.listSecrets().primaryKey
