import { vnetConfigInfo } from './vnet-config.bicep'

@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}
@description('MSI Id.')
param identityId string?

@description('Whether to enable public network access. Defaults to Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@export()
@description('Information about a workload profile for the environment.')
type workloadProfileInfo = {
  @description('Friendly name of the workload profile.')
  name: string
  @description('Type of the workload profile.')
  workloadProfileType:
    | 'D4'
    | 'D8'
    | 'D16'
    | 'D32'
    | 'E4'
    | 'E8'
    | 'E16'
    | 'E32'
    | 'NC24-A100'
    | 'NC48-A100'
    | 'NC96-A100'
  @description('Minimum number of nodes for the workload profile.')
  minimumCount: int
  @description('Maximum number of nodes for the workload profile.')
  maximumCount: int
}

@export()
@description('Information about the configuration for a custom domain in the environment.')
type customDomainConfigInfo = {
  @description('Name of the custom domain.')
  dnsSuffix: string
  @description('Value of the custom domain certificate.')
  certificateValue: string
  @description('Password for the custom domain certificate.')
  certificatePassword: string
}

@description('Additional workload profiles. Includes Consumption by default.')
param workloadProfiles workloadProfileInfo[] = []
@description('Name of the Log Analytics Workspace to store application logs.')
param logAnalyticsWorkspaceName string
@description('Name of the Application Insights resource.')
param applicationInsightsName string
@description('Custom domain configuration for the environment.')
param customDomainConfig customDomainConfigInfo = {
  dnsSuffix: ''
  certificateValue: ''
  certificatePassword: ''
}
@description('Virtual network configuration for the environment.')
param vnetConfig vnetConfigInfo = {
  infrastructureSubnetId: ''
  internal: true
}
@description('Value indicating whether the environment is zone-redundant. Defaults to false.')
param zoneRedundant bool = false

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: identityId == null ? 'SystemAssigned' : 'UserAssigned'
    userAssignedIdentities: identityId == null
      ? null
      : {
          '${identityId}': {}
        }
  }
  properties: {
    publicNetworkAccess: !empty(vnetConfig.infrastructureSubnetId) ? 'Disabled' : 'Enabled'
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: concat(
      [
        {
          name: 'Consumption'
          workloadProfileType: 'Consumption'
        }
      ],
      workloadProfiles
    )
    customDomainConfiguration: !empty(customDomainConfig.dnsSuffix) ? customDomainConfig : {}
    vnetConfiguration: !empty(vnetConfig.infrastructureSubnetId) ? vnetConfig : {}
    zoneRedundant: zoneRedundant
    daprAIConnectionString: applicationInsights.properties.ConnectionString
    daprAIInstrumentationKey: applicationInsights.properties.InstrumentationKey
  }
}

@description('ID for the deployed Container Apps Environment resource.')
output id string = containerAppsEnvironment.id
@description('Name for the deployed Container Apps Environment resource.')
output name string = containerAppsEnvironment.name
@description('Default domain for the deployed Container Apps Environment resource.')
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
@description('Static IP for the deployed Container Apps Environment resource.')
output staticIp string = containerAppsEnvironment.properties.staticIp

@description('Static IP for the deployed Container Apps Environment resource.')
output properties object = containerAppsEnvironment.properties
