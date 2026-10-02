// deploy/bicep/modules/network/routeTableEgress.bicep
@description('Environment')
@allowed(['dev', 'prod'])
param environment string

@description('Private IP of the Azure Firewall')
param firewallPrivateIp string

resource routeTableAppExisting 'Microsoft.Network/routeTables@2025-01-01' existing = {
  name: 'rt-app-${environment}'
}

resource egressRoute 'Microsoft.Network/routeTables/routes@2025-01-01' = {
  parent: routeTableAppExisting
  name: 'route-internet'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallPrivateIp
  }
}
