param tags object = {}
param keyVaultName string
param contentType string = 'string'

param enabled bool = true
param exp int = 0
param nbf int = 0

@description('The value of the secret. storage access, but do not hard code any secrets in your templates')
@secure()
param secretValues object = {}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' =  [for secret in items(secretValues): {
  name: secret.value.name
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: enabled
      exp: exp
      nbf: nbf
    }
    contentType: contentType
    value: secret.value.value
  }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}
