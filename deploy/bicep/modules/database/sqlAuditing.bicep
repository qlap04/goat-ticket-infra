// deploy/bicep/modules/database/sqlAuditing.bicep
// Separate from sql.bicep because auditing needs Storage RBAC granted first (rbacModule),
// which itself needs sqlServer's principalId — solves circular dependency, same pattern as Firewall/RouteTable

@description('Name of the SQL Server (existing)')
param sqlServerName string

@description('Storage account name to write SQL audit logs to')
param runtimeStorageAccountName string

resource sqlServer 'Microsoft.Sql/servers@2025-01-01' existing = {
  name: sqlServerName
}

resource sqlServerAuditing 'Microsoft.Sql/servers/auditingSettings@2025-01-01' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: 'https://${runtimeStorageAccountName}.blob.core.windows.net'
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: true
  }
}
