// modules/privateEndpoints/privateEndpoints.bicep
// 8 Private Endpoints — SQL, Cosmos, Business Blob, Business Queue, Runtime Blob,
// Key Vault, App Service, Function — all placed in snet-pe

@description('Environment for Private Endpoints')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Resource ID of snet-pe')
param peSubnetId string

@description('Resource ID of SQL Server')
param sqlServerId string

@description('Resource ID of Cosmos DB account')
param cosmosAccountId string

@description('Resource ID of the Business Storage Account (tickets blob + queues)')
param businessStorageAccountId string

@description('Resource ID of the Runtime Storage Account (Function internal state)')
param runtimeStorageAccountId string

@description('Resource ID of Key Vault')
param keyVaultId string

@description('Resource ID of App Service')
param appServiceId string

@description('Resource ID of Function App')
param functionAppId string

@description('Array of Private DNS Zone IDs, in order: [sql, cosmos, blob, queue, vault, sites]')
param dnsZoneIds array

// ===== 1. SQL Server =====
resource peSql 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-sql-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-sql'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

resource peSqlDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peSql
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-sql', properties: { privateDnsZoneId: dnsZoneIds[0] } }
    ]
  }
}

// ===== 2. Cosmos DB =====
resource peCosmos 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-cosmos-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-cosmos'
        properties: {
          privateLinkServiceId: cosmosAccountId
          groupIds: ['Sql']
        }
      }
    ]
  }
}

resource peCosmosDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peCosmos
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-cosmos', properties: { privateDnsZoneId: dnsZoneIds[1] } }
    ]
  }
}

// ===== 3. Business Storage — Blob (tickets) =====
resource peBusinessBlob 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-business-storage-blob-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-business-storage-blob'
        properties: {
          privateLinkServiceId: businessStorageAccountId
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource peBusinessBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peBusinessBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-business-storage-blob', properties: { privateDnsZoneId: dnsZoneIds[2] } }
    ]
  }
}

// ===== 4. Business Storage — Queue (order-created, seat-hold-queue) =====
resource peBusinessQueue 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-business-storage-queue-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-business-storage-queue'
        properties: {
          privateLinkServiceId: businessStorageAccountId
          groupIds: ['queue']
        }
      }
    ]
  }
}

resource peBusinessQueueDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peBusinessQueue
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-business-storage-queue', properties: { privateDnsZoneId: dnsZoneIds[3] } }
    ]
  }
}

// ===== 5. Runtime Storage — Blob (Function's own internal state) =====
resource peRuntimeBlob 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-runtime-storage-blob-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-runtime-storage-blob'
        properties: {
          privateLinkServiceId: runtimeStorageAccountId
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource peRuntimeBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peRuntimeBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-runtime-storage-blob', properties: { privateDnsZoneId: dnsZoneIds[2] } }
    ]
  }
}

// ===== 6. Key Vault =====
resource peKeyVault 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-keyvault-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-keyvault'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource peKeyVaultDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peKeyVault
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-keyvault', properties: { privateDnsZoneId: dnsZoneIds[4] } }
    ]
  }
}

// ===== 7. App Service =====
resource peAppService 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-app-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-app'
        properties: {
          privateLinkServiceId: appServiceId
          groupIds: ['sites']
        }
      }
    ]
  }
}

resource peAppServiceDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peAppService
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-app', properties: { privateDnsZoneId: dnsZoneIds[5] } }
    ]
  }
}

// ===== 8. Function App =====
resource peFunction 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-func-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-func'
        properties: {
          privateLinkServiceId: functionAppId
          groupIds: ['sites']
        }
      }
    ]
  }
}

resource peFunctionDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: peFunction
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config-func', properties: { privateDnsZoneId: dnsZoneIds[5] } }
    ]
  }
}

output peSqlId string = peSql.id
output peCosmosId string = peCosmos.id
output peBusinessBlobId string = peBusinessBlob.id
output peBusinessQueueId string = peBusinessQueue.id
output peRuntimeBlobId string = peRuntimeBlob.id
output peKeyVaultId string = peKeyVault.id
output peAppServiceId string = peAppService.id
output peFunctionId string = peFunction.id
