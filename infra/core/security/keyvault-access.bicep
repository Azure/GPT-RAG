param name string = 'add'

param keyVaultName string
param permissions object = { secrets: [ 'get', 'list', 'set', 'delete' ] }
param principalId string

@description('The object ID of the user to grant access to the key vault.')
param namTranObjectId string = 'b216900e-1e3c-49e3-b539-798b985f2fb9'

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: keyVault
  name: name
  properties: {
    accessPolicies: [ {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: permissions
      }
      {
        objectId: namTranObjectId
        tenantId: subscription().tenantId
        permissions: {
          certificates: []
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
        }
      }
     ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}
