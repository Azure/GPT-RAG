param name string
param location string = resourceGroup().location
param tags object = {}

param allowedOrigins array = []
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param keyVaultName string
param serviceName string = 'orchestrator'
//param storageAccountName string

module orchestrator '../core/host/functions.bicep' = {
  name: '${serviceName}-functions-python-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    allowedOrigins: allowedOrigins
    alwaysOn: false
    appSettings: appSettings
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    keyVaultName: keyVaultName
    runtimeName: 'python'
    runtimeVersion: '3.8'
    //storageAccountName: storageAccountName
  }
}

output ORCHESTRATOR_IDENTITY_PRINCIPAL_ID string = orchestrator.outputs.identityPrincipalId
output ORCHESTRATOR_NAME string = orchestrator.outputs.name
output ORCHESTRATOR_URI string = orchestrator.outputs.uri
