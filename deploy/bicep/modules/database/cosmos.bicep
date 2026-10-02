// TODO: Cosmos DB account + database/container with private endpoint-only access
// deploy/bicep/modules/database/cosmos.bicep
// Azure Cosmos DB (SQL API) — catalog container, public access disabled, private endpoint only

@description('Environment for Cosmos DB')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

import { networkAccessRules } from '../shared/networkAccessRules.bicep'

var cosmosAccountName = 'cosmos-goat-${environment}'
var databaseName = 'goatticket'
var containerName = 'catalog'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: toLower(cosmosAccountName)
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    publicNetworkAccess: networkAccessRules.defaultAction == 'Deny' ? 'Disabled' : 'Enabled'
    disableLocalAuth: true
    disableKeyBasedMetadataWriteAccess: true
    ipRules: [for ip in networkAccessRules.allowedIpRanges: { ipAddressOrRange: ip }]
    isVirtualNetworkFilterEnabled: true
    capabilities: [
      { name: 'EnableServerless' }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
    }
  }
}

output cosmosAccountId string = cosmosAccount.id
output cosmosAccountEndpoint string = cosmosAccount.properties.documentEndpoint
