@description('Target environment name. Example: dev, prod')
param environment string

@description('Azure region for this environment (ex: eastus)')
param location string = 'eastus'

@description('Resource group name where these resources should be deployed')
param resourceGroupName string

@description('SKU for App Services (ex: B1 for dev, P1v2 for prod)')
param appServiceSkuName string

@description('SKU / tier for SQL or database sizing (ex: Basic for dev, S1/SKU for prod)')
param sqlSkuName string
@description('Edition for SQL DB (ex: Basic, Standard)')
param sqlEdition string

@description('API Management SKU (ex: Consumption_0 for dev, Developer/Basic for prod)')
param apiManagementSkuName string

@description('Global tags enforced by governance / FinOps. This will be merged with any resource-level tags.')
param globalTags object = {}

@description('Optional extra tags to apply to the RecruitEdge Java API app service (overrides/extends globalTags).')
param javaApiTags object = {}

@description('Optional extra tags to apply to the RecruitEdge Python API app service (overrides/extends globalTags).')
param pythonApiTags object = {}

@description('Optional extra tags to apply to python function app.')
param pythonFuncTags object = {}

@description('Optional extra tags to apply to node function app.')
param nodeFuncTags object = {}

@description('Optional extra tags to apply to the static web app / frontend.')
param webTags object = {}

@description('Optional extra tags to apply to API Management.')
param apimTags object = {}

@description('Optional extra tags for SQL.')
param sqlTags object = {}

@description('Optional extra tags for storage.')
param storageTags object = {}

@description('Optional extra tags for B2C.')
param b2cTags object = {}


// Helper to merge globalTags with local overrides.
// Resource-level values win over global values.
function mergeTags(globalObj object, localObj object) object {
  return union(globalObj, localObj)
}


// -----------------------------------------------------------------------------
// Storage Account (shared / general storage, static content, function backing)
// -----------------------------------------------------------------------------
module storage 'templates/storage/template.bicep' = {
  name: 'storage-${environment}'
  params: {
    name: 'recruitedge${environment}sa'
    location: location
    resourceGroupName: resourceGroupName
    enableStaticWebsite: false // true only for React frontend
    allowBlobPublicAccess: environment == 'dev'
    tags: mergeTags(globalTags, storageTags)
  }
}



// -----------------------------------------------------------------------------
// SQL Server + Database
// -----------------------------------------------------------------------------
module sql 'templates/sql/template.bicep' = {
  name: 'sql-${environment}'
  params: {
    serverName: 'recruitedge-${environment}-sqlsrv'
    databaseName: 'recruitedge-${environment}-db'
    location: location
    resourceGroupName: resourceGroupName
    administratorLogin: env('SQL_ADMIN_USER')
    administratorPassword: env('SQL_ADMIN_PWD')
    skuName: sqlSkuName
    edition: sqlEdition
    publicNetworkAccess: environment == 'dev'
    tags: mergeTags(globalTags, sqlTags)
  }
}



// -----------------------------------------------------------------------------
// App Service - Java backend API
// -----------------------------------------------------------------------------
module javaApi 'templates/app-service/template.bicep' = {
  name: 'appservice-java-${environment}'
  params: {
    name: 'recruitedge-${environment}-java-api'
    location: location
    resourceGroupName: resourceGroupName
    skuName: appServiceSkuName
    tags: mergeTags(globalTags, javaApiTags)
  }
}


// -----------------------------------------------------------------------------
// App Service - Python backend API (ML / match engine)
// -----------------------------------------------------------------------------
module pythonApi 'templates/app-service/template.bicep' = {
  name: 'appservice-python-${environment}'
  params: {
    name: 'recruitedge-${environment}-python-api'
    location: location
    resourceGroupName: resourceGroupName
    skuName: appServiceSkuName
    runtime: 'python'
    alwaysOn: environment == 'prod'
    tags: mergeTags(globalTags, pythonApiTags)
  }
}


// -----------------------------------------------------------------------------
// Azure Function App - Python (resume parsing, notifications, etc.)
// -----------------------------------------------------------------------------
module pythonFunc 'templates/azure-functions/template.bicep' = {
  name: 'func-python-${environment}'
  params: {
    name: 'recruitedge-${environment}-func-python'
    location: location
    resourceGroupName: resourceGroupName
    storageAccountName: 'recruitedge${environment}sa'
    runtime: 'python'
    skuName: environment == 'prod' ? 'EP1' : 'Y1'
    alwaysOn: environment == 'prod'
    tags: mergeTags(globalTags, pythonFuncTags)
  }
}


// -----------------------------------------------------------------------------
// Azure Function App - Node (webhooks, light event handlers, etc.)
// -----------------------------------------------------------------------------
module nodeFunc 'templates/azure-functions/template.bicep' = {
  name: 'func-node-${environment}'
  params: {
    name: 'recruitedge-${environment}-func-node'
    location: location
    resourceGroupName: resourceGroupName
    storageAccountName: 'recruitedge${environment}sa'
    runtime: 'node'
    tags: mergeTags(globalTags, nodeFuncTags)
  }
}


// -----------------------------------------------------------------------------
// Static Website - React Frontend (hosted in Storage static website)
// -----------------------------------------------------------------------------
module staticWeb 'templates/storage/template.bicep' = {
  name: 'staticweb-${environment}'
  params: {
    name: 'recruitedge${environment}websa'
    location: location
    resourceGroupName: resourceGroupName
    enableStaticWebsite: true
    allowBlobPublicAccess: true
    tags: mergeTags(globalTags, webTags)
  }
}


// -----------------------------------------------------------------------------
// API Management - Gateway in front of the APIs / Functions
// -----------------------------------------------------------------------------
module apim 'templates/api-management/template.bicep' = {
  name: 'apim-${environment}'
  params: {
    name: 'recruitedge-${environment}-api'
    location: location
    resourceGroupName: resourceGroupName
    skuName: apiManagementSkuName
    tags: mergeTags(globalTags, apimTags)
  }
}


// -----------------------------------------------------------------------------
// Azure AD B2C (placeholder)
// Note: B2C tenant creation cannot be automated 100% with ARM/Bicep.
// We deploy a stub or "no-op" resource so it shows up in reporting,
// and we still attach tags for governance / cost allocation.
// -----------------------------------------------------------------------------
module b2c 'templates/azure-ad-b2c/template.bicep' = {
  name: 'b2c-${environment}'
  params: {
    tenantName: 'recruitedge${environment}b2c'
    displayName: 'RecruitEdge ${environment}'
    countryCode: 'unitedstates'
    tags: mergeTags(globalTags, b2cTags)
  }
}
