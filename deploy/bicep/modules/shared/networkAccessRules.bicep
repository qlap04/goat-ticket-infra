// deploy/bicep/modules/shared/networkAccessRules.bicep
// Network-access policy intent shared by Storage, Key Vault, and Cosmos DB.
// Resource-specific shape differences (e.g. Cosmos's isVirtualNetworkFilterEnabled) stay local
// to each consuming module — only the fields meaningful to all three live here.
// A compile-time constant (not a module) so its fields can drive resource `for`-loops
// (e.g. Cosmos's ipRules) in consuming files, which a module output cannot do (BCP178).

@export()
var networkAccessRules = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  allowedIpRanges: []
}
