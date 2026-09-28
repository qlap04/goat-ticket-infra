// TODO: VNet + 5 subnets — snet-appgw, snet-app, snet-func, snet-pe, AzureFirewallSubnet
@description('Environment name: dev or prod.')
@allowed(['dev', 'prod'])
param environment string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('VNet address space in CIDR')
param vnetAddressPrefix string = '10.10.0.0/16'

var vnetName = 'vnet-goat-${environment}'
var subnetDefinitions = [
  { name: 'snet-appgw', addressPrefix: '10.10.1.0/24' }
  { name: 'snet-app', addressPrefix: '10.10.2.0/24' }
  { name: 'snet-func', addressPrefix: '10.10.3.0/24' }
  { name: 'snet-pe', addressPrefix: '10.10.4.0/24' }
  { name: 'AzureFirewallSubnet', addressPrefix: '10.10.5.0/26' }
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource subnets 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = [
  for subnet in subnetDefinitions: {
    name: subnet.name
    parent: virtualNetwork
    properties: {
      addressPrefix: subnet.addressPrefix
    }
  }
]

output snetAppGwResourceId string = filter(subnets, s => s.name == 'snet-appgw')[0].id
output snetAppResourceId string = filter(subnets, s => s.name == 'snet-app')[0].id
output snetFuncResourceId string = filter(subnets, s => s.name == 'snet-func')[0].id
output snetPeResourceId string = filter(subnets, s => s.name == 'snet-pe')[0].id
output azureFirewallSubnetResourceId string = filter(subnets, s => s.name == 'AzureFirewallSubnet')[0].id
output vnetId string = virtualNetwork.id
