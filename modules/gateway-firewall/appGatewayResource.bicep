// modules/gateway-firewall/appGatewayResource.bicep
// Separate from appGateway.bicep because App Gateway needs RBAC on Key Vault
// (agwIdentity → Key Vault Secrets User) BEFORE it can fetch the cert at deploy time —
// same circular-dependency pattern as sqlAuditing.bicep

@description('Environment for App Gateway')
@allowed(['dev', 'prod'])
param environment string

param location string = resourceGroup().location
param appGatewaySubnetId string
param backendFqdn string
param customDomain string = 'goatticket.com'
param keyVaultCertSecretUri string
param agwIdentityId string
param wafPolicyId string
param publicIpId string

var appGatewayName = 'agw-goat-${environment}'

resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agwIdentityId}': {}
    }
  }
  properties: {
    sku: { name: 'WAF_v2', tier: 'WAF_v2' }
    firewallPolicy: { id: wafPolicyId }
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101S'
    }
    autoscaleConfiguration: { minCapacity: 1, maxCapacity: 3 }
    gatewayIPConfigurations: [
      { name: 'appGwIpConfig', properties: { subnet: { id: appGatewaySubnetId } } }
    ]
    frontendIPConfigurations: [
      { name: 'appGwFrontendIp', properties: { publicIPAddress: { id: publicIpId } } }
    ]
    frontendPorts: [
      { name: 'port443', properties: { port: 443 } }
    ]
    sslCertificates: [
      { name: 'cert-goatticket', properties: { keyVaultSecretId: keyVaultCertSecretUri } }
    ]
    backendAddressPools: [
      { name: 'pool-goatticket', properties: { backendAddresses: [{ fqdn: backendFqdn }] } }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpsettings-goatticket'
        properties: { port: 443, protocol: 'Https', pickHostNameFromBackendAddress: true, requestTimeout: 30 }
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
    probes: [
      {
        name: 'probe-goatticket'
        properties: {
          protocol: 'Https'
          path: '/swagger/index.html'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
    ]
  }
}

output appGatewayId string = appGateway.id
output appGatewayPublicIp string = reference(publicIpId, '2023-11-01').ipAddress
