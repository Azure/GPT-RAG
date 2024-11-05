// core/identity/b2c.bicep
param name string
param location string = resourceGroup().location
param tags object = {}

@description('B2C tenant country/region')
param countryCode string = 'US'

@description('B2C tenant data residency')
param dataResidency string = 'United States'

@description('Display name of the B2C tenant')
param displayName string = name

resource b2cTenant 'Microsoft.AzureActiveDirectory/b2cDirectories@2021-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'A0'
  }
  properties: {
    createTenantProperties: {
      countryCode: countryCode
      displayName: displayName
      dataResidency: dataResidency
    }
  }
}

output id string = b2cTenant.id
output name string = b2cTenant.name
output tenantId string = b2cTenant.properties.tenantId
