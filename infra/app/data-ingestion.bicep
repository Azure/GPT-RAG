param name string
param location string = resourceGroup().location
param tags object = {}

param allowedOrigins array = []
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param keyVaultName string
param serviceName string = 'data-ingestion'
//param storageAccountName string

module dataIngestion '../core/host/functions.bicep' = {
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
    // storageAccountName: storageAccountName
  }
}

output DATA_INGESTION_IDENTITY_PRINCIPAL_ID string = dataIngestion.outputs.identityPrincipalId
output DATA_INGESTION_NAME string = dataIngestion.outputs.name
output DATA_INGESTION_URI string = dataIngestion.outputs.uri
