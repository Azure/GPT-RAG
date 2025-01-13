param name string
param location string = resourceGroup().location
param tags object = {}

@allowed(['Hot', 'Cool', 'Premium'])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = false
param allowCrossTenantReplication bool = true
param allowSharedKeyAccess bool = true
param defaultToOAuthAuthentication bool = false
param deleteRetentionPolicy object = {}
@allowed(['AzureDnsZone', 'Standard'])
param dnsEndpointType string = 'Standard'
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'
param sku object = { name: 'Standard_LRS' }
param secretName string = 'storageConnectionString'
param keyVaultName string

param containers array = []

// Add parameter for SAS token expiry with utcNow() as default
@description('Expiry date for SAS token in ISO 8601 format. Set to maximum allowed date (year 9999).')
param sasTokenExpiry string = dateTimeAdd(utcNow(), 'P3Y')

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    dnsEndpointType: dnsEndpointType
    minimumTlsVersion: minimumTlsVersion
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: publicNetworkAccess
  }

  resource blobServices 'blobServices' = if (!empty(containers)) {
    name: 'default'
    properties: {
      deleteRetentionPolicy: deleteRetentionPolicy
    }
    resource container 'containers' = [
      for container in containers: {
        name: container.name
        properties: {
          publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
        }
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: secretName
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
  }
}

var serviceSasToken = listServiceSAS(storage.id, '2021-08-01', {
  canonicalizedResource: '/blob/${storage.name}/${containers[0].name}'
  signedProtocol: 'https'
  signedResourceTypes: 'o'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: sasTokenExpiry
}).serviceSasToken

resource keyVaultSasToken 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(containers)) {
  name: 'blobSasToken'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
    value: serviceSasToken
  }
}

output name string = storage.name
output id string = storage.id
output primaryEndpoints object = storage.properties.primaryEndpoints
