// TODO: App Service Plan + App Service with VNet integration
// modules/compute/appService.bicep
// App Service Plan (Premium v3, Linux) + App Service (API)
// Outbound via VNet Integration (snet-app) — inbound via Private Endpoint (separate module)

@description('Environment for App Service')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Resource ID of snet-app, for VNet Integration (outbound)')
param appSubnetId string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

var appServicePlanName = 'plan-goat-${environment}'
var appServiceName = 'app-goat-api-${environment}'

resource appServicePlan 'Microsoft.Web/serverfarms@2025-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P1v3'
  }
  properties: {
    reserved: true // Linux plan
  }
}

resource appService 'Microsoft.Web/sites@2025-01-01' = {
  name: appServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: appSubnetId
    publicNetworkAccess: 'Disabled'
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
  }
}

output appServiceId string = appService.id
output appServicePrincipalId string = appService.identity.principalId
output appServiceDefaultHostname string = appService.properties.defaultHostName
