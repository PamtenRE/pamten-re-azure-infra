@description('Name of the Azure Function App.')
param name string

@description('Azure region where the Function App should be deployed.')
param location string

@description('Resource group name. This is used for any resources that need a group reference, such as RBAC scope definitions.')
param resourceGroupName string

@description('Name of the Storage Account that backs the Function App. Must already exist in the same subscription.')
param storageAccountName string

@description('The runtime stack for the Function App. Supported values are python, node, java and dotnet.')
@allowed([
  'python'
  'node'
  'java'
  'dotnet'
])
param runtime string = 'python'

@description('The SKU for the hosting plan. Use Y1 for consumption or EP1/EP2 for Premium. When not Y1, a plan is created.')
param skuName string = 'Y1'

@description('Tags to apply to all resources created by this template.')
param tags object = {}

@description('Optional array of application settings. Each entry must be an object with `name` and `value` fields.')
param appSettings array = []

@description('AlwaysOn flag. Required to be true when using Premium or Dedicated plans.')
param alwaysOn bool = false

@description('Optional resource ID of a user‑assigned managed identity to attach to the Function App. Leave blank to use system‑assigned identity only.')
param userAssignedIdentityResourceId string = ''

@description('Resource ID of an existing Log Analytics workspace. Application Insights will be created in this template and wired to this workspace.')
param workspaceResourceId string

@description('Optional array of role assignments to apply to the Function App identity. Each entry must contain `roleDefinitionId` and `scope`.')
param roleAssignments array = []

// -----------------------------------------------------------------------------
// Derived values
// -----------------------------------------------------------------------------

// Name of the hosting plan derived from the function name
var hostingPlanName = '${name}-plan'

// Determine the appropriate linuxFxVersion based off of the requested runtime
var linuxFxVersion = runtime == 'python' ? 'Python|3.10' :
                     runtime == 'node'   ? 'Node|18'    :
                     runtime == 'java'   ? 'Java|17'    :
                                           'DotNet|6.0'

// Determine the identity configuration. When a user‑assigned identity ID is supplied,
// the Function App will have both system and user assigned identities. Otherwise,
// only a system assigned identity is configured.
var identityConfig = userAssignedIdentityResourceId == ''
  ? {
      type: 'SystemAssigned'
    }
  : {
      type: 'SystemAssigned,UserAssigned'
      userAssignedIdentities: {
        '${userAssignedIdentityResourceId}': {}
      }
    }

// Compose default application settings required for any Linux Function App
var defaultAppSettings = [
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
]

// -----------------------------------------------------------------------------
// Resource Definitions
// -----------------------------------------------------------------------------

// Create an App Service plan when using any tier other than the Y1 consumption plan
resource functionPlan 'Microsoft.Web/serverfarms@2023-12-01' = if (skuName != 'Y1') {
  name: hostingPlanName
  location: location
  sku: {
    name: skuName
    tier: skuName == 'EP1' || skuName == 'EP2' || skuName == 'EP3' ? 'ElasticPremium' : 'Dynamic'
    capacity: 1
  }
  properties: {
    // Use a reserved (Linux) plan when running Node or Python runtimes
    reserved: runtime == 'python' || runtime == 'node'
  }
  tags: tags
}

// Create a workspace‑based Application Insights instance for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-ai'
  location: location
  tags: tags
  kind: 'other'
  properties: {
    // Set the application type appropriate for functions
    Application_Type: 'web'
    // Link this App Insights to the provided Log Analytics workspace
    WorkspaceResourceId: workspaceResourceId
  }
}

// Main Function App resource
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: identityConfig
  properties: {
    // For consumption plans (Y1) there is no dedicated serverFarmId
    serverFarmId: skuName == 'Y1' ? null : functionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      appSettings: concat(
        // Combine default settings, Application Insights settings, and user‑provided settings
        concat(defaultAppSettings, [
          {
            name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
            value: appInsights.properties.InstrumentationKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appInsights.properties.ConnectionString
          }
        ]),
        appSettings
      )
    }
  }
  dependsOn: [
    functionPlan
    appInsights
  ]
}

// Create RBAC role assignments for the Function App identity
// Each entry in the roleAssignments parameter should provide a roleDefinitionId and scope
resource roleAssignmentsRes 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, idx) in roleAssignments: {
  name: guid(functionApp.id, role.roleDefinitionId, idx)
  scope: role.scope
  properties: {
    roleDefinitionId: role.roleDefinitionId
    principalId: functionApp.identity.principalId
  }
  dependsOn: [
    functionApp
  ]
}]

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------

@description('The name of the newly created Function App')
output functionAppName string = functionApp.name

@description('URL at which the Function App can be accessed')
output functionAppUrl string = 'https://${functionApp.name}.azurewebsites.net'

@description('The ARM resource ID of the Function App')
output functionAppId string = functionApp.id

@description('Resource ID of the hosting plan used by the Function App')
output functionPlanId string = skuName == 'Y1' ? '' : functionPlan.id

@description('Name of the hosting plan used by the Function App')
output functionPlanName string = skuName == 'Y1' ? '' : functionPlan.name

@description('Name of the Application Insights resource')
output appInsightsName string = appInsights.name

@description('Instrumentation Key for the Application Insights instance')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Principal ID of the managed identity assigned to the Function App')
output identityPrincipalId string = functionApp.identity.principalId
