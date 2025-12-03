// ============================================================================
// AI Foundry Wrapper Module
// This module wraps the Azure Verified Module (AVM) for AI Foundry and
// exposes the AI Project's managed identity principalId as an output.
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------
// Parameters (matching AVM module signature)
// ---------------------------------------------------------------------

@description('Required. Base name for all resources. Must be 10 characters or less.')
@maxLength(10)
param baseName string

@description('Optional. Include associated resources like Storage, Key Vault, Cosmos DB, and AI Search.')
param includeAssociatedResources bool = true

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Optional. Resource ID of the subnet for private endpoints.')
param privateEndpointSubnetResourceId string = ''

@description('Required. AI Foundry account configuration.')
param aiFoundryConfiguration object

@description('Optional. AI model deployments configuration.')
param aiModelDeployments array = []

@description('Optional. AI Search configuration.')
param aiSearchConfiguration object = {}

@description('Optional. Cosmos DB configuration.')
param cosmosDbConfiguration object = {}

@description('Optional. Key Vault configuration.')
param keyVaultConfiguration object = {}

@description('Optional. Storage Account configuration.')
param storageAccountConfiguration object = {}

@description('Optional. Enable telemetry via the Customer Usage Attribution ID.')
param enableTelemetry bool = true

// ---------------------------------------------------------------------
// Deploy AVM AI Foundry Module
// ---------------------------------------------------------------------

module aiFoundryAvm 'br/public:avm/ptn/ai-ml/ai-foundry:0.6.0' = {
  name: 'aiFoundryAvm-${baseName}'
  params: {
    baseName: baseName
    includeAssociatedResources: includeAssociatedResources
    location: location
    tags: tags
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    aiFoundryConfiguration: aiFoundryConfiguration
    aiModelDeployments: aiModelDeployments
    aiSearchConfiguration: aiSearchConfiguration
    cosmosDbConfiguration: cosmosDbConfiguration
    keyVaultConfiguration: keyVaultConfiguration
    storageAccountConfiguration: storageAccountConfiguration
    enableTelemetry: enableTelemetry
  }
}

// ---------------------------------------------------------------------
// Nested deployment to retrieve AI Project Principal ID
// This workaround is needed because Bicep cannot access identity.principalId
// directly from module outputs when using dynamic resource names
// ---------------------------------------------------------------------

module getProjectPrincipalId 'get-project-principalid.bicep' = {
  name: 'getProjectPrincipalId-${baseName}'
  params: {
    accountName: aiFoundryAvm.outputs.aiServicesName
    projectName: aiFoundryAvm.outputs.aiProjectName
  }
}

// ---------------------------------------------------------------------
// Outputs (original AVM outputs + resource IDs + principalId)
// ---------------------------------------------------------------------

@description('The name of the AI Services account.')
output aiServicesName string = aiFoundryAvm.outputs.aiServicesName

@description('The name of the AI Foundry project.')
output aiProjectName string = aiFoundryAvm.outputs.aiProjectName

@description('The name of the AI Search service.')
output aiSearchName string = aiFoundryAvm.outputs.aiSearchName

@description('The name of the Cosmos DB account.')
output cosmosAccountName string = aiFoundryAvm.outputs.cosmosAccountName

@description('The name of the Key Vault.')
output keyVaultName string = aiFoundryAvm.outputs.keyVaultName

@description('The name of the Storage Account.')
output storageAccountName string = aiFoundryAvm.outputs.storageAccountName

@description('The name of the resource group.')
output resourceGroupName string = aiFoundryAvm.outputs.resourceGroupName

@description('The principal ID of the AI Foundry project managed identity.')
output aiProjectPrincipalId string = getProjectPrincipalId.outputs.principalId
