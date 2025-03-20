param name string
param location string = resourceGroup().location
param tags object = {}
@secure()
@description('The names of the secrets to be created in the key vault')

param storageAccountName string
var aiServiceName = '${name}-r1-aiservice'
var hubName = '${name}-r1-hub'
var projectName = '${name}-r1-project'

resource deepseekR1AIService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
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
/*
// R1 Hub
resource deepseekR1Hub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: hubName
  location: location
  tags: tags
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

// R1 Project
resource deepseekR1Project 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
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
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://westus.api.azureml.ms/discovery'
    hubResourceId: deepseekR1Hub.id
    enableDataIsolation: true
  }
}

// Hub Connections
resource hubAIServiceConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: deepseekR1Hub
  name: aiServiceName
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: 'https://${aiServiceName}.cognitiveservices.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: deepseekR1AIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

resource hubAoaiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: deepseekR1Hub
  name: '${aiServiceName}_aoai'
  properties: {
    authType: 'ApiKey'
    category: 'AzureOpenAI'
    target: 'https://${aiServiceName}.openai.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: deepseekR1AIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

// Project Connections
resource projectAIServiceConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: deepseekR1Project
  name: aiServiceName
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: 'https://${aiServiceName}.cognitiveservices.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: deepseekR1AIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}

resource projectAoaiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: deepseekR1Project
  name: '${aiServiceName}_aoai'
  properties: {
    authType: 'ApiKey'
    category: 'AzureOpenAI'
    target: 'https://${aiServiceName}.openai.azure.com/'
    isSharedToAll: true
    sharedUserList: []
    metadata: {
      ApiType: 'Azure'
      ResourceId: deepseekR1AIService.id
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
}
*/
output r1Endpoint string = deepseekR1AIService.properties.endpoint
output r1Key string = deepseekR1AIService.listKeys().key1
