// deploy/bicep/modules/gateway-firewall/firewallPolicy.bicep
// TODO: Firewall Policy + Rule Collection Group — egress FQDN allowlist for snet-app/snet-func

@description('Environment for firewall policy')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

// ===== GROUP FOR ALL — Firewall Policy =====
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2025-01-01' = {
  name: 'afwp-goat-${environment}'
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-01-01' = {
  parent: firewallPolicy
  name: 'rcg-egress-${environment}'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowEgressFqdns'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'allow-nuget'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            sourceAddresses: [
              '10.10.2.0/24' // snet-app
              '10.10.3.0/24' // snet-func
            ]
            targetFqdns: [
              'api.nuget.org'
              'nuget.org'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'allow-entra-id'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            sourceAddresses: [
              '10.10.2.0/24'
              '10.10.3.0/24'
            ]
            targetFqdns: [
              'login.microsoftonline.com'
              'graph.microsoft.com'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'allow-app-insights'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            sourceAddresses: [
              '10.10.2.0/24'
              '10.10.3.0/24'
            ]
            targetFqdns: [
              '*.applicationinsights.azure.com'
              '*.monitor.azure.com'
            ]
          }
        ]
      }
    ]
  }
}

output firewallPolicyId string = firewallPolicy.id
