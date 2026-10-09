// deploy/bicep/modules/config/appConfiguration.bicep
// Azure App Configuration — one store for every environment, separated by label.
//
// A key with no label is the common value; the same key with a label overrides it for that
// environment. The application reads the unlabelled set first and the labelled set second, so the
// label wins. That is per-key override, which a variable group cannot do: two groups declaring the
// same variable replace the whole value, not one key inside it.
//
// Free tier: one store per subscription, 1000 requests a day, 10 MB, 7 days of revision history, and
// no private endpoint. Accepted for the mock. The store is reachable publicly but local
// authentication is switched off, so only an Azure identity holding a data role can read it.

@description('Environment for App Configuration')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Suffix appended to the globally unique store name, normally empty')
param nameSuffix string

import { appConfigurationName as buildName } from '../shared/naming.bicep'

var storeName = buildName(environment, nameSuffix)

resource store 'Microsoft.AppConfiguration/configurationStores@2024-06-01' = {
  name: storeName
  location: location
  sku: {
    name: 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // No connection strings and no access keys: readers authenticate with an Azure identity, per
    // the constitution's managed-identity principle.
    disableLocalAuth: true
    // The free tier does not support soft delete. Zero also releases the name immediately when the
    // store is deleted, which matters because the resource groups are deleted between demos.
    softDeleteRetentionInDays: 0
  }
}

output appConfigurationId string = store.id
output appConfigurationName string = store.name
output appConfigurationEndpoint string = store.properties.endpoint
