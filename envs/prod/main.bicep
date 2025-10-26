// Entry point for the prod environment

@description('Environment name (e.g. dev, prod).')
param environment string = 'prod'
@description('Azure region to deploy resources.')
param location string = 'eastus2'
@description('Administrator login for SQL server.')
param administratorLogin string
@secure()
@description('Administrator password for SQL server.')
param administratorPassword string
@description('SKU for App Service plan (e.g. F1, B1, S1).')
param appServiceSku string = 'S1'
@description('SKU for the SQL database (e.g. Basic, S0, S2).')
param sqlSku string = 'S0'
@description('SQL database tier (e.g. Basic, Standard).')
param sqlEdition string = 'Standard'

// Additional parameters to control how many resources of each type to create.
@description('Number of web app instances to create. Use 1 for a single web app.')
param webCount int = 1
@description('Number of additional storage accounts to create (excluding the one used for Functions). Use 1 for a single storage account.')
param storageCount int = 1
@description('Number of Function Apps to create.')
param functionCount int = 1

var baseName = 'recruitedge-${environment}'
var tags = {
  Environment: environment
  Project: 'job-portal'
}

// Create a collection of indices for looping over resources
var webIndices = range(0, webCount)
var storageIndices = range(0, storageCount)
var functionIndices = range(0, functionCount)

// Create one or more storage accounts.  The first storage account can be used
// for Azure Functions; additional accounts can be used for blob storage or other needs.
module storageAccounts '../../templates/storage/template.bicep' = [for idx in storageIndices: {
  name: 'storage-${idx}'
  params: {
    name: '${baseName}sa${idx}'
    location: location
    // Use geo-redundant storage for production
    skuName: 'Standard_GRS'
    tags: tags
  }
}]

// Provision SQL server and database (single instance)
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

// Provision one or more App Service plans and Web Apps
module webApps '../../templates/app-service/template.bicep' = [for idx in webIndices: {
  name: 'appservice-${idx}'
  params: {
    name: '${baseName}-web${idx}'
    location: location
    resourceGroupName: resourceGroup().name
    skuName: appServiceSku
    tags: tags
  }
}]

// Provision one or more Azure Functions apps.  All Functions use the first storage
// account in the collection (index 0).  To use a different storage account, adjust
// the index as needed.
module functionApps '../../templates/azure-functions/template.bicep' = [for idx in functionIndices: {
  name: 'function-${idx}'
  params: {
    name: '${baseName}-func${idx}'
    location: location
    storageAccountName: storageAccounts[0].outputs.storageAccountName
    runtime: 'java'
    tags: tags
  }
}]

// Outputs to expose the names of created resources
output storageAccountNames array = [for idx in storageIndices: storageAccounts[idx].outputs.storageAccountName]
output webAppNames array = [for idx in webIndices: webApps[idx].outputs.appName]
output functionAppNames array = [for idx in functionIndices: functionApps[idx].outputs.functionAppName]
