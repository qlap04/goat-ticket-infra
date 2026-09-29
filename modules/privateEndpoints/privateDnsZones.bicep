// TODO: Private DNS zones and VNet links for each private endpoint type
// modules/privateEndpoints/privateDnsZones.bicep
// TODO: 6 Private DNS Zones + link to VNet — required so PE hostnames resolve to private IPs

@description('Resource ID of the VNet, for linking DNS zones')
param vnetId string

var dnsZoneNames = [
  'privatelink.database.windows.net' // SQL
  'privatelink.documents.azure.com' // Cosmos
  'privatelink.blob.core.windows.net' // Storage Blob
  'privatelink.queue.core.windows.net' // Storage Queue
  'privatelink.vaultcore.azure.net' // Key Vault
  'privatelink.azurewebsites.net' // App Service + Function (shared)
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
