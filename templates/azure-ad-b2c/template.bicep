@description('Azure AD B2C tenant name (unique across directory).')
param tenantName string

@description('Friendly display name for the B2C tenant.')
param displayName string

@description('ISO country code for B2C tenant location (e.g., unitedstates).')
param countryCode string = 'unitedstates'

@description('Tags for FinOps and governance tracking.')
param tags object = {}

@description('Optional Azure Active Directory domain name (used for linking to apps).')
param domainName string = '${tenantName}.onmicrosoft.com'

// ----------------------------------------------------------------------------
// Note: Azure AD B2C tenants cannot be fully provisioned via Bicep or ARM.
// This resource acts as a governance placeholder and audit representation
// for compliance, tagging, and future tenant linking.
// ----------------------------------------------------------------------------

resource b2cInfo 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'b2c-placeholder-${tenantName}'
  location: 'eastus'  // region doesn't matter for logical placeholder
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '10.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    scriptContent: '''
      Write-Output "Azure AD B2C Tenant Placeholder for ${tenantName} (${displayName}) - ${countryCode}"
    '''
    arguments: ''
    environmentVariables: []
  }
  tags: tags
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
output b2cTenantName string = tenantName
output b2cDisplayName string = displayName
output b2cCountryCode string = countryCode
output b2cDomain string = domainName
output b2cInfoResourceId string = b2cInfo.id
output b2cInfoResourceName string = b2cInfo.name
