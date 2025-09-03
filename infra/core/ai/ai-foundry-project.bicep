@description('The name of the Azure AI service that will host the project')
param aiServiceName string

@description('The name of the Azure AI Foundry project to create')
param projectName string = 'agent-project'

@description('The location for the Azure AI Foundry project')
param location string

@description('Tags to apply to the Azure AI Foundry project')
param tags object = {}

// Create the Azure AI Foundry project as a child resource of the AI service
resource aiFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: '${aiServiceName}/${projectName}'
  location: location
  kind: 'AIServices'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: projectName
  }
}

@description('The resource ID of the Azure AI Foundry project')
output id string = aiFoundryProject.id

@description('The name of the Azure AI Foundry project')
output name string = aiFoundryProject.name

@description('The principal ID of the project managed identity')
output principalId string = aiFoundryProject.identity.principalId