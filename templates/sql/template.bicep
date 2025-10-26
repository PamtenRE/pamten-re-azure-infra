@description('SQL Server name.')
param serverName string

@description('SQL Database name.')
param databaseName string

@description('Azure location.')
param location string

@description('Resource group name.')
param resourceGroupName string

@description('SQL Administrator login username.')
param administratorLogin string = 'sqladmin'

@description('SQL Administrator password (from Key Vault or secret variable).')
@secure()
param administratorPassword string

@description('SKU name for SQL Database (e.g., Basic, S0, S1, GP_Gen5_2).')
param skuName string = 'Basic'

@description('Edition for SQL Database (Basic, Standard, GeneralPurpose, BusinessCritical).')
param edition string = 'Basic'

@description('Enable public network access (true for dev, false for prod).')
param publicNetworkAccess bool = true

@description('Tags to apply to SQL resources.')
param tags object = {}

@description('Optional collation for the SQL Database.')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

// ----------------------------------------------------------------------------
// SQL Server
// ----------------------------------------------------------------------------
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
  }
  tags: tags
}

// ----------------------------------------------------------------------------
// SQL Database
// ----------------------------------------------------------------------------
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: '${sqlServer.name}/${databaseName}'
  location: location
  sku: {
    name: skuName
    tier: edition
  }
  properties: {
    collation: collation
    readScale: 'Disabled'
  }
  tags: tags
  dependsOn: [
    sqlServer
  ]
}

// ----------------------------------------------------------------------------
// Firewall rule for dev (optional)
// ----------------------------------------------------------------------------
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = if (publicNetworkAccess) {
  name: '${sqlServer.name}/AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    sqlServer
  ]
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output sqlServerResourceId string = sqlServer.id
output sqlDatabaseResourceId string = sqlDatabase.id
output sqlConnectionString string = concat(
  'Server=tcp:', sqlServer.name, '.database.windows.net,1433;',
  'Database=', databaseName, ';',
  'User ID=', administratorLogin, ';',
  'Password=', administratorPassword, ';',
  'Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;'
)
output serverFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
