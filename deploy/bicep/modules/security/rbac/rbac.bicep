// deploy/bicep/modules/security/rbac/rbac.bicep
// RBAC parent — composes array/for-loop-driven Key Vault + Cosmos child modules, plus the
// Storage/SQL role assignments (kept here directly; each differs in role/target per pairing).
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

@description('principalId of SQL Server Managed Identity')
param sqlServerPrincipalId string

// ===== Built-in role definition IDs =====
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var cosmosDataReaderRoleId = '00000000-0000-0000-0000-000000000001'

var keyVaultPrincipals = [
  {
    principalId: appServicePrincipalId
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalType: 'ServicePrincipal'
  }
  {
    principalId: agwIdentityPrincipalId
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalType: 'ServicePrincipal'
  }
]

var cosmosPrincipals = [
  {
    principalId: appServicePrincipalId
    roleDefinitionId: cosmosDataReaderRoleId
  }
  {
    principalId: functionAppPrincipalId
    roleDefinitionId: cosmosDataReaderRoleId
  }
]

module keyVaultRoleAssignmentsModule 'keyVaultRoleAssignments.bicep' = {
  name: 'keyVaultRoleAssignmentsDeployment'
  params: {
    keyVaultId: keyVaultId
    principals: keyVaultPrincipals
  }
}

module cosmosRoleAssignmentsModule 'cosmosRoleAssignments.bicep' = {
  name: 'cosmosRoleAssignmentsDeployment'
  params: {
    cosmosAccountId: cosmosAccountId
    principals: cosmosPrincipals
  }
}

// ===== existing references =====
resource runtimeStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: last(split(runtimeStorageAccountId, '/'))
}

resource businessStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: last(split(businessStorageAccountId, '/'))
}

// ===== MI-func → Runtime Storage (Blob Data Owner — Function needs elevated rights to
//        manage its own internal lock files/checkpoints, not just read/write) =====
resource funcToRuntimeStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorageAccountId, functionAppPrincipalId, storageBlobDataOwnerRoleId)
  scope: runtimeStorageAccount
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ===== MI-func → Business Storage Blob (Data Contributor — tickets container) =====
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

// ===== MI-func → Business Storage Queue (Data Contributor — order-created, seat-hold-queue) =====
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

// =====
resource sqlToRuntimeStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorageAccountId, sqlServerPrincipalId, storageBlobDataContributorRoleId)
  scope: runtimeStorageAccount
  properties: {
    principalId: sqlServerPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalType: 'ServicePrincipal'
  }
}
