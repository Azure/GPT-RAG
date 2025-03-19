param name string
param location string = 'westus'
param tags object = {}

// Key vault parameters
param keyVaultName string
param storageAccountName string

var aiServiceName = '${name}-aiservice'
var hubName = '${name}-hub'
var projectName = '${name}-project'

resource visionIngestionAIService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServiceName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiServiceName
    publicNetworkAccess: 'Enabled'
  }
}

// Vision Ingestion Hub
resource visionIngestionHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: hubName
  location: location
  tags: {
    '__SYSTEM__AzureOpenAI_${aiServiceName}_aoai': visionIngestionAIService.id
    '__SYSTEM__AIServices_${aiServiceName}': visionIngestionAIService.id
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: hubName
    storageAccount: storageAccountName
    keyVault: keyVaultName
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://westus.api.azureml.ms/discovery'
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id
    }
    enableDataIsolation: true
  }
}

// Vision Ingestion Project
resource visionIngestionProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: projectName
  location: location
  tags: {
    labelingEnabled: 'true'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: projectName
    storageAccount: storageAccountName
    keyVault: keyVaultName
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://westus.api.azureml.ms/discovery'
    hubResourceId: visionIngestionHub.id
    enableDataIsolation: true
  }
}

// Hub Connections
resource hubAIServiceConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: visionIngestionHub
  name: aiServiceName
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: 'https://${aiServiceName}.cognitiveservices.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: visionIngestionAIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

resource hubAoaiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: visionIngestionHub
  name: '${aiServiceName}_aoai'
  properties: {
    authType: 'ApiKey'
    category: 'AzureOpenAI'
    target: 'https://${aiServiceName}.openai.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: visionIngestionAIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

// Project Connections
resource projectAIServiceConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: visionIngestionProject
  name: aiServiceName
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: 'https://${aiServiceName}.cognitiveservices.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: visionIngestionAIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

resource projectAoaiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: visionIngestionProject
  name: '${aiServiceName}_aoai'
  properties: {
    authType: 'ApiKey'
    category: 'AzureOpenAI'
    target: 'https://${aiServiceName}.openai.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: visionIngestionAIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

// Outputs
output hubWorkspaceId string = visionIngestionHub.id
output projectWorkspaceId string = visionIngestionProject.id
output aiServiceId string = visionIngestionAIService.id
output aiServiceEndpoint string = visionIngestionAIService.properties.endpoint
// NOT SURE HOW TO RETURN THIS ERROR: Outputs should not contain secrets. Found possible secret: function 'listKeys'
output aiServiceKey string = listKeys(visionIngestionAIService.id, visionIngestionAIService.apiVersion).key1

