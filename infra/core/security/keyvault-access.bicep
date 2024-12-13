param permissions object = { secrets: [ 'get', 'list', 'set', 'delete' ] }
param principalId string
param resourceName string

resource resource 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: resourceName
}

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: resource
  name: 'add'
  properties: {
    accessPolicies: [ {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: permissions
      } ]
  }
}
