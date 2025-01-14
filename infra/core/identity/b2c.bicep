@description('Name of the B2C tenant')
param name string

@description('Tags to apply to the B2C tenant')
param tags object = {}

@description('B2C tenant country/region code (e.g., US for United States)')
param countryCode string = 'US'

@description('Display name of the B2C tenant')
param displayName string = name

resource b2cTenant 'Microsoft.AzureActiveDirectory/b2cDirectories@2021-04-01' = {
  name: name
  location: 'global' // Change from 'United States' to 'global'
  tags: tags
  properties: {
    createTenantProperties: {
      countryCode: countryCode
      displayName: displayName
    }
  }
}
