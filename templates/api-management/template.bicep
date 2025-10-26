@description('Name of the API Management instance.')
param name string

@description('Azure location.')
param location string

@description('Resource group name where APIM should be deployed.')
param resourceGroupName string

@description('SKU name for API Management (Consumption_0, Developer, Basic, Standard).')
param skuName string = 'Consumption_0'

@description('Optional publisher email for APIM admin contact.')
param publisherEmail string = 'admin@recruitedge.com'

@description('Optional publisher name for APIM admin contact.')
param publisherName string = 'RecruitEdge Platform'

@description('Tags to apply to the APIM instance.')
param tags object = {}

resource apiManagement 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: name
  location: location
  sku: {
    name: skuName
    capacity: 0
  }
  publisherEmail: publisherEmail
  publisherName: publisherName
  tags: tags
}

output apimName string = apiManagement.name
output apimResourceId string = apiManagement.id
output apimHostname string = apiManagement.properties.gatewayUrl
