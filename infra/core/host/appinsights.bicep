param applicationInsightsName string
param appInsightsLocation string

param appInsightsReuse bool
param existingAppInsightsResourceGroupName string

// New parameter: if this is provided (non‐empty) then the App Insights resource will be linked
// to that Log Analytics workspace. Otherwise (when empty) we will deploy a default workspace.
param logAnalyticsWorkspaceResourceId string = ''

// When we are creating a new Application Insights resource (i.e. not reusing an existing one)
// and no workspace id was provided, deploy a new Log Analytics workspace.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (!appInsightsReuse && empty(logAnalyticsWorkspaceResourceId)) {
  name: '${applicationInsightsName}-law'
  location: appInsightsLocation
  properties: {
    sku: {
      name: 'free'
    }
  }
}

// If reusing an existing App Insights resource, reference it (assumed to already be workspace‐based)
resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (appInsightsReuse) {
  scope: resourceGroup(existingAppInsightsResourceGroupName)
  name: applicationInsightsName
}

// Create a new Application Insights resource in workspace‐based mode.
// Its properties include the WorkspaceResourceId. This value comes either from the parameter
// (if one was provided) or from the newly deployed Log Analytics workspace.
resource newApplicationInsights 'Microsoft.Insights/components@2020-02-02' = if (!appInsightsReuse) {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: empty(logAnalyticsWorkspaceResourceId) ? logAnalyticsWorkspace.id : logAnalyticsWorkspaceResourceId
  }
}

output id string = appInsightsReuse ? existingApplicationInsights.id : newApplicationInsights.id
output name string = appInsightsReuse ? existingApplicationInsights.name : newApplicationInsights.name
output instrumentationKey string = appInsightsReuse ? existingApplicationInsights.properties.InstrumentationKey : newApplicationInsights.properties.InstrumentationKey
output connectionString string = appInsightsReuse ? existingApplicationInsights.properties.ConnectionString : newApplicationInsights.properties.ConnectionString
