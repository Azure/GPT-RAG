targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the azd environment. azd uses this name to find resources from azure.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param resourceGroupName string
param keyVaultName string

param azureFunctionsServicePlanName string
param orchestratorFunctionsName string
param dataIngestionFunctionsName string

param searchServiceName string
param searchServiceSkuName string = 'standard'

param openAiServiceName string
param openAiSkuName string = 'S0' 
param gptDeploymentName string = ''
param gptDeploymentCapacity int = 30
param gptModelName string = 'text-davinci-003'
param chatGptDeploymentName string = ''
param chatGptDeploymentCapacity int = 30
param chatGptModelName string = 'gpt-35-turbo'

@description('Id of the user or app to assign application roles')
param principalId string = ''

var tags = { 'azd-env-name': environmentName }
var gptDeployment = empty(gptDeploymentName) ? 'davinci' : gptDeploymentName
var chatGptDeployment = empty(chatGptDeploymentName) ? 'chat' : chatGptDeploymentName

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: keyVaultName
    location: location
    tags: tags
    principalId: principalId
  }
}

// Create an App Service Plan
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: azureFunctionsServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'B1'
      capacity: 1
    }
    kind: 'linux'
  }
}

// orchestrator
module orchestrator './app/orchestrator.bicep' = {
  name: 'orchestrator'
  scope: resourceGroup
  params: {
    name: orchestratorFunctionsName
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    allowedOrigins: [ '*' ]
    // storageAccountName: '<placeholder>'
  }
}

// Give the orchestrator access to KeyVault
module orchestratorKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'orchestrator-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: orchestrator.outputs.ORCHESTRATOR_IDENTITY_PRINCIPAL_ID
  }
}

// data ingestion
module dataIngestion './app/data-ingestion.bicep' = {
  name: 'dataIngestion'
  scope: resourceGroup
  params: {
    name: dataIngestionFunctionsName
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    allowedOrigins: [ '*' ]
    //storageAccountName: '<placeholder>'
  }
}

// Give the orchestrator access to KeyVault
module dataIngestionKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'data-ingestion-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: dataIngestion.outputs.DATA_INGESTION_IDENTITY_PRINCIPAL_ID
  }
}

module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: openAiServiceName
    location: location
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: gptDeployment
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: '1'
        }
        capacity: gptDeploymentCapacity
      }
      {
        name: chatGptDeployment
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: '0301'
        }
        capacity: chatGptDeploymentCapacity
      }
    ]
  }
}

module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: resourceGroup
  params: {
    name: searchServiceName
    location: location
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output AZURE_OPENAI_SERVICE string = openAi.outputs.name
output AZURE_OPENAI_GPT_DEPLOYMENT string = gptDeployment
output AZURE_OPENAI_CHATGPT_DEPLOYMENT string = chatGptDeployment

output AZURE_SEARCH_SERVICE string = searchService.outputs.name
