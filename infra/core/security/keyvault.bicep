param name string
param location string = resourceGroup().location
param tags object = {}
param publicNetworkAccess string

param keyVaultReuse bool
param existingKeyVaultResourceGroupName string

@description('Secret Keys to add to App Configuration')
param secureAppSettings array

param tlsCertificateName string = 'gptrag-tls'

// @secure()
// param vmUserPasswordKey string
// @secure()
// param vmUserPassword string

param principalId string = ''

@description('Key Vault SKU name. Defaults to standard.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
@description('Whether soft deletion is enabled. Defaults to true.')
param enableSoftDelete bool = true
@description('Number of days to retain soft-deleted keys, secrets, and certificates. Defaults to 90.')
param retentionInDays int = 90
@description('Whether purge protection is enabled. Defaults to true.')
param enablePurgeProtection bool = true

resource existingKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = if (keyVaultReuse) {
  scope: resourceGroup(existingKeyVaultResourceGroupName)
  name: name  
}

resource newKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' = if (!keyVaultReuse) {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: skuName }
    publicNetworkAccess: publicNetworkAccess
    accessPolicies: []
    enableSoftDelete: enableSoftDelete
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: retentionInDays
  }
}

// Secret in Key Vault
resource secret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = [for (config, i) in secureAppSettings: {
  parent: newKeyVault
  name: replace(config.name, '_', '-')
  properties: {
      contentType: 'string'
      value:  config.value
  }
  tags: {}
}
]

output id string = keyVaultReuse ? existingKeyVault.id: newKeyVault.id
output name string = keyVaultReuse ? existingKeyVault.name: newKeyVault.name
output endpoint string = keyVaultReuse ? existingKeyVault.properties.vaultUri: newKeyVault.properties.vaultUri
output secrets array = [for (config, i) in secureAppSettings: {
  name: config.name
  value: concat('{"uri":"',secret[i].properties.secretUri, '"}')
}]
output tlsCertificateUri string = (!empty(tlsCertificateName)) ? 'https://${name}.vault.azure.net/certificates/${tlsCertificateName}' : ''
