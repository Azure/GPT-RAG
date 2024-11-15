param name string
param location string = resourceGroup().location
param tags object = {}
param existingStorageResourceGroupName string
param storageReuse bool
param deployStorageAccount bool = true

@allowed([ 'Hot', 'Cool', 'Premium' ])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = false
param allowCrossTenantReplication bool = true
param allowSharedKeyAccess bool = false
param defaultToOAuthAuthentication bool = false
param deleteRetentionPolicy object = {}
@allowed([ 'AzureDnsZone', 'Standard' ])
param dnsEndpointType string = 'Standard'
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Disabled'
param sku object = { name: 'Standard_LRS' }
param containers array = []


resource existingStorage 'Microsoft.Storage/storageAccounts@2022-05-01' existing  = if (storageReuse && deployStorageAccount) {
  scope: resourceGroup(existingStorageResourceGroupName)
  name: name
}

resource newStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = if (!storageReuse && deployStorageAccount) {
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
    supportsHttpsTrafficOnly: true
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
    resource container 'containers' = [for container in containers: {
      name: container.name
      properties: {
        publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
      }
    }]
  }
}

output name string = !deployStorageAccount ? '' : storageReuse ? existingStorage.name : newStorage.name
output id string = !deployStorageAccount ? '' : storageReuse ? existingStorage.id : newStorage.id
output primaryEndpoints object = !deployStorageAccount ? {} : storageReuse ? existingStorage.properties.primaryEndpoints: newStorage.properties.primaryEndpoints
