@description('Name of the identity')
param name string
@description('Location of the identity')
param location string
@description('Resource group name')
param resourceGroupName string
@description('Tags')
param tags object = {}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output principalId string = userAssignedIdentity.properties.principalId
output clientId string = userAssignedIdentity.properties.clientId
