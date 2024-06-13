param applicationInsightsName string
param appInsightsLocation string

param appInsightsReuse bool
param existingAppInsightsResourceGroupName string

resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing  = if (appInsightsReuse) {
  scope: resourceGroup(existingAppInsightsResourceGroupName)
  name: applicationInsightsName
}

resource newApplicationInsights 'Microsoft.Insights/components@2020-02-02' = if (!appInsightsReuse) {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

output id string = appInsightsReuse ? existingApplicationInsights.id : newApplicationInsights.id
output instrumentationKey string = appInsightsReuse ? existingApplicationInsights.properties.InstrumentationKey : newApplicationInsights.properties.InstrumentationKey
output connectionString string = appInsightsReuse ? existingApplicationInsights.properties.ConnectionString : newApplicationInsights.properties.ConnectionString
