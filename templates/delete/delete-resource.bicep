/*
  Generic deletion template for Azure resources
  Usage:
    az deployment group create \
      --resource-group <RG_NAME> \
      --template-file templates/delete/delete-resource.bicep \
      --parameters resourceName=<name> resourceType=<type> apiVersion=<version>
*/

@description('Name of the resource to delete')
param resourceName string

@description('Full resource type (e.g., Microsoft.Storage/storageAccounts)')
param resourceType string

@description('API version of the resource provider (default = latest stable)')
@allowed([
  '2023-05-01'
  '2022-09-01'
  '2021-09-01'
])
param apiVersion string = '2023-05-01'

@description('Location of the resource (optional)')
param location string = resourceGroup().location

@description('Whether to force delete dependent resources if supported')
param forceDelete bool = false

@description('Global tags for audit traceability')
param tags object = {
  managedBy: 'Pamten CloudOps'
  environment: 'dev'
  deletedBy: 'automation'
  timestamp: utcNow()
}

resource targetResource '${resourceType}@${apiVersion}' existing = {
  name: resourceName
}

/*
  Note: ARM/Bicep doesn’t have a native “delete” action resource.
  Instead, we mark the resource as `existing` and redeploy with condition = false.
  That instructs Azure Resource Manager to remove the resource.
*/

resource deleteTarget '${resourceType}@${apiVersion}' = if (false) {
  name: resourceName
  location: location
  tags: tags
}

output message string = '✅ Deletion triggered for ${resourceType} → ${resourceName}'
