// TODO: Network Security Group(s) with inbound/outbound rules per subnet
@description('Environment for nsg')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

// nsg-appgw — App Gateway subnet: Internet HTTPS in + mandatory GatewayManager rule
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: 'nsg-appgw-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'Allow-Https-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// nsg-app — App Service subnet: only App Gateway subnet can reach it, deny internet
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: 'nsg-app-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// nsg-func — Function subnet: only App subnet can reach it, deny-all fallback
resource nsgFunc 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: 'nsg-func-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// nsg-pe — Private Endpoint subnet: only traffic from inside the VNet, deny internet
resource nsgPe 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: 'nsg-pe-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-From-VNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork' // include App GW
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '443'
            '1433'
          ]
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

output nsgAppGwId string = nsgAppGw.id
output nsgAppId string = nsgApp.id
output nsgFuncId string = nsgFunc.id
output nsgPeId string = nsgPe.id
