// modules/storage/storageAccount.bicep
// 2 Storage Accounts: runtime (Function's own internal state) + business (tickets blob, 2 queues)

@description('Environment for Storage Accounts')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

var runtimeStorageAccountName = 'stgoatrt${environment}${uniqueString(resourceGroup().id)}'
var businessStorageAccountName = 'stgoatbiz${environment}${uniqueString(resourceGroup().id)}'

// ===== Runtime Storage — Function's own internal state (lock files, checkpoints) =====
resource runtimeStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: runtimeStorageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// ===== Business Storage — tickets blob + order/seat-hold queues =====
resource businessStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: businessStorageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: businessStorageAccount
  name: 'default'
}

resource ticketsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: 'tickets'
  properties: {
    publicAccess: 'None'
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' = {
  parent: businessStorageAccount
  name: 'default'
}

resource orderCreatedQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = {
  parent: queueService
  name: 'order-created'
}

resource seatHoldQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = {
  parent: queueService
  name: 'seat-hold-queue'
}

output runtimeStorageAccountId string = runtimeStorageAccount.id
output runtimeStorageAccountName string = runtimeStorageAccount.name
output businessStorageAccountId string = businessStorageAccount.id
output businessStorageAccountName string = businessStorageAccount.name
output businessStorageAccountBlobEndpoint string = businessStorageAccount.properties.primaryEndpoints.blob
output businessStorageAccountQueueEndpoint string = businessStorageAccount.properties.primaryEndpoints.queue
