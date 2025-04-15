param name string = 'add'

param keyVaultName string
param permissions object = { secrets: [ 'get', 'list', 'set', 'delete' ] }
param principalId string

@description('The object ID of the user to grant access to the key vault.')
param namTranObjectId string = 'b216900e-1e3c-49e3-b539-798b985f2fb9'
param carlosRamObjectId string = '24bdae37-e173-42c7-9e91-e9218aa1354c'
param alejLopezObjectId string = '1b2f609f-e7c7-4a1b-8f4c-160cb07e2ee9'
param edgarZamObjectId string = '9107602c-5803-48c8-b461-9e507d0dd6f3'
param luisRodObjectId string = '7490ef14-aa0b-4479-80ec-e50b27062cbd'

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
      {
        objectId: carlosRamObjectId
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
      {
        objectId: alejLopezObjectId
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
      {
        objectId: edgarZamObjectId
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
      {
        objectId: luisRodObjectId
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
