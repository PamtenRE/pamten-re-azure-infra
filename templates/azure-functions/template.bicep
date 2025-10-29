@description('Name of the Azure Function App.')
param name string

@description('Azure region.')
param location string

@description('Resource group name where the Function App is deployed.')
param resourceGroupName string

@description('Associated Storage Account name used by this Function App.')
param storageAccountName string

@description('Runtime for this Function App (python, node, java, dotnet).')
@allowed([
  'python'
  'node'
  'java'
  'dotnet'
])
param runtime string = 'python'

@description('App Service Plan SKU (e.g., Y1 for consumption, EP1 for elastic premium).')
param skuName string = 'Y1'

@description('Tags to apply to the Function App and its plan.')
param tags object = {}

@description('Optional environment variables / app settings as an array of {name,value} objects.')
param appSettings array = []

@description('Always On flag (required for Premium / Dedicated plans).')
param alwaysOn bool = false

// -----------------------------------------------------------------------------
// Derived values
// -----------------------------------------------------------------------------
var hostingPlanName = '${name}-plan'
var linuxFxVersion = runtime == 'python' ? 'Python|3.10' :
                     runtime == 'node' ? 'Node|18' :
                     runtime == 'java' ? 'Java|17' :
                     'DotNet|6.0'

// -----------------------------------------------------------------------------
// App Service Plan (only for non-consumption plans)
// -----------------------------------------------------------------------------
resource functionPlan 'Microsoft.Web/serverfarms@2023-12-01' = if (skuName != 'Y1') {
  name: hostingPlanName
  location: location
  sku: {
    name: skuName
    tier: skuName == 'EP1' ? 'ElasticPremium' : 'Dynamic'
  }
  properties: {
    reserved: true
  }
  tags: tags
}

// -----------------------------------------------------------------------------
// Function App
// -----------------------------------------------------------------------------
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: skuName == 'Y1' ? null : functionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      appSettings: concat(
        [
          {
            name: 'AzureWebJobsStorage'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=core.windows.net'
          }
          {
            name: 'FUNCTIONS_EXTENSION_VERSION'
            value: '~4'
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: runtime
          }
          {
            name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
            value: 'false'
          }
          {
            name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
            value: 'true'
          }
        ],
        appSettings
      )
    }
  }
  dependsOn: [
    functionPlan
  ]
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.name}.azurewebsites.net'
output functionAppId string = functionApp.id
output functionPlanId string = skuName == 'Y1' ? 'consumption-plan' : functionPlan.id
output functionPlanName string = skuName == 'Y1' ? 'consumption-plan' : functionPlan.name
