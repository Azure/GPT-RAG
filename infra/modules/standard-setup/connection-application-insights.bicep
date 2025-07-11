/*
Connections enable your AI applications to access tools and objects managed elsewhere in or outside of Azure.

This example demonstrates how to add an Azure Application Insights connection.

Only one application insights can be set on a project at a time.
*/
param aiFoundryName string = '<your-foundry-name>'
param connectedResourceName string = 'appi${aiFoundryName}'

// Refers your existing Azure AI Foundry resource
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: aiFoundryName
  scope: resourceGroup()
}

// Conditionally refers your existing Azure AI Search resource
resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing =  {
  name: connectedResourceName
}

// Creates the Azure Foundry connection to your Azure App Insights resource
resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: '${aiFoundryName}-appinsights'
  parent: aiFoundry
  properties: {
    category: 'AppInsights'
    target:  existingAppInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: existingAppInsights.properties.ConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: existingAppInsights.id
    }
  }
}
