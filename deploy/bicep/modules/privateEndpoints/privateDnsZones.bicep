// TODO: Private DNS zones and VNet links for each private endpoint type
// deploy/bicep/modules/privateEndpoints/privateDnsZones.bicep
// TODO: 6 Private DNS Zones + link to VNet — required so PE hostnames resolve to private IPs

@description('Resource ID of the VNet, for linking DNS zones')
param vnetId string

// Order is a contract with privateEndpoints.bicep, which indexes the dnsZoneIds output as
// [sql, cosmos, blob, queue, vault, sites]. Do not reorder.
//
// Where Azure exposes the cloud's DNS suffix, the zone name is derived from it so the same template
// is correct in a sovereign cloud. Cosmos DB, Key Vault private link and App Service have no
// suffix in environment(), so those three stay literal.
var dnsZoneNames = [
  'privatelink${az.environment().suffixes.sqlServerHostname}' // SQL
  'privatelink.documents.azure.com' // Cosmos — no suffix exposed by environment()
  'privatelink.blob.${az.environment().suffixes.storage}' // Storage Blob
  'privatelink.queue.${az.environment().suffixes.storage}' // Storage Queue
  'privatelink.vaultcore.azure.net' // Key Vault — suffixes.keyvaultDns is vault.azure.net, not vaultcore
  'privatelink.azurewebsites.net' // App Service + Function — no suffix exposed by environment()
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zoneName in dnsZoneNames: {
    name: zoneName
    location: 'global'
  }
]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zoneName, i) in dnsZoneNames: {
    parent: dnsZones[i]
    name: 'link-${zoneName}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnetId
      }
    }
  }
]

output dnsZoneIds array = [for i in range(0, length(dnsZoneNames)): dnsZones[i].id]
