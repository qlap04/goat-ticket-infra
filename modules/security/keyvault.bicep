// modules/security/keyvault.bicep
// Key Vault (RBAC authorization) — TicketQrSigningKey secret only
// public access disabled, private endpoint only

@description('Environment for Key Vault')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('RS256 private key value for signing ticket QR codes')
@secure()
param ticketQrSigningKeyValue string

var keyVaultName = 'kv-goat-${environment}'

resource keyVault 'Microsoft.KeyVault/vaults@2025-01-01' = {
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
  }
}

resource ticketQrSigningKeySecret 'Microsoft.KeyVault/vaults/secrets@2025-01-01' = {
  parent: keyVault
  name: 'TicketQrSigningKey'
  properties: {
    value: ticketQrSigningKeyValue
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
