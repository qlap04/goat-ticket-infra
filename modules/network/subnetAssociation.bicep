// modules/network/subnetAssociation.bicep
// Associates NSG + RouteTable to the 4 subnets that need it — separate module because
// main.bicep runs at subscription scope, but this needs resourceGroup scope.
// IMPORTANT: subnet PUT replaces the whole properties object — delegations must be
// re-declared here too, or they get wiped out by this second declaration.

@description('Environment')
@allowed(['dev', 'prod'])
param environment string

param nsgAppGwId string
param nsgAppId string
param nsgFuncId string
param nsgPeId string
param routeTableAppId string
param routeTablePeId string

resource vnetExisting 'Microsoft.Network/virtualNetworks@2025-01-01' existing = {
  name: 'vnet-goat-${environment}'
}

resource snetAppGwUpdate 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnetExisting
  name: 'snet-appgw'
  properties: {
    addressPrefix: '10.10.1.0/24'
    networkSecurityGroup: { id: nsgAppGwId }
  }
}

resource snetAppUpdate 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnetExisting
  name: 'snet-app'
  properties: {
    addressPrefix: '10.10.2.0/24'
    networkSecurityGroup: { id: nsgAppId }
    routeTable: { id: routeTableAppId }
    delegations: [
      {
        name: 'delegation-serverfarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

resource snetFuncUpdate 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnetExisting
  name: 'snet-func'
  properties: {
    addressPrefix: '10.10.3.0/24'
    networkSecurityGroup: { id: nsgFuncId }
    routeTable: { id: routeTableAppId }
    delegations: [
      {
        name: 'delegation-serverfarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

resource snetPeUpdate 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnetExisting
  name: 'snet-pe'
  properties: {
    addressPrefix: '10.10.4.0/24'
    networkSecurityGroup: { id: nsgPeId }
    routeTable: { id: routeTablePeId }
  }
}
