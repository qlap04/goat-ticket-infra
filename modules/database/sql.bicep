// TODO: Azure SQL Server + database with private endpoint-only access
// modules/database/sql.bicep
// TODO: Azure SQL Server (Entra-only auth) + Database — public access disabled, private endpoint only
@description('Environment for SQL Server')
@allowed(['dev', 'prod'])
param environment string

@description('location of a rg')
param location string = resourceGroup().location

@description('Entra ID object ID of the admin — defaults to whoever runs the deployment, override if needed')
param sqlAdminObjectId string = deployer().objectId

@description('Entra ID admin display name — defaults to deployer\'s email/UPN, override if needed')
param sqlAdminLogin string = deployer().userPrincipalName

var sqlServerName = 'sql-goat-${environment}'
var sqlDatabaseName = 'sqldb-goat'

resource sqlServer 'Microsoft.Sql/servers@2025-01-01' = {
  name: sqlServerName
  location: location
  properties: {
    // administrators block (Entra ID admin, not be administratorLogin/Password),
    // publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminLogin
      principalType: 'User'
      sid: sqlAdminObjectId
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
    // around 15 USD/month
    name: 'S0'
    tier: 'Standard'
  }
}

output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseId string = sqlDatabase.id
