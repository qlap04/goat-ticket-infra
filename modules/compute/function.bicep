// modules/compute/function.bicep
// Function App Plan (Premium EP1, Linux) + Function App (.NET 8 isolated worker)
// Outbound via VNet Integration (snet-func) — inbound via Private Endpoint (separate module)
// AzureWebJobsStorage uses Identity-based connection (no Account Key)

@description('Environment for Function App')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Resource ID of snet-func, for VNet Integration (outbound)')
param funcSubnetId string

@description('Storage Account name for AzureWebJobsStorage (Function runtime internal storage)')
param runtimeStorageAccountName string

@description('Business Storage Account name — for blob (tickets) and queue (order-created, seat-hold-queue). Accessed via DefaultAzureCredential, not a connection string.')
param businessStorageAccountName string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

var functionPlanName = 'plan-goat-func-${environment}'
var functionAppName = 'func-goat-worker-${environment}'

resource functionPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: functionPlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

// checkov:skip=CKV_AZURE_225:Zone redundancy not needed for portfolio dev environment, adds cost without benefit at this scale
// checkov:skip=CKV_AZURE_17:Client certificate auth not used, Entra ID handles authentication for the API; Function has no public inbound
// checkov:skip=CKV_AZURE_213:Health check endpoint not yet implemented in application code — enable once a health check function exists
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: functionPlan.id
    virtualNetworkSubnetId: funcSubnetId
    publicNetworkAccess: 'Disabled'
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      http20Enabled: true
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: runtimeStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'BusinessStorageAccountName'
          value: businessStorageAccountName
        }
      ]
    }
  }
}

output functionAppId string = functionApp.id
output functionAppPrincipalId string = functionApp.identity.principalId
output functionAppDefaultHostname string = functionApp.properties.defaultHostName
