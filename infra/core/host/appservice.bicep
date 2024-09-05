param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
param applicationInsightsName string = ''
param applicationInsightsResourceGroupName string = ''
param appServicePlanId string

// Runtime Properties
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'
param runtimeVersion string

// Microsoft.Web/sites Properties
param kind string = 'app,linux'

// Microsoft.Web/sites/config
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param appSettings array = []
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param linuxFxVersion string = runtimeNameAndVersion
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param scmDoBuildDuringDeployment bool = false
param use32BitWorkerProcess bool = false
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = ''
param basicPublishingCredentials bool = false
param networkIsolation bool
param vnetName string = ''
param subnetId string = ''

param appServiceReuse bool
param deployAppService bool = true

param existingAppServiceNameResourceGroupName string    

resource existingAppService 'Microsoft.Web/sites@2022-09-01' existing = if (appServiceReuse && deployAppService) {
  scope: resourceGroup(existingAppServiceNameResourceGroupName)
  name: name
}

resource newAppService 'Microsoft.Web/sites@2022-09-01' = if (!appServiceReuse && deployAppService) {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    virtualNetworkSubnetId: networkIsolation?subnetId:null
    vnetRouteAllEnabled: true
    siteConfig: {
      vnetName: networkIsolation?vnetName:null
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      ftpsState: ftpsState
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      appSettings: concat(appSettings,[
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: string(scmDoBuildDuringDeployment)
        }  
        {
          name: 'ENABLE_ORYX_BUILD'
          value: string(enableOryxBuild)
        }  
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }    
      ])      
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
    }
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
  }

  resource basicPublishingCredentialsPoliciesFtp 'basicPublishingCredentialsPolicies' = {
    name: 'ftp'
    properties: {
      allow: basicPublishingCredentials
    }
  }

  resource basicPublishingCredentialsPoliciesScm 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: basicPublishingCredentials
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  scope: resourceGroup(applicationInsightsResourceGroupName)
  name: applicationInsightsName
}

output identityPrincipalId string = !deployAppService ? '' : appServiceReuse ? existingAppService.identity.principalId : newAppService.identity.principalId
output name string = !deployAppService ? '' : appServiceReuse ? existingAppService.name : newAppService.name
output uri string = !deployAppService ? '' : 'https://${appServiceReuse ? existingAppService.properties.defaultHostName : newAppService.properties.defaultHostName }'
output id string = !deployAppService ? '' : appServiceReuse ? existingAppService.id : newAppService.id
// output key string = listKeys(appService.id, appService.apiVersion).default
