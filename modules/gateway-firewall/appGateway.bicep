// modules/gateway-firewall/appGateway.bicep
// TODO: Application Gateway + WAF + Key Vault-linked TLS cert — public entry point for GOAT Ticket

@description('Environment for App Gateway')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Resource ID of snet-appgw, passed in from the network module output')
param appGatewaySubnetId string

@description('Backend App Service default hostname (FQDN)')
param backendFqdn string

@description('Custom domain for the multi-site listener')
param customDomain string = 'goatticket.com'

@description('URI of the certificate secret in Key Vault, without version, for auto-rotation')
param keyVaultCertSecretUri string

var appGatewayName = 'agw-goat-${environment}'
var publicIpName = 'pip-agw-${environment}'
var wafPolicyName = 'wafp-goat-${environment}'
var agwIdentityName = 'id-agw-${environment}'

// ===== USER-ASSIGNED IDENTITY — for reading the cert from Key Vault =====
resource agwIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: agwIdentityName
  location: location
}

// ===== WAF POLICY =====
resource wafPolicy 'Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: wafPolicyName
  location: location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

// ===== PUBLIC IP =====
resource publicIpAgw 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ===== APPLICATION GATEWAY =====
resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agwIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101S'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 3
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: { id: appGatewaySubnetId }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwFrontendIp'
        properties: {
          publicIPAddress: { id: publicIpAgw.id }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port443'
        properties: { port: 443 }
      }
    ]
    sslCertificates: [
      {
        name: 'cert-goatticket'
        properties: {
          keyVaultSecretId: keyVaultCertSecretUri
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'pool-goatticket'
        properties: {
          backendAddresses: [
            { fqdn: backendFqdn }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpsettings-goatticket'
        properties: {
          port: 443
          protocol: 'Https'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-goatticket'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendIPConfigurations',
              appGatewayName,
              'appGwFrontendIp'
            )
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port443')
          }
          protocol: 'Https'
          hostNames: [customDomain]
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'cert-goatticket')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule-goatticket'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'listener-goatticket')
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendAddressPools',
              appGatewayName,
              'pool-goatticket'
            )
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              appGatewayName,
              'httpsettings-goatticket'
            )
          }
        }
      }
    ]
  }
}

output appGatewayId string = appGateway.id
output appGatewayPublicIp string = publicIpAgw.properties.ipAddress
output agwIdentityId string = agwIdentity.id
output agwIdentityPrincipalId string = agwIdentity.properties.principalId
