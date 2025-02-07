param applicationInsightsName string
param appInsightsLocation string
param appInsightsReuse bool
param existingAppInsightsResourceGroupName string
param logAnalyticsWorkspaceResourceId string = ''

// Only deploy a new Log Analytics workspace when:
//   - We are creating a new Application Insights resource (i.e. not reusing an existing one)
//   - No workspace resource ID was provided

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if ( !appInsightsReuse && empty(logAnalyticsWorkspaceResourceId) ) {
  name: '${applicationInsightsName}-law'
  location: appInsightsLocation
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
  }
}

// If reusing an existing App Insights resource, reference it (assumed to already be workspace‐based)
resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (appInsightsReuse) {
  scope: resourceGroup(existingAppInsightsResourceGroupName)
  name: applicationInsightsName
}

// Create a new Application Insights resource in workspace‐based mode.
// we set WorkspaceResourceId to empty. Otherwise, the value comes either from the parameter
// (if one was provided) or from the newly deployed Log Analytics workspace.
resource newApplicationInsights 'Microsoft.Insights/components@2020-02-02' = if (!appInsightsReuse) {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: empty(logAnalyticsWorkspaceResourceId) ? logAnalyticsWorkspace.id : logAnalyticsWorkspaceResourceId
  }
}

output id string = appInsightsReuse ? existingApplicationInsights.id : newApplicationInsights.id
output name string = appInsightsReuse ? existingApplicationInsights.name : newApplicationInsights.name
output instrumentationKey string = appInsightsReuse ? existingApplicationInsights.properties.InstrumentationKey : newApplicationInsights.properties.InstrumentationKey
output connectionString string = appInsightsReuse ? existingApplicationInsights.properties.ConnectionString : newApplicationInsights.properties.ConnectionString
