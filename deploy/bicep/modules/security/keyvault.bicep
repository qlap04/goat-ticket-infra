// deploy/bicep/modules/security/keyvault.bicep
// Key Vault (RBAC authorization). The vault only; its secrets are written by the delivery
// pipeline from a variable group, behind a toggle, so no secret value passes through Bicep.
// public access disabled, private endpoint only

@description('Environment for Key Vault')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Suffix appended to the globally unique vault name, normally empty')
param nameSuffix string

import { networkAccessRules } from '../shared/networkAccessRules.bicep'
import { keyVaultName as buildKeyVaultName } from '../shared/naming.bicep'

var keyVaultName = buildKeyVaultName(environment, nameSuffix)

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    accessPolicies: []
    networkAcls: {
      defaultAction: networkAccessRules.defaultAction
      bypass: networkAccessRules.bypass
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
