// Azure SQL server and database template

param location string
param serverName string
param databaseName string
@description('The administrator username for the SQL server.')
param administratorLogin string
@secure()
@description('The administrator password for the SQL server.')
param administratorPassword string
@description('The name of the pricing tier (e.g. Basic, S0, S1).')
param skuName string = 'Basic'
@description('The edition of the SQL database (e.g. Basic, Standard).')
param edition string = 'Basic'
@description('Tags applied to the resources.')
param tags object = {}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '12.0'
  }
  tags: tags
}

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: '${serverName}/${databaseName}'
  location: location
  sku: {
    name: skuName
    tier: edition
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
  tags: tags
}

output serverFullyQualifiedDomainName string = '${sqlServer.name}.database.windows.net'
output databaseNameOut string = database.name