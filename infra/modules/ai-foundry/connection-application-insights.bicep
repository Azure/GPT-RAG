// ==================================================================
// infra/modules/ai-foundry/connection-application-insights.bicep
// ==================================================================
metadata name = 'ai-foundry-connection-app-insights'
metadata description = 'Create an Application Insights connection in Azure AI Foundry account.'

@description('Required. The name of the Azure AI Foundry account.')
param aiFoundryName string

@description('Required. The name of the Application Insights resource to connect.')
param connectedResourceName string

@description('Optional. The name to assign to the App Insights connection.')
param appInsightsConnectionName string = '${aiFoundryName}-appinsights-connection'

// Reference existing AI Foundry account
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: aiFoundryName
  scope: resourceGroup()
}

// Reference existing Application Insights
resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: connectedResourceName
}

// Create the App Insights connection
resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: appInsightsConnectionName
  parent: aiFoundry
  properties: {
    category: 'AppInsights'
    target: existingAppInsights.id
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

@description('The name of the App Insights connection.')
output connectionName string = appInsightsConnectionName
