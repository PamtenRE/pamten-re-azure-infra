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

@description('Optional environment variables / app settings.')
param appSettings object = {}

@description('Always On flag (required for Premium / Dedicated plans).')
param alwaysOn bool = false

// -----------------------------------------------------------------------------
// Derived Names
// -----------------------------------------------------------------------------
var hostingPlanName = '${name}-plan'
var storageAccountId = resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
var linuxFxVersion = runtime == 'python' ? 'Python|3.10' :
                     runtime == 'node' ? 'Node|18' :
                     runtime == 'java' ? 'Java|17' :
                     'DotNet|6.0'

// -----------------------------------------------------------------------------
// Hosting Plan (Consumption or Premium)
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
  properties: {
    serverFarmId: skuName == 'Y1'
      ? null
      : functionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: concat('DefaultEndpointsProtocol=https;AccountName=', storageAccountName, ';EndpointSuffix=core.windows.net')
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
        for kvp in appSettings: {
          name: kvp.key
          value: kvp.value
        }
      ]
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
