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

@description('Entra ID tenant ID')
param tenantId string

@description('Client ID of the API app registration')
param apiClientId string

@description('Client ID of the Swagger UI app registration')
param swaggerClientId string

var appServicePlanName = 'plan-goat-${environment}'
var appServiceName = 'app-goat-api-${environment}'

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

// checkov:skip=CKV_AZURE_225:Zone redundancy not needed for portfolio dev envirorg ewwgwgnment, adds cost without benefit at this scale
// checkov:skip=CKV_AZURE_17:Client certificate auth not used, Entra ID (Microsoft.Identity.Web) handles all authentication
// checkov:skip=CKV_AZURE_213:Health check endpoint not yet implemented in application code — enable once /api/health exists
resource appService 'Microsoft.Web/sites@2024-11-01' = {
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
      http20Enabled: true
      appSettings: [
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
        { name: 'ASPNETCORE_ENVIRONMENT', value: 'Development' }
        { name: 'AzureAd__Instance', value: 'https://login.microsoftonline.com/' }
        { name: 'AzureAd__TenantId', value: tenantId }
        { name: 'AzureAd__ClientId', value: apiClientId }
        { name: 'AzureAd__Audience', value: 'api://${apiClientId}' }
        { name: 'SwaggerOAuth__TenantId', value: tenantId }
        { name: 'SwaggerOAuth__ClientId', value: swaggerClientId }
        { name: 'SwaggerOAuth__Scope', value: 'api://${apiClientId}/access_as_user' }
      ]
    }
  }
}

output appServiceId string = appService.id
output appServicePrincipalId string = appService.identity.principalId
output appServiceDefaultHostname string = appService.properties.defaultHostName
