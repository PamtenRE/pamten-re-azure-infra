// Azure Functions template
// This template provisions a Consumption plan and a Function App.  Supply an existing
// storage account name for the Functions runtime.  The template does not deploy
// your function code.

param name string
param location string
param storageAccountName string
@description('Azure Functions runtime (e.g. dotnet, node, python, java).')
param runtime string = 'java'
@description('Tags applied to the resources.')
param tags object = {}

// Consumption plan for Functions
resource plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  tags: tags
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          // The storage account key must be provided; replace the placeholder or
          // consider using a Key Vault reference.
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=<replace-with-key>;EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
      ]
    }
  }
  tags: tags
}

output functionAppName string = functionApp.name