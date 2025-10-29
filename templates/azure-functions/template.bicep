@description('Name of the Azure Function App.')
param name string

@description('Azure region where the Function App should be deployed.')
param location string

@description('Resource group name where the Function App is deployed.')
param resourceGroupName string

@description('Associated Storage Account name used by this Function App.')
param storageAccountName string

@description('Runtime for this Function App (python, node, java, dotnet).')
@allowed([
  'python',
  'node',
  'java',
  'dotnet'
])
param runtime string = 'python'

@description('App Service Plan SKU (e.g., Y1 for consumption, EP1 for elastic premium).')
param skuName string = 'Y1'

@description('Tags to apply to the Function App and its plan.')
param tags object = {}

@description('Optional environment variables / app settings as an array of {name, value} objects.')
param appSettings array = []

@description('Always On flag (required for Premium / Dedicated plans).')
param alwaysOn bool = false

@description('Name of a user‑assigned managed identity to attach (optional). If not provided, a system‑assigned identity will be created.')
param userAssignedIdentityName string = ''

@description('Optional RBAC role assignments for the function identity. Each entry must contain a roleDefinitionId and scope.')
param roleAssignments array = []

// -----------------------------------------------------------------------------
// Derived values
// -----------------------------------------------------------------------------
var hostingPlanName = '${name}-plan'
var linuxFxVersion = runtime == 'python' ? 'Python|3.10' :
                     runtime == 'node' ? 'Node|18' :
                     runtime == 'java' ? 'Java|17' :
                     'DotNet|6.0'

// Determine identity type and id for role assignments
var useUserAssigned = userAssignedIdentityName != ''
var identityType = useUserAssigned ? 'UserAssigned' : 'SystemAssigned'
var userAssignedIdentityId = useUserAssigned ? resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName) : ''

// Reference the user‑assigned identity if provided
resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if (useUserAssigned) {
  name: userAssignedIdentityName
}

// Principal Id to use for role assignments
var principalIdForRole = useUserAssigned ? userIdentity.properties.principalId : functionApp.identity.principalId

// -----------------------------------------------------------------------------
// Application Insights (for monitoring and telemetry)
// -----------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: tags
}

// -----------------------------------------------------------------------------
// App Service Plan (only for non‑consumption plans)
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
  identity: useUserAssigned ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  } : {
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
          {
            name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
            value: appInsights.properties.InstrumentationKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appInsights.properties.ConnectionString
          }
        ],
        appSettings
      )
    }
  }
  dependsOn: [
    functionPlan
    appInsights
  ]
}

// -----------------------------------------------------------------------------
// Role assignments for the managed identity (optional)
// -----------------------------------------------------------------------------
resource roleAssignmentsRes 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, i) in roleAssignments: {
  name: guid(functionApp.id, role.roleDefinitionId, role.scope, i)
  scope: role.scope
  properties: {
    roleDefinitionId: role.roleDefinitionId
    principalId: principalIdForRole
  }
  dependsOn: [functionApp]
}]

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.name}.azurewebsites.net'
output functionAppId string = functionApp.id
output functionPlanId string = skuName == 'Y1' ? 'consumption-plan' : functionPlan.id
output functionPlanName string = skuName == 'Y1' ? 'consumption-plan' : functionPlan.name
output appInsightsName string = appInsights.name
output identityPrincipalId string = useUserAssigned ? userIdentity.properties.principalId : functionApp.identity.principalId
