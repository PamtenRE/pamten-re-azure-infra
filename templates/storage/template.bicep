// Azure Storage Account template

param name string
param location string
@description('SKU of the storage account (e.g. Standard_LRS, Standard_GRS).')
param skuName string = 'Standard_LRS'
@description('Tags applied to the storage account.')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
  tags: tags
}

output storageAccountName string = storageAccount.name