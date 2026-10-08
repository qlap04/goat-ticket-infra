// deploy/bicep/modules/compute/appService.bicep
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

@description('Suffix appended to the globally unique app name, normally empty')
param nameSuffix string

import { appServiceName as buildAppServiceName } from '../shared/naming.bicep'

var appServicePlanName = 'plan-goat-${environment}'
var appServiceName = buildAppServiceName(environment, nameSuffix)

// Only the settings that make this a working App Service resource, the way linuxFxVersion does.
// Every application setting (AzureAd, SwaggerOAuth, Cosmos, Sql, Storage, KeyVault,
// ASPNETCORE_ENVIRONMENT, Swagger) is owned by the delivery pipeline and written from
// appSettingsJson in the goat-app-<env> variable group, so they are not listed here.
//
// Consequence to respect: an infrastructure deployment replaces this list, which clears the
// settings the pipeline wrote. Run the application pipeline after any infrastructure deployment.
// The stage template already orders it that way inside a run.
var apiAppSettings = [
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
  { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
]

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    reserved: true
  }
}

// checkov:skip=CKV_AZURE_225:Zone redundancy not needed for portfolio dev environment, adds cost without benefit at this scale
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
      appSettings: apiAppSettings
    }
  }
}

// checkov:skip=CKV_AZURE_225:Zone redundancy not needed for portfolio dev environment, adds cost without benefit at this scale
// checkov:skip=CKV_AZURE_17:Client certificate auth not used, Entra ID (Microsoft.Identity.Web) handles all authentication
// checkov:skip=CKV_AZURE_213:Health check endpoint not yet implemented in application code — enable once /api/health exists
resource appServiceStagingSlot 'Microsoft.Web/sites/slots@2024-11-01' = {
  parent: appService
  name: 'staging'
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
      // Identical to the production list on purpose: settings that are not slot settings move with
      // the code during a swap, so an entry missing here would be missing in production afterwards.
      appSettings: apiAppSettings
    }
  }
}

output appServiceId string = appService.id
output appServicePrincipalId string = appService.identity.principalId
output appServiceDefaultHostname string = appService.properties.defaultHostName
output appServiceName string = appService.name
