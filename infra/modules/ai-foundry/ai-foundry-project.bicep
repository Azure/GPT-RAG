@description('Location (region) where the resource will be created')
param location string

@description('Name of the AI Foundry account where the project will be created')
param accountName string

@description('Unique name of the project to create within the AI Foundry account')
param projectName string

@description('Friendly name to display in the portal')
param displayName string

@description('Description of the project')
param projectDescription string

@description('Name of the existing Azure Cognitive Search service to be used by the project')
param aiSearchName string

@description('Name of the resource group where the Azure Cognitive Search service is located')
param aiSearchServiceResourceGroupName string

@description('Subscription ID that contains the Azure Cognitive Search service')
param aiSearchServiceSubscriptionId string

@description('Name of the existing Azure Cosmos DB account to be linked to the project')
param cosmosDBName string

@description('Subscription ID that contains the Azure Cosmos DB account')
param cosmosDBSubscriptionId string

@description('Name of the resource group where the Azure Cosmos DB account is located')
param cosmosDBResourceGroupName string

@description('Name of the existing Azure Storage account to be used for project data')
param azureStorageName string

@description('Subscription ID that contains the Azure Storage account')
param azureStorageSubscriptionId string

@description('Name of the resource group where the Azure Storage account is located')
param azureStorageResourceGroupName string

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
}

resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosDBName
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: azureStorageName
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
}

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

#disable-next-line BCP053
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: projectDescription
    displayName: displayName
  }

  resource project_connection_cosmosdb_account 'connections@2025-04-01-preview' = {
    name: '${cosmosDBAccount.name}-connection'    
    properties: {
      category: 'CosmosDB'
      target: cosmosDBAccount.properties.documentEndpoint
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: cosmosDBAccount.id
        location: cosmosDBAccount.location
      }
    }
  }

  resource project_connection_azure_storage 'connections@2025-04-01-preview' = {
    name: '${storageAccount.name}-connection'
    properties: {
      category: 'AzureStorageAccount'
      target: storageAccount.properties.primaryEndpoints.blob
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: storageAccount.id
        location: storageAccount.location
      }
    }
  }

  resource project_connection_azureai_search 'connections@2025-04-01-preview' = {    
    name: '${searchService.name}-connection'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${searchService.name}.search.windows.net'
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: searchService.id
        location: searchService.location
      }
    }
  }

}

output projectName string = project.name
output projectId string = project.id
output projectPrincipalId string = project.identity.principalId
output resourceId string = project.id
output endpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${project.name}'

#disable-next-line BCP053
output projectWorkspaceId string = project.properties.internalId

// BYO connection names
output cosmosDBConnection string = '${cosmosDBAccount.name}-connection'
output azureStorageConnection string = '${storageAccount.name}-connection'
output aiSearchConnection string = '${searchService.name}-connection'
