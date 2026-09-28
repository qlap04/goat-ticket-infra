// modules/database/sql.bicep
// Azure SQL Server (Entra-only auth) + Database — public access disabled, private endpoint only

@description('Environment for SQL Server')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Entra ID object ID of the admin — defaults to whoever runs the deployment, override if needed')
param sqlAdminObjectId string = deployer().objectId

@description('Entra ID admin display name — defaults to the deployer objectId since Bicep deployer() has no userPrincipalName property, override with a real email/name if desired')
param sqlAdminLogin string = deployer().objectId

var sqlServerName = 'sql-goat-${environment}'
var sqlDatabaseName = 'sqldb-goat'

resource sqlServer 'Microsoft.Sql/servers@2025-01-01' = {
  name: sqlServerName
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminLogin
      principalType: 'User'
      sid: sqlAdminObjectId
      tenantId: deployer().tenantId
    }
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2025-01-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
}

output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseId string = sqlDatabase.id
