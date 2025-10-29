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
// Azure workaround: nested deployment to dynamically delete resource
// --------------------------------------------------------------------

resource deleteDeployment 'Microsoft.Resources/deployments@2022-09-01' = {
  name: 'delete-${uniqueString(resourceName, resourceType)}'
  properties: {
    mode: 'Incremental'
    expressionEvaluationOptions: {
      scope: 'inner'
    }
    parameters: {
      resourceTypeParam: {
        value: resourceType
      }
      apiVersionParam: {
        value: apiVersion
      }
      resourceNameParam: {
        value: resourceName
      }
    }
    
  }
}

output message string = 'Deletion initiated for ${resourceType} → ${resourceName}'
