// Entry point for the dev environment

@description('Environment name (e.g. dev, prod).')
param environment string = 'dev'
@description('Azure region to deploy resources.')
param location string = 'eastus'
@description('Administrator login for SQL server.')
param administratorLogin string
@secure()
@description('Administrator password for SQL server.')
param administratorPassword string
@description('SKU for App Service plan (e.g. F1, B1, S1).')
param appServiceSku string = 'B1'
@description('SKU for the SQL database (e.g. Basic, S0).')
param sqlSku string = 'Basic'
@description('SQL database tier (e.g. Basic, Standard).')
param sqlEdition string = 'Basic'

var baseName = 'recruitedge-${environment}'
var tags = {
  Environment: environment
  Project: 'job-portal'
}

// Provision storage account
module storageModule '../../templates/storage/template.bicep' = {
  name: 'storage'
  params: {
    name: '${baseName}sa'
    location: location
    tags: tags
  }
}

// Provision SQL server and database
module sqlModule '../../templates/sql/template.bicep' = {
  name: 'sql'
  params: {
    location: location
    serverName: '${baseName}-sqlsrv'
    databaseName: '${baseName}-db'
    administratorLogin: administratorLogin
    administratorPassword: administratorPassword
    skuName: sqlSku
    edition: sqlEdition
    tags: tags
  }
}

// Provision App Service plan and Web App
module appModule '../../templates/app-service/template.bicep' = {
  name: 'appservice'
  params: {
    name: '${baseName}-web'
    location: location
    resourceGroupName: resourceGroup().name
    skuName: appServiceSku
    tags: tags
  }
}

// Provision Azure Functions app
module functionModule '../../templates/azure-functions/template.bicep' = {
  name: 'function'
  params: {
    name: '${baseName}-func'
    location: location
    storageAccountName: storageModule.outputs.storageAccountName
    runtime: 'java' // adjust to 'python' for Python functions
    tags: tags
  }
}
