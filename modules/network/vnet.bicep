// TODO: VNet + 5 subnets — snet-appgw, snet-app, snet-func, snet-pe, AzureFirewallSubnet
@description('Environment name: dev or prod.')
@allowed(['dev', 'prod'])
param environment string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('VNet address space in CIDR')
param vnetAddressPrefix string = '10.10.0.0/16'

var vnetName = 'vnet-goat-${environment}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
  }
}

resource subnetAppGw 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  name: 'snet-appgw'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.10.1.0/24'
  }
}

resource subnetApp 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  name: 'snet-app'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.10.2.0/24'
    delegations: [
      {
        name: 'delegation-serverfarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  dependsOn: [subnetAppGw]
}

resource subnetFunc 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  name: 'snet-func'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.10.3.0/24'
    delegations: [
      {
        name: 'delegation-serverfarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  dependsOn: [subnetApp]
}

resource subnetPe 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  name: 'snet-pe'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.10.4.0/24'
  }
  dependsOn: [subnetFunc]
}

resource subnetFirewall 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  name: 'AzureFirewallSubnet'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.10.5.0/26'
  }
  dependsOn: [subnetPe]
}

output snetAppGwResourceId string = subnetAppGw.id
output snetAppResourceId string = subnetApp.id
output snetFuncResourceId string = subnetFunc.id
output snetPeResourceId string = subnetPe.id
output azureFirewallSubnetResourceId string = subnetFirewall.id
output vnetId string = virtualNetwork.id
