@description('Name of the AI Services account to create')
param accountName string

@description('Azure location where the AI Services account and deployments will be created')
param location string

// Optional parameters for Azure Key Vault integration (CMK encryption)

@description('Name of the Azure Key Vault target')
param keyVaultName string = ''

@description('Name of the Azure Key Vault key')
param keyName string = ''

@description('Version of the Azure Key Vault key')
param keyVersion string = ''

resource existingAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (keyVaultName != '') {
  name: keyVaultName
}

// AI Foundry Account Resource

resource accountUpdate 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: existingAccount.name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    encryption: {
      keySource: 'Microsoft.KeyVault'
      keyVaultProperties: {
        keyVaultUri: keyVault.properties.vaultUri
        keyName: keyName
        keyVersion: keyVersion
      }
    }
  }
}
