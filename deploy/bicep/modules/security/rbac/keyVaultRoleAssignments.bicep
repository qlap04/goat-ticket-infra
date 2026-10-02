// deploy/bicep/modules/security/rbac/keyVaultRoleAssignments.bicep
// Array/for-loop-driven Key Vault role assignments — add/remove a principal by editing the array.

@description('Resource ID of the target Key Vault')
param keyVaultId string

@description('One entry per identity to grant a role on this Key Vault')
param principals array

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource keyVaultRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principal in principals: {
    name: guid(keyVaultId, principal.principalId, principal.roleDefinitionId)
    scope: keyVault
    properties: {
      principalId: principal.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', principal.roleDefinitionId)
      principalType: principal.principalType
    }
  }
]
