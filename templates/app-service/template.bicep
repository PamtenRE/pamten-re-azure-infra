@description('Name of the Web App.')
param name string

@description('Azure region where this Web App should be deployed.')
param location string

@description('Resource group name where this Web App should be deployed.')
param resourceGroupName string

@description('App Service Plan SKU (e.g., B1, P1v2).')
param skuName string = 'B1'

@description('Runtime stack: dotnet, java, python, node, etc.')
@allowed([
  'dotnet'
  'java'
  'python'
  'node'
])
param runtime string = 'python'

@description('Tags to apply to this Web App and its plan.')
param tags object = {}

@description('Optional environment variable map for app settings.')
param appSettings object = {}

@description('Optional flag to enable Always On (recommended for prod).')
param alwaysOn bool = false

// Generate plan name based on app name to keep things consistent
var planName = '${name}-plan'

// -----------------------------------------------------------------------------
// App Service Plan
// -----------------------------------------------------------------------------
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: skuName
    capacity: 1
  }
  properties: {
    reserved: runtime == 'python' || runtime == 'node' ? true : false  // Linux plans for non-Windows stacks
  }
  tags: tags
}

// -----------------------------------------------------------------------------
// Web App
// -----------------------------------------------------------------------------
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: runtime == 'python' ? 'PYTHON|3.10' :
                      runtime == 'java' ? 'JAVA|17-java17' :
                      runtime == 'node' ? 'NODE|18-lts' :
                      'DOTNETCORE|6.0'
      alwaysOn: alwaysOn
      appSettings: [
        for kvp in union({
          "APPINSIGHTS_INSTRUMENTATIONKEY": ""
          "SCM_DO_BUILD_DURING_DEPLOYMENT": "true"
        }, appSettings): {
          name: kvp.key
          value: kvp.value
        }
      ]
    }
  }
  dependsOn: [
    appServicePlan
  ]
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output appServiceName string = webApp.name
output appServiceUrl string = 'https://${webApp.name}.azurewebsites.net'
output appServicePlanName string = appServicePlan.name
output appServicePlanId string = appServicePlan.id
