// Entry point for the dev environment
// This template deploys the core infrastructure for the RecruitEdge platform development environment

@allowed(['dev', 'test', 'staging', 'prod'])
@description('Environment name that determines resource naming and SKU selection.')
param environment string = 'dev'

// Resource naming variables
var prefix = 'recruitedge'
var baseName = '${prefix}-${environment}'

// Common tags that apply to all resources
var tags = {
  Environment: environment
  Project: prefix
  DeployedBy: 'bicep'
  Component: 'infrastructure'
  ManagedBy: 'platform-team'
}

@description('Primary Azure region for resource deployment.')
@allowed([
  'eastus'
  'eastus2'
  'westus'
  'westus2'
  'centralus'
])
param location string = 'eastus'

@minLength(4)
@maxLength(20)
@description('Administrator login for SQL server. Must be at least 4 characters.')
param administratorLogin string

@secure()
@minLength(12)
@description('Administrator password for SQL server. Must be at least 12 characters and meet complexity requirements.')
param administratorPassword string

@allowed([
  'F1'  // Free tier
  'B1'  // Basic tier
  'S1'  // Standard tier
  'P1V2'// Premium V2
])
@description('SKU for App Service plan. Use F1/B1 for dev, S1 for test, P1V2 for prod.')
param appServiceSku string = 'B1'

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('SQL database edition. Affects available features and pricing.')
param sqlEdition string = 'Basic'

@allowed([
  'Basic'    // 5 DTU
  'S0'       // 10 DTU
  'S1'       // 20 DTU
  'P1'       // 125 DTU
])
@description('SQL database SKU name. Must be compatible with selected edition.')
param sqlSku string = 'Basic'

// Resource naming function
func resourceName(service string) string => 'recruitedge-${environment}-${service}'

// Variables
var naming = {
  storage: replace(resourceName('sa'), '-', '')  // Storage accounts can't have hyphens
  sql: resourceName('sql')
  sqlDb: resourceName('db')
  webapp: resourceName('web')
  function: resourceName('func')
}

// Common tags applied to all resources
var commonTags = union({
  Environment: environment
  Project: 'recruitedge'
  DeployedBy: 'bicep'
  LastDeployment: utcNow('yyyy-MM-dd')
}, loadJsonContent('../common/tags.json'))

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

@allowed(['node', 'python', 'java', 'powershell', 'dotnet'])
@description('Runtime stack for the Function App.')
param functionRuntime string

// Provision Azure Functions app
module functionModule '../../templates/azure-functions/template.bicep' = {
  name: 'function'
  params: {
    name: '${baseName}-func'
    location: location
    storageAccountName: storageModule.outputs.storageAccountName
    runtime: functionRuntime
    tags: tags
  }
}
