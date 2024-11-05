param name string
param location string
param tags object
param administratorLogin string
@secure()
param administratorLoginPassword string
param databaseName string
param keyVaultName string
param secretName string

// Add server configuration parameters based on ARM template
param serverEdition string = 'Burstable'
param storageSizeGB int = 32
param storageIops int = 360
param version string = '8.0.21'
param backupRetentionDays int = 7
param geoRedundantBackup string = 'Disabled'
param availabilityZone string = ''
param haEnabled string = 'Disabled'
param standbyAvailabilityZone string = ''
param vmName string = 'Standard_B1ms'
param vCores int = 1
param storageAutogrow string = 'Enabled'
param autoIoScaling string = 'Disabled'
param acceleratedLogs string = 'Disabled'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: vmName
    tier: serverEdition
    capacity: vCores
  }
  properties: {
    createMode: 'Default'
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
      iops: storageIops
      autogrow: storageAutogrow
      autoIoScaling: autoIoScaling
      logOnDisk: acceleratedLogs
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    availabilityZone: availabilityZone
    highAvailability: {
      mode: haEnabled
      standbyAvailabilityZone: standbyAvailabilityZone
    }
  }
}

resource database 'Microsoft.DBforMySQL/flexibleServers/databases@2021-05-01' = {
  parent: mysqlServer
  name: databaseName
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

resource mysqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: administratorLoginPassword
  }
}

resource firewallRule 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-05-01' = {
  parent: mysqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

output id string = mysqlServer.id
output name string = mysqlServer.name
output databaseName string = database.name
output serverFullyQualifiedDomainName string = mysqlServer.properties.fullyQualifiedDomainName
