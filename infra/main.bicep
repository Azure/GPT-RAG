targetScope = 'subscription'

// TEMPLATE PARAMETERS (change as needed to customize your deployment)

@description('Name of the resource group where all resources will be created')
param resourceGroupName string

@description('Random id to generate sufix for resources names. Do not change it.')
// param servicesNameSufix string = substring(uniqueString(subscription().id), 0, 5)
param guidValue string = newGuid()
output guidOutput string = guidValue

@minLength(1)
@maxLength(64)
@description('Environment name used as a tag for all resources.')
param environmentName string = 'dev'

//language settings
@description('Language used when orchestrator needs send error messages to the UX.')
@allowed(['pt', 'es', 'en'])
param orchestratorMessagesLanguage string = 'en'
@description('Analyzer language used by Azure search to analyze indexes text content.')
@allowed(['pt-Br.microsoft', 'es.microsoft', 'ar.microsoft', 'bn.microsoft', 'bg.microsoft', 'ca.microsoft', 'zh-Hans.microsoft', 'zh-Hant.microsoft', 'hr.microsoft', 'cs.microsoft', 'da.microsoft', 'nl.microsoft', 'en.microsoft', 'et.microsoft', 'fi.microsoft', 'fr.microsoft', 'de.microsoft', 'el.microsoft', 'gu.microsoft', 'he.microsoft', 'hi.microsoft', 'hu.microsoft', 'is.microsoft', 'id.microsoft', 'it.microsoft', 'ja.microsoft', 'kn.microsoft', 'ko.microsoft', 'lv.microsoft', 'lt.microsoft', 'ml.microsoft', 'ms.microsoft', 'mr.microsoft', 'nb.microsoft', 'pl.microsoft', 'pt-Pt.microsoft', 'pa.microsoft', 'ro.microsoft', 'ru.microsoft', 'sr-cyrillic.microsoft', 'sr-latin.microsoft', 'sk.microsoft', 'sl.microsoft', 'sv.microsoft', 'ta.microsoft', 'te.microsoft', 'th.microsoft', 'tr.microsoft', 'uk.microsoft', 'ur.microsoft', 'vi.microsoft' ])
param searchAnalyzerName string = 'en.microsoft'
@description('Search language, only valid when semantic reranking is used.')
@allowed(['pt', 'es', 'en'])
param searchServiceLanguage string = 'en'
@description('Language used for speech recognition in the frontend.')
@allowed(['pt-BR', 'af-ZA', 'am-ET', 'ar-AE', 'ar-BH', 'ar-DZ', 'ar-EG', 'ar-IL', 'ar-IQ', 'ar-JO', 'ar-KW', 'ar-LB', 'ar-LY', 'ar-MA', 'ar-OM', 'ar-PS', 'ar-QA', 'ar-SA', 'ar-SY', 'ar-TN', 'ar-YE', 'az-AZ', 'bg-BG', 'bn-IN', 'bs-BA', 'ca-ES', 'cs-CZ', 'cy-GB', 'da-DK', 'de-AT', 'de-CH', 'de-DE', 'el-GR', 'en-AU', 'en-CA', 'en-GB', 'en-GH', 'en-HK', 'en-IE', 'en-IN', 'en-KE', 'en-NG', 'en-NZ', 'en-PH', 'en-SG', 'en-TZ', 'en-US', 'en-ZA', 'es-AR', 'es-BO', 'es-CL', 'es-CO', 'es-CR', 'es-CU', 'es-DO', 'es-EC', 'es-ES', 'es-GQ', 'es-GT', 'es-HN', 'es-MX', 'es-NI', 'es-PA', 'es-PE', 'es-PR', 'es-PY', 'es-SV', 'es-US', 'es-UY', 'es-VE', 'et-EE', 'eu-ES', 'fa-IR', 'fi-FI', 'fil-PH', 'fr-BE', 'fr-CA', 'fr-CH', 'fr-FR', 'ga-IE', 'gl-ES', 'gu-IN', 'he-IL', 'hi-IN', 'hr-HR', 'hu-HU', 'hy-AM', 'id-ID', 'is-IS', 'it-CH', 'it-IT', 'ja-JP', 'jv-ID', 'ka-GE', 'kk-KZ', 'km-KH', 'kn-IN', 'ko-KR', 'lo-LA', 'lt-LT', 'lv-LV', 'mk-MK', 'ml-IN', 'mn-MN', 'mr-IN', 'ms-MY', 'mt-MT', 'my-MM', 'nb-NO', 'ne-NP', 'nl-BE', 'nl-NL', 'pl-PL', 'ps-AF', 'pt-PT', 'ro-RO', 'ru-RU', 'si-LK', 'sk-SK', 'sl-SI', 'so-SO', 'sq-AL', 'sr-RS', 'sv-SE', 'sw-KE', 'sw-TZ', 'ta-IN', 'te-IN', 'th-TH', 'tr-TR', 'uk-UA', 'uz-UZ', 'vi-VN', 'wuu-CN', 'yue-CN', 'zh-CN', 'zh-CN-shandong', 'zh-CN-sichuan', 'zh-HK', 'zh-TW', 'zu-ZA' ])
param speechRecognitionLanguage string = 'en-US'
@description('Language used for speech synthesis in the frontend.')
@allowed(['pt-BR', 'es-ES', 'es-MX','ar-EG', 'ar-SA', 'ca-ES', 'cs-CZ', 'da-DK', 'de-AT', 'de-CH', 'de-DE', 'en-AU', 'en-CA', 'en-GB', 'en-HK', 'en-IE', 'en-IN', 'en-US', 'es-ES', 'es-MX', 'fi-FI', 'fr-BE', 'fr-CA', 'fr-CH', 'fr-FR', 'hi-IN', 'hu-HU', 'id-ID', 'it-IT', 'ja-JP', 'ko-KR', 'nb-NO', 'nl-BE', 'nl-NL', 'pl-PL', 'pt-PT', 'ru-RU', 'sv-SE', 'th-TH', 'tr-TR', 'zh-CN', 'zh-HK', 'zh-TW'])
param speechSynthesisLanguage string = 'en-US'
@description('Voice used for speech synthesis in the frontend.')
@allowed([ 'pt-BR-FranciscaNeural', 'es-MX-BeatrizNeural', 'en-US-RyanMultilingualNeural', 'de-DE-AmalaNeural', 'fr-FR-DeniseNeural'])
param speechSynthesisVoiceName string = 'en-US-RyanMultilingualNeural'

// openai
@description('GPT model used to answer user questions. Don\'t forget to check region availability.')
@allowed([ 'gpt-35-turbo-16k', 'gpt-4', 'gpt-4-32k' ])
param chatGptModelName string = 'gpt-35-turbo-16k'
@description('GPT model version.')
@allowed([ '0613' ])
param chatGptModelVersion string = '0613'
@description('GPT model deployment name.')
param chatGptDeploymentName string = 'chat'
@description('GPT model tokens per Minute Rate Limit (thousands). Default quota per model and region: gpt-4: 20; gpt-4-32: 60; All others: 240.')
@minValue(1)
@maxValue(20)
param chatGptDeploymentCapacity int = 2
@description('Embeddings model used to generate vector embeddings. Don\'t forget to check region availability.')
@allowed([ 'text-embedding-ada-002' ])
param embeddingsModelName string = 'text-embedding-ada-002'
@description('Embeddings model version.')
@allowed([ '2' ])
param embeddingsModelVersion string = '2'
@description('Embeddings model deployment name.')
param embeddingsDeploymentName string = 'text-embedding-ada-002'
@description('Embeddings model tokens per Minute Rate Limit (thousands). Default quota per model and region: 240')
@minValue(1)
@maxValue(240)
param embeddingsDeploymentCapacity int = 10
@description('Azure OpenAI API version.')
@allowed([ '2023-05-15', '2023-06-01-preview'])
param openaiApiVersion string = '2023-05-15'

// search
@description('Orchestrator supports the following retrieval approaches: hybrid(term + vector search), semantic(hybrid + semantic reranking) or use oyd feature of Azure OpenAI.')
@allowed([ 'hybrid', 'semantic', 'oyd' ])
param retrievalApproach string = 'semantic'
var searchServiceSkuName = 'standard'
@description('Search index name.')
var searchIndex = 'ragindex'
@allowed([ '2023-07-01-Preview' ])
param searchApiVersion string = '2023-07-01-Preview'
@description('Frequency of search reindexing. PT5M (5 min), PT1H (1 hour), P1D (1 day).')
@allowed(['PT5M', 'PT1H', 'P1D'])
param searchIndexInterval string = 'PT1H'

// chunking
@description('The number of tokens in each chunk.')
param chunkNumTokens string = '2048'
@description('The minimum chunk size below which chunks will be filtered.')
param chunkMinSize string = '100'
@description('The number of tokens to overlap between chunks.')
param chunkTokenOverlap string = '100'

// storage
@description('Name of the container where source documents will be stored.')
param storageContainerName string = 'documents'

@minLength(1)
@description('Primary location for all resources. No need to change since deployment() function will get the resource group location.')
// param location string = 'eastus'
param location string = deployment().location
@description('(optional) Id of the user or app to assign keyvault access. Keep it none if you don\'t want add any principal.')
param principalId string = 'none'

// Nombres de los servicios
@description('Cosmos DB Account Name. Use your own name convention or leave as it is to generate a random name.')
param dbAccountName string = 'dbgpt0${substring(uniqueString(guidValue), 0, 5)}'
@description('Cosmos DB Database Name. Use your own name convention or leave as it is to generate a random name.')
param dbDatabaseName string = 'db0${substring(uniqueString(guidValue), 0, 5)}'
@description('Key Vault Name. Use your own name convention or leave as it is to generate a random name.')
param keyVaultName string = 'kv0${substring(uniqueString(guidValue), 0, 5)}'
@description('Storage Account Name. Use your own name convention or leave as it is to generate a random name.')
param storageAccountName string = 'strag0${substring(uniqueString(guidValue), 0, 5)}'
@description('Speech Account Name. Use your own name convention or leave as it is to generate a random name.')
param speechServiceName string = 'speech0${substring(uniqueString(guidValue), 0, 5)}'
@description('Document Intelligence Account Name. Use your own name convention or leave as it is to generate a random name.')
param formRecognizerServiceName string = 'fr0${substring(uniqueString(guidValue), 0, 5)}'
@description('App Service Plan Name. Use your own name convention or leave as it is to generate a random name.')
param azureAppServicePlanName string = 'appplan0${substring(uniqueString(guidValue), 0, 5)}'
@description('App Insights Name. Use your own name convention or leave as it is to generate a random name.')
param appInsightsName string = 'appins0${substring(uniqueString(guidValue), 0, 5)}'
@description('Front-end App Service Name. Use your own name convention or leave as it is to generate a random name.')
param azureAppServiceName string = 'webgpt0${substring(uniqueString(guidValue), 0, 5)}'
@description('Orchestrator Function Name. Use your own name convention or leave as it is to generate a random name.')
param orchestratorFunctionAppName string = 'fnorch0${substring(uniqueString(guidValue), 0, 5)}'
@description('Data Ingestion Function Name. Use your own name convention or leave as it is to generate a random name.')
param dataIngestionFunctionAppName string = 'fninges0${substring(uniqueString(guidValue), 0, 5)}'
@description('Search Service Name. Use your own name convention or leave as it is to generate a random name.')
param searchServiceName string = 'search0${substring(uniqueString(guidValue), 0, 5)}'
@description('OpenAI Service Name. Use your own name convention or leave as it is to generate a random name.')
param openAiServiceName string = 'oai0${substring(uniqueString(guidValue), 0, 5)}'

var orchestratorEndpoint = 'https://${orchestratorFunctionAppName}.azurewebsites.net/api/orc'
var tags = { 'azd-env-name': environmentName }
var principalIdvar = (principalId != 'none') ? principalId : ''

// MAIN

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// storage

var containerName = storageContainerName
var chunksContainerName = '${containerName}-chunks'

module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: storageAccountName
    location: location
    tags: tags
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    containers: [{name:containerName, publicAccess: 'Blob'}, {name:chunksContainerName}]
  }  
}

// Database
module cosmosAccount './core/db/cosmos.bicep' = {
  name: 'account'
  scope: resourceGroup
  params: {
    accountName: dbAccountName
    location: location
    containerName: 'conversations'
    databaseName: dbDatabaseName
    tags: tags    
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: keyVaultName
    location: location
    tags: tags
    principalId: principalIdvar
  }
}

// Create an App Service Plan
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: azureAppServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'B1'
      capacity: 1
    }
    kind: 'linux'
  }
}

// app insights
module appInsights './core/host/appinsights.bicep' = {
  name: 'appinsights'
  scope: resourceGroup
  params: {
    applicationInsightsName: appInsightsName
    appInsightsLocation: location
  }
}

// orchestrator
module orchestrator './core/host/functions.bicep' = {
  name: 'orchestrator'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    appName: orchestratorFunctionAppName
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    tags: tags
    alwaysOn: true
    functionAppScaleLimit: 2
    numberOfWorkers: 2
    minimumElasticInstanceCount: 1
    allowedOrigins: [ '*' ]    
    appSettings:[
      {
        name: 'AZURE_DB_ID'
        value: dbAccountName
      }
      {
        name: 'AZURE_KEY_VAULT_NAME'
        value: keyVault.outputs.name
      }      
      {
        name: 'AZURE_SEARCH_SERVICE'
        value: searchServiceName
      }
      {
        name: 'AZURE_SEARCH_INDEX'
        value: searchIndex
      }
      {
        name: 'AZURE_SEARCH_APPROACH'
        value: retrievalApproach
      }
      {
        name: 'AZURE_SEARCH_SEMANTIC_SEARCH_LANGUAGE'
        value: searchServiceLanguage
      }      
      {
        name: 'AZURE_SEARCH_API_VERSION'
        value: searchApiVersion
      }
      {
        name: 'AZURE_OPENAI_RESOURCE'
        value: openAiServiceName
      }
      {
        name: 'AZURE_OPENAI_CHATGPT_MODEL'
        value: chatGptModelName
      }      
      {
        name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
        value: chatGptDeploymentName
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_MODEL'
        value: embeddingsModelName
      }      
      {
        name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
        value: embeddingsDeploymentName
      }
      {
        name: 'AZURE_OPENAI_STREAM'
        value: false
      }
      {
        name: 'ORCHESTRATOR_MESSAGES_LANGUAGE'
        value: orchestratorMessagesLanguage
      }      
    ]  
  }
}

// module delay './core/delay.bicep' = {
//   name: 'delay'
//   scope: resourceGroup
//   params: {
//     location: orchestrator.outputs.location
//     sleepSeconds: 360
//   }
// }


// Give the orchestrator access to KeyVault
module orchestratorKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'orchestrator-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: orchestrator.outputs.identityPrincipalId
  }
} 

module appService  'core/host/appservice.bicep'  = {
  name: 'frontend'
  scope: resourceGroup
  params: {
    name: azureAppServiceName
    applicationInsightsName: appInsightsName
    appCommandLine: 'python ./app.py'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    appSettings: {
      AZURE_KEY_VAULT_NAME: keyVault.outputs.name
      ORCHESTRATOR_ENDPOINT: orchestratorEndpoint
      SPEECH_REGION: location
      SPEECH_RECOGNITION_LANGUAGE: speechRecognitionLanguage
      SPEECH_SYNTHESIS_LANGUAGE: speechSynthesisLanguage
      SPEECH_SYNTHESIS_VOICE_NAME: speechSynthesisVoiceName
    }     
  }
}

// Give the App Service access to KeyVault
module appsericeKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'appservice-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: appService.outputs.identityPrincipalId
  }
}

module dataIngestion './core/host/functions.bicep' = {
  name: 'dataIngestion'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    appName: dataIngestionFunctionAppName
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    tags: tags
    alwaysOn: true
    allowedOrigins: [ '*' ]
    functionAppScaleLimit: 1
    minimumElasticInstanceCount: 1
    numberOfWorkers: 1  
    appSettings:[
      {
        name: 'AZURE_KEY_VAULT_NAME'
        value: keyVault.outputs.name
      }
      {      
        name: 'FUNCTION_APP_NAME'
        value: dataIngestionFunctionAppName
      }
      {
        name: 'SEARCH_SERVICE'
        value: searchServiceName
      }
      {
        name: 'SEARCH_INDEX_NAME'
        value: searchIndex
      } 
      {
        name: 'SEARCH_ANALYZER_NAME'
        value: searchAnalyzerName
      }
      {
        name: 'SEARCH_API_VERSION'
        value: searchApiVersion
      }
      {
        name: 'SEARCH_INDEX_INTERVAL'
        value: searchIndexInterval
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: storageAccountName
      }
      {
        name: 'STORAGE_CONTAINER'
        value: containerName
      }
      {
        name: 'STORAGE_CONTAINER_CHUNKS'
        value: chunksContainerName
      }
      {
        name: 'AZURE_FORMREC_SERVICE'
        value: formRecognizerServiceName
      }
      {
        name: 'AZURE_OPENAI_API_VERSION'
        value: openaiApiVersion
      }
      {
        name: 'AZURE_SEARCH_APPROACH'
        value: retrievalApproach
      }
      {
        name: 'AZURE_OPENAI_SERVICE_NAME'
        value: openAiServiceName
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
        value: embeddingsDeploymentName
      }
      {
        name: 'NUM_TOKENS'
        value: chunkNumTokens
      }
      {
        name: 'MIN_CHUNK_SIZE'
        value: chunkMinSize
      }
      {
        name: 'TOKEN_OVERLAP'
        value: chunkTokenOverlap
      }      
    ]  
  }
}

// Give the data ingestion access to KeyVault
module dataIngestionKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'data-ingestion-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: dataIngestion.outputs.identityPrincipalId
  }
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: 'FormRecognizer'
  scope: resourceGroup
  params: {
    name: formRecognizerServiceName
    location: location
    kind: 'FormRecognizer'
    tags: tags
    sku: {
      name: 'S0'
    }
  }
}

module speechServices 'core/ai/cognitiveservices.bicep' = {
  name: 'SpeechServices'
  scope: resourceGroup
  params: {
    name: speechServiceName
    location: location
    kind: 'SpeechServices'
    tags: tags
    sku: {
      name: 'S0'
    }
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
      name: 'S0' 
    }    
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        capacity: chatGptDeploymentCapacity
      },{
        name: embeddingsDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingsModelName
          version: embeddingsModelVersion
        }
        capacity: embeddingsDeploymentCapacity
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



module keyVaultSecret './core/security/keyvault-secrets.bicep' = {
  name: 'keyvaultsecrets'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    secretValues: {
      // orchestratorFunctionKey: {
      //   name: 'orchestratorKey'
      //   value: orchestrator.outputs.hostKey
      // }
      // ingestionFunctionKey: {
      //   name: 'ingestionKey'
      //   value: ingestion.outputs.hostKey
      // }      
      azureSearchKey: {
        name: 'azureSearchKey'
        value: searchService.outputs.apiKey
      }
      formRecKey: {
        name: 'formRecKey'
        value: formRecognizer.outputs.apiKey
      }
      speechKey: {
        name: 'speechKey'
        value: speechServices.outputs.apiKey
      }            
      azureOpenAIKey: {
        name: 'azureOpenAIKey'
        value: openAi.outputs.apiKey
      }
      azureDBkey: {
        name: 'azureDBkey'
        value: cosmosAccount.outputs.azureDBkey
      }
      storageConnectionString: {
        name: 'storageConnectionString'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storage.outputs.name};AccountKey=${storage.outputs.storageKey};EndpointSuffix=core.windows.net'
      }
    }
  }
}
