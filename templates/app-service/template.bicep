// Azure App Service template
// This template provisions an App Service plan and Web App.

param name string
param location string
param resourceGroupName string
@description('The SKU of the App Service plan (e.g. F1, B1, S1).')
param skuName string = 'F1'
@description('Tags applied to the resources.')
param tags object = {}

// App Service plan
resource plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-plan'
  location: location
  sku: {
    name: skuName
  }
  tags: tags
}

// Web App
resource app 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
  }
  tags: tags
}

output appName string = app.name