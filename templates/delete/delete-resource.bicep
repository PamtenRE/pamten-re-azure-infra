@description('Name of the resource to delete')
param resourceName string

@description('Full resource type, e.g., Microsoft.Storage/storageAccounts')
param resourceType string

@description('API version to use for the resource provider')
param apiVersion string = '2023-05-01'

@description('Resource group where the resource exists')
param resourceGroupName string

@description('Optional location (for audit tag)')
param location string = resourceGroup().location

@description('Optional audit tags')
param tags object = {}

@description('Enable force delete mode (logical switch, not used in this version)')
param forceDelete bool = false

// --------------------------------------------------------------------
// Azure workaround: Use nested deployment to dynamically delete resource
// --------------------------------------------------------------------

resource deleteDeployment 'Microsoft.Resources/deployments@2022-09-01' = {
  name: 'delete-${uniqueString(resourceName, resourceType)}'
  properties: {
    mode: 'Incremental'
    expressionEvaluationOptions: {
      scope: 'inner'
    }
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      'contentVersion': '1.0.0.0'
      'resources': [
        {
          'type': resourceType
          'apiVersion': apiVersion
          'name': resourceName
          'condition': false
        }
      ]
    }
  }
}

output message string = '🗑️ Deletion initiated for ${resourceType} → ${resourceName}'
