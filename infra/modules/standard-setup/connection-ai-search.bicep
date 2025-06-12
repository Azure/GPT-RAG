/*
Connections enable your AI applications to access tools and objects managed elsewhere in or outside of Azure.

This example demonstrates how to add an Azure AI Search connection.
*/
param aiFoundryName string = '<your-account-name>'
param connectedResourceName string = 'ais-${aiFoundryName}'
 
// Refers your existing Azure AI Foundry resource
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiFoundryName
  scope: resourceGroup()
}

// Conditionally refers your existing Azure AI Search resource
resource existingSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing =  {
  name: connectedResourceName
}

// Creates the Azure Foundry connection to your Azure AI Search resource
resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: '${aiFoundryName}-aisearch'
  parent: aiFoundry
  properties: {
    category: 'CognitiveSearch'
    target: existingSearchService.properties.endpoint
    authType: 'AAD' // Supported auth types: ApiKey, AAD
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: existingSearchService.id
      location:  existingSearchService.location
    }
  }
}
