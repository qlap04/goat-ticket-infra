// main.bicep
// GOAT Ticket — full infrastructure orchestration across 2 resource groups.
// targetScope: subscription — this file creates BOTH resource groups itself,
// intended to be run via CI/CD pipeline (az deployment sub create).
//
// Deployment order:
// 1. Resource Groups
// 2. network (vnet, nsg, routeTable-base)
// 3. gateway-firewall (firewallPolicy, firewall) — needs network subnet IDs
// 4. routeTableEgress — needs firewall private IP (solves circular dependency)
// 5. storage (2 accounts: runtime + business)
// 6. appInsights
// 7. database (sql, cosmos)
// 8. security/keyvault
// 9. compute (appService, function) — needs subnet IDs, App Insights, storage names
// 10. gateway-firewall/appGateway — needs Key Vault cert URI, backend FQDN, snet-appgw
// 11. security/rbac — needs all principalIds + resource IDs
// 12. privateEndpoints (dnsZones, then privateEndpoints)
// 13. subnetAssociation — separate module (resourceGroup scope) because main.bicep
//     runs at subscription scope and cannot directly declare resourceGroup-scoped
//     child resources outside a module (BCP165)

targetScope = 'subscription'

@description('Environment name: dev or prod.')
@allowed(['dev', 'prod'])
param environment string

@description('Azure region for all resources.')
param location string = 'southeastasia'

@description('Custom domain for the App Gateway multi-site listener')
param customDomain string = 'goatticket.com'

@description('URI of the TLS certificate secret in Key Vault, without version, for auto-rotation')
param keyVaultCertSecretUri string

@description('RS256 private key value for signing ticket QR codes')
@secure()
param ticketQrSigningKeyValue string

// ===== RESOURCE GROUPS =====
resource rgNetwork 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-goat-network-${environment}'
  location: location
}

resource rgApp 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-goat-app-${environment}'
  location: location
}

// ============================================================
// 1. NETWORK
// ============================================================
module vnetModule 'modules/network/vnet.bicep' = {
  name: 'vnetDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
  }
}

module nsgModule 'modules/network/nsg.bicep' = {
  name: 'nsgDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
  }
}

module routeTableModule 'modules/network/routeTable.bicep' = {
  name: 'routeTableDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
  }
}

// ============================================================
// 2. GATEWAY + FIREWALL (firewall needs network subnet + policy)
// ============================================================
module firewallPolicyModule 'modules/gateway-firewall/firewallPolicy.bicep' = {
  name: 'firewallPolicyDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
  }
}

module firewallModule 'modules/gateway-firewall/firewall.bicep' = {
  name: 'firewallDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
    azureFirewallSubnetId: vnetModule.outputs.azureFirewallSubnetResourceId
    firewallPolicyId: firewallPolicyModule.outputs.firewallPolicyId
  }
}

// ============================================================
// 3. ROUTE TABLE EGRESS — solves the routeTable ↔ firewall circular dependency
// ============================================================
module routeTableEgressModule 'modules/network/routeTableEgress.bicep' = {
  name: 'routeTableEgressDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    firewallPrivateIp: firewallModule.outputs.firewallPrivateIp
  }
  dependsOn: [
    routeTableModule
  ]
}

// ============================================================
// 4. STORAGE (2 accounts: runtime + business)
// ============================================================
module storageModule 'modules/storage/storageAccount.bicep' = {
  name: 'storageDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
  }
}

// ============================================================
// 5. APPLICATION INSIGHTS (shared by App Service + Function)
// ============================================================
module appInsightsModule 'modules/security/appInsights.bicep' = {
  name: 'appInsightsDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
  }
}

// ============================================================
// 6. DATABASE
// ============================================================
module sqlModule 'modules/database/sql.bicep' = {
  name: 'sqlDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
    runtimeStorageAccountName: storageModule.outputs.runtimeStorageAccountName
    // sqlAdminObjectId / sqlAdminLogin intentionally NOT passed —
    // sql.bicep defaults them to deployer().objectId / deployer().userPrincipalName,
    // so whoever (or whichever pipeline Service Principal) runs the deployment
    // automatically becomes the SQL admin. Override in .bicepparam only if needed.
  }
}

module cosmosModule 'modules/database/cosmos.bicep' = {
  name: 'cosmosDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
  }
}

// ============================================================
// 7. KEY VAULT
// ============================================================
module keyVaultModule 'modules/security/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
    ticketQrSigningKeyValue: ticketQrSigningKeyValue
  }
}

// ============================================================
// 8. COMPUTE (needs snet-app/snet-func, App Insights, storage names)
// ============================================================
module appServiceModule 'modules/compute/appService.bicep' = {
  name: 'appServiceDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
    appSubnetId: vnetModule.outputs.snetAppResourceId
    appInsightsConnectionString: appInsightsModule.outputs.appInsightsConnectionString
  }
}

module functionModule 'modules/compute/function.bicep' = {
  name: 'functionDeployment'
  scope: rgApp
  params: {
    environment: environment
    location: location
    funcSubnetId: vnetModule.outputs.snetFuncResourceId
    runtimeStorageAccountName: storageModule.outputs.runtimeStorageAccountName
    businessStorageAccountName: storageModule.outputs.businessStorageAccountName
    appInsightsConnectionString: appInsightsModule.outputs.appInsightsConnectionString
  }
}

// ============================================================
// 9. APPLICATION GATEWAY (needs Key Vault cert, snet-appgw, App Service hostname)
// ============================================================
module appGatewayModule 'modules/gateway-firewall/appGateway.bicep' = {
  name: 'appGatewayDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
    appGatewaySubnetId: vnetModule.outputs.snetAppGwResourceId
    backendFqdn: appServiceModule.outputs.appServiceDefaultHostname
    customDomain: customDomain
    keyVaultCertSecretUri: keyVaultCertSecretUri
  }
}

// ============================================================
// 10. RBAC (needs all principalIds + resource IDs from steps 4-9)
// ============================================================
module rbacModule 'modules/security/rbac.bicep' = {
  name: 'rbacDeployment'
  scope: rgApp
  params: {
    appServicePrincipalId: appServiceModule.outputs.appServicePrincipalId
    functionAppPrincipalId: functionModule.outputs.functionAppPrincipalId
    agwIdentityPrincipalId: appGatewayModule.outputs.agwIdentityPrincipalId
    sqlServerPrincipalId: sqlModule.outputs.sqlServerPrincipalId
    keyVaultId: keyVaultModule.outputs.keyVaultId
    cosmosAccountId: cosmosModule.outputs.cosmosAccountId
    runtimeStorageAccountId: storageModule.outputs.runtimeStorageAccountId
    businessStorageAccountId: storageModule.outputs.businessStorageAccountId
  }
}

//appGatewayResourceModule
module appGatewayResourceModule 'modules/gateway-firewall/appGatewayResource.bicep' = {
  name: 'appGatewayResourceDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    appGatewaySubnetId: vnetModule.outputs.snetAppGwResourceId
    backendFqdn: appServiceModule.outputs.appServiceDefaultHostname
    customDomain: customDomain
    keyVaultCertSecretUri: keyVaultCertSecretUri
    agwIdentityId: appGatewayModule.outputs.agwIdentityId
    wafPolicyId: appGatewayModule.outputs.wafPolicyId
    publicIpId: appGatewayModule.outputs.publicIpId
  }
  dependsOn: [rbacModule]
}

//Auditing module
module sqlAuditingModule 'modules/database/sqlAuditing.bicep' = {
  name: 'sqlAuditingDeployment'
  scope: rgApp
  params: {
    sqlServerName: 'sql-goat-${environment}'
    runtimeStorageAccountName: storageModule.outputs.runtimeStorageAccountName
  }
  dependsOn: [
    rbacModule
  ]
}

// ============================================================
// 11. PRIVATE DNS ZONES
// ============================================================
module privateDnsZonesModule 'modules/privateEndpoints/privateDnsZones.bicep' = {
  name: 'privateDnsZonesDeployment'
  scope: rgNetwork
  params: {
    vnetId: vnetModule.outputs.vnetId
  }
}

// ============================================================
// 12. PRIVATE ENDPOINTS (8 total: sql, cosmos, biz-blob, biz-queue, runtime-blob, keyvault, app, func)
// ============================================================
module privateEndpointsModule 'modules/privateEndpoints/privateEndpoints.bicep' = {
  name: 'privateEndpointsDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    location: location
    peSubnetId: vnetModule.outputs.snetPeResourceId
    sqlServerId: sqlModule.outputs.sqlServerId
    cosmosAccountId: cosmosModule.outputs.cosmosAccountId
    businessStorageAccountId: storageModule.outputs.businessStorageAccountId
    runtimeStorageAccountId: storageModule.outputs.runtimeStorageAccountId
    keyVaultId: keyVaultModule.outputs.keyVaultId
    appServiceId: appServiceModule.outputs.appServiceId
    functionAppId: functionModule.outputs.functionAppId
    dnsZoneIds: privateDnsZonesModule.outputs.dnsZoneIds
  }
}

// ============================================================
// 13. ASSOCIATE NSG + ROUTE TABLE TO SUBNETS
// Separate module (not inline resources) because this file's targetScope is
// 'subscription' — Bicep does not allow declaring resourceGroup-scoped child
// resources directly outside a module in a subscription-scope file (BCP165).
// ============================================================
module subnetAssociationModule 'modules/network/subnetAssociation.bicep' = {
  name: 'subnetAssociationDeployment'
  scope: rgNetwork
  params: {
    environment: environment
    nsgAppGwId: nsgModule.outputs.nsgAppGwId
    nsgAppId: nsgModule.outputs.nsgAppId
    nsgFuncId: nsgModule.outputs.nsgFuncId
    nsgPeId: nsgModule.outputs.nsgPeId
    routeTableAppId: routeTableModule.outputs.routeTableAppId
    routeTablePeId: routeTableModule.outputs.routeTablePeId
  }
  dependsOn: [
    vnetModule
    appGatewayModule
    appServiceModule
    functionModule
    routeTableEgressModule
    privateEndpointsModule
  ]
}

// ============================================================
// OUTPUTS
// ============================================================
output resourceGroupNetworkName string = rgNetwork.name
output resourceGroupAppName string = rgApp.name
output appGatewayPublicIp string = appGatewayModule.outputs.publicIpId
output appServiceDefaultHostname string = appServiceModule.outputs.appServiceDefaultHostname
