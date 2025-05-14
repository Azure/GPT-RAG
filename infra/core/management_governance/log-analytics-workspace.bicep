@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

@export()
@description('SKU information for Log Analytics Workspace.')
type skuInfo = {
  @description('Name of the SKU.')
  name: 'CapacityReservation' | 'Free' | 'LACluster' | 'PerGB2018' | 'PerNode' | 'Premium' | 'Standalone' | 'Standard'
}

@export()
@description('Diagnostic settings configuration info for logs.')
type diagnosticSettingsLogConfigInfo = {
  @description('Name of the diagnostic log setting. Required if categoryGroup is not specified.')
  category: string?
  @description('Name of the category group of diagnostic logs. Required if category is not specified.')
  categoryGroup: string?
  @description('Flag indicating whether the diagnostic setting is enabled.')
  enabled: bool
  @description('Retention policy for the logs.')
  retentionPolicy: {
    @description('Flag indicating whether the retention policy is enabled.')
    enabled: bool
    @description('Number of days to retain the logs.')
    days: int
  }?
}

@export()
@description('Diagnostic settings configuration info for metrics.')
type diagnosticSettingsMetricConfigInfo = {
  @description('Name of the diagnostic metric setting.')
  category: string
  @description('Flag indicating whether the diagnostic setting is enabled.')
  enabled: bool
  @description('Retention policy for the metrics.')
  retentionPolicy: {
    @description('Flag indicating whether the retention policy is enabled.')
    enabled: bool
    @description('Number of days to retain the metrics.')
    days: int
  }?
}

@export()
@description('Diagnostic settings info for supported resources.')
type diagnosticSettingsInfo = {
  @description('Diagnostic settings for logs.')
  logs: diagnosticSettingsLogConfigInfo[]
  @description('Diagnostic settings for metrics.')
  metrics: diagnosticSettingsMetricConfigInfo[]
}

@description('Log Analytics Workspace SKU. Defaults to PerGB2018.')
param sku skuInfo = {
  name: 'PerGB2018'
}
@description('Retention period (in days) for the Log Analytics Workspace. Defaults to 30.')
param retentionInDays int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: sku
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('ID for the deployed Log Analytics Workspace resource.')
output id string = logAnalyticsWorkspace.id
@description('Name for the deployed Log Analytics Workspace resource.')
output name string = logAnalyticsWorkspace.name
@description('Customer ID for the deployed Log Analytics Workspace resource.')
output customerId string = logAnalyticsWorkspace.properties.customerId
