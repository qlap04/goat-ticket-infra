// deploy/bicep/modules/security/rbac/cosmosRoleAssignments.bicep
// Array/for-loop-driven Cosmos DB SQL role assignments — add/remove a principal by editing the array.

@description('Resource ID of the target Cosmos account')
param cosmosAccountId string

@description('One entry per identity to grant a Cosmos SQL role on this account')
param principals array

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: last(split(cosmosAccountId, '/'))
}

resource cosmosRoleAssignments 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = [
  for principal in principals: {
    parent: cosmosAccount
    name: guid(cosmosAccountId, principal.principalId, principal.roleDefinitionId)
    properties: {
      roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${principal.roleDefinitionId}'
      principalId: principal.principalId
      scope: cosmosAccountId
    }
  }
]
