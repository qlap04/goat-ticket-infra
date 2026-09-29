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
output agwIdentityId string = agwIdentity.id
output agwIdentityPrincipalId string = agwIdentity.properties.principalId
output wafPolicyId string = wafPolicy.id
output publicIpId string = publicIpAgw.id
