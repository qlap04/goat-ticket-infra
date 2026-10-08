// deploy/bicep/modules/database/sqlAuditing.bicep
// Separate from sql.bicep because auditing needs Storage RBAC granted first (rbacModule),
// which itself needs sqlServer's principalId — solves circular dependency, same pattern as Firewall/RouteTable

@description('Name of the SQL Server (existing)')
param sqlServerName string

@description('Blob service endpoint of the storage account that holds SQL audit logs. Taken from the storage account itself rather than assembled from its name, so the endpoint stays correct in every cloud and cannot drift from the account.')
param runtimeStorageAccountBlobEndpoint string

resource sqlServer 'Microsoft.Sql/servers@2025-01-01' existing = {
  name: sqlServerName
}

resource sqlServerAuditing 'Microsoft.Sql/servers/auditingSettings@2025-01-01' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: runtimeStorageAccountBlobEndpoint
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: true
  }
}
