/*
Connections enable your AI applications to access tools and objects managed elsewhere in or outside of Azure.

This example demonstrates how to add an Azure Storage connection.
*/
param aiFoundryName string = '<your-account-name>'
param connectedResourceName string = 'st${aiFoundryName}'
 
// Refers your existing Azure AI Foundry resource
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: aiFoundryName
  scope: resourceGroup()
}

// Conditionally refers your existing Azure Storage account
resource existingStorage 'Microsoft.Storage/storageAccounts@2024-01-01' existing =  {
  name: connectedResourceName
}
 
// Creates the Azure Foundry connection to your Azure Storage account
resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: '${aiFoundryName}-storage'
  parent: aiFoundry
  properties: {
    category: 'AzureStorageAccount'
    target: existingStorage.id
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId:  existingStorage.id
    }
  }
}
