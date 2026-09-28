// TODO: Route Table with routes forcing egress through Azure Firewall
// modules/network/routeTable.bicep
// TODO: Route Tables — rt-app (snet-app, snet-func) and rt-pe (snet-pe)

@description('Environment for route tables')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

// rt-app — used by snet-app and snet-func
// NOTE: 0.0.0.0/0 → Firewall route is added LATER (separate module),
// once the Firewall's private IP exists.
resource routeTableApp 'Microsoft.Network/routeTables@2025-01-01' = {
  name: 'rt-app-${environment}'
  location: location
  properties: {
    routes: [
      {
        name: 'route-to-pe'
        properties: {
          addressPrefix: '10.10.4.0/24'
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

// rt-pe — used by snet-pe, only needs local VNet routing
resource routeTablePe 'Microsoft.Network/routeTables@2025-01-01' = {
  name: 'rt-pe-${environment}'
  location: location
  properties: {
    routes: [
      {
        name: 'route-local'
        properties: {
          addressPrefix: '10.10.0.0/16'
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

output routeTableAppId string = routeTableApp.id
output routeTablePeId string = routeTablePe.id
