/*
Connections enable your AI applications to access tools and objects managed elsewhere in or outside of Azure.

This example demonstrates how to add an Azure AI Search connection.
*/
param aiFoundryName string = '<your-account-name>'
param aiProjectName string = '<your-project-name>'
param connectedResourceName string = 'ais-${aiFoundryName}'
param aiSearchConnectionName string  = '${aiFoundryName}-connection'

// Refers your existing Azure AI Foundry resource
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: aiFoundryName
  scope: resourceGroup()
}

// Conditionally refers your existing Azure AI Search resource
resource existingSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing =  {
  name: connectedResourceName
}

// Creates the Azure Foundry connection to your Azure AI Search resource
resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: aiSearchConnectionName
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

output seachConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.CognitiveServices/accounts/${aiFoundryName}/projects/${aiProjectName}/connections/${aiSearchConnectionName}'
