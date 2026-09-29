// modules/security/rbac.bicep
// RBAC role assignments — MI-app, MI-func, agwIdentity onto Key Vault, Cosmos, Storage (x2 accounts)
// NOTE: SQL permissions are NOT handled here — done via T-SQL (CREATE USER FROM EXTERNAL PROVIDER)
// run manually/via pipeline after deployment, since SQL keeps its own internal permission system.

@description('principalId of App Service Managed Identity')
param appServicePrincipalId string

@description('principalId of Function App Managed Identity')
param functionAppPrincipalId string

@description('principalId of App Gateway User-Assigned Identity')
param agwIdentityPrincipalId string

@description('Resource ID of the Key Vault')
param keyVaultId string

@description('Resource ID of the Cosmos DB account')
param cosmosAccountId string

@description('Resource ID of the Runtime Storage Account (Function internal state)')
param runtimeStorageAccountId string

@description('Resource ID of the Business Storage Account (tickets blob + queues)')
param businessStorageAccountId string

// ===== Built-in role definition IDs =====
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var cosmosDataReaderRoleId = '00000000-0000-0000-0000-000000000001'

// ===== existing references =====
resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: last(split(cosmosAccountId, '/'))
}

resource runtimeStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: last(split(runtimeStorageAccountId, '/'))
}

resource businessStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: last(split(businessStorageAccountId, '/'))
}

// ===== 1. MI-app → Key Vault (Secrets User) =====
resource appToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, appServicePrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: appServicePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ===== 2. MI-app → Cosmos (Data Reader) — Cosmos data-plane RBAC, different resource type =====
resource appToCosmosReader 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccountId, appServicePrincipalId, cosmosDataReaderRoleId)
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosDataReaderRoleId}'
    principalId: appServicePrincipalId
    scope: cosmosAccountId
  }
}

// ===== 3. MI-func → Cosmos (Data Reader) =====
resource funcToCosmosReader 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccountId, functionAppPrincipalId, cosmosDataReaderRoleId)
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosDataReaderRoleId}'
    principalId: functionAppPrincipalId
    scope: cosmosAccountId
  }
}

// ===== 4. MI-func → Runtime Storage (Blob Data Owner — Function needs elevated rights to
//          manage its own internal lock files/checkpoints, not just read/write) =====
resource funcToRuntimeStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorageAccountId, functionAppPrincipalId, storageBlobDataOwnerRoleId)
  scope: runtimeStorageAccount
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ===== 5. MI-func → Business Storage Blob (Data Contributor — tickets container) =====
resource funcToBusinessBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(businessStorageAccountId, functionAppPrincipalId, storageBlobDataContributorRoleId)
  scope: businessStorageAccount
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalType: 'ServicePrincipal'
  }
}

// ===== 6. MI-func → Business Storage Queue (Data Contributor — order-created, seat-hold-queue) =====
resource funcToBusinessQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(businessStorageAccountId, functionAppPrincipalId, storageQueueDataContributorRoleId)
  scope: businessStorageAccount
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageQueueDataContributorRoleId
    )
    principalType: 'ServicePrincipal'
  }
}

// ===== 7. agwIdentity → Key Vault (Secrets User) — for pulling the TLS cert =====
resource agwToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, agwIdentityPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: agwIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}
