// core/identity/b2c.bicep
param name string
param tags object = {}

@description('B2C tenant country/region')
param countryCode string = 'US'

@description('Display name of the B2C tenant')
param displayName string = name

resource b2cTenant 'Microsoft.AzureActiveDirectory/b2cDirectories@2021-04-01' = {
  name: name
  location: 'unitedstates'
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'A0'
  }
  properties: {
    createTenantProperties: {
      countryCode: countryCode
      displayName: displayName
    }
  }
}

output id string = b2cTenant.id
output name string = b2cTenant.name
output tenantId string = b2cTenant.properties.tenantId
