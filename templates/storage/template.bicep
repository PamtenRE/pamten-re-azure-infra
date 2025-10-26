@description('Name of the Storage Account.')
param name string

@description('Azure region where this storage account will be created.')
param location string

@description('Resource group name.')
param resourceGroupName string

@description('Tags to apply to this storage account.')
param tags object = {}

@description('Enable static website hosting (true for frontend, false for backend storage).')
param enableStaticWebsite bool = false

@description('Access tier for the storage account (Hot or Cool).')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Replication type for redundancy (LRS, GRS, ZRS).')
@allowed([
  'LRS'
  'GRS'
  'ZRS'
])
param replicationType string = 'LRS'

@description('Allow public access to blobs (should be false in prod).')
param allowBlobPublicAccess bool = true

@description('Enable secure transfer (HTTPS only).')
param enableHttpsOnly bool = true

@description('Optional retention policy in days for deleted blobs (0 disables).')
param softDeleteRetentionDays int = 7

// ----------------------------------------------------------------------------
// Storage Account
// ----------------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_${replicationType}'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    supportsHttpsTrafficOnly: enableHttpsOnly
    minimumTlsVersion: 'TLS1_2'
    deleteRetentionPolicy: {
      enabled: softDeleteRetentionDays > 0
      days: softDeleteRetentionDays
    }
    blobRestoreStatus: {
      status: 'disabled'
    }
  }
  tags: tags
}

// ----------------------------------------------------------------------------
// Static Website (optional)
// ----------------------------------------------------------------------------
resource staticWebsite 'Microsoft.Storage/storageAccounts/staticWebsite@2023-01-01' = if (enableStaticWebsite) {
  parent: storageAccount
  name: 'default'
  properties: {
    enabled: true
    indexDocument: 'index.html'
    errorDocument404Path: 'index.html'
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output staticWebsiteUrl string = enableStaticWebsite ? storageAccount.properties.primaryEndpoints.web : ''
output staticWebsiteHostname string = enableStaticWebsite ? '${storageAccount.name}.z13.web.core.windows.net' : ''
