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

//network
@description('Network isolation? If yes it will create the private endpoints.')
@allowed([true, false])
param networkIsolation bool = false

@description('Create bastion and vm to test the solution when choosing network isolation?')
@allowed([true, false])
param createBastion bool = true

@minLength(6)
@maxLength(72)
@description('Test vm gpt user password. Use strong password with letters and numbers. Needed only when choosing network isolation and create bastion option. If not creating with network isolation you can write anything. Password must be between 6-72 characters long and must satisfy at least 3 of password complexity requirements from the following: 1-Contains an uppercase character, 2-Contains a lowercase character, 3-Contains a numeric digit, 4-Contains a special character, 5- Control characters are not allowed.')
@secure()
param vmUserPassword string

@description('Test vm gpt user name. Needed only when choosing network isolation and create bastion option. If not you can leave it blank.')
param vmUserName string = 'gptrag'

//language settings
@description('Language used when orchestrator needs send error messages to the UX.')
@allowed(['pt', 'es', 'en'])
param orchestratorMessagesLanguage string = 'es'
@description('Analyzer language used by Azure search to analyze indexes text content.')
@allowed(['pt-Br.microsoft', 'es.microsoft', 'ar.microsoft', 'bn.microsoft', 'bg.microsoft', 'ca.microsoft', 'zh-Hans.microsoft', 'zh-Hant.microsoft', 'hr.microsoft', 'cs.microsoft', 'da.microsoft', 'nl.microsoft', 'en.microsoft', 'et.microsoft', 'fi.microsoft', 'fr.microsoft', 'de.microsoft', 'el.microsoft', 'gu.microsoft', 'he.microsoft', 'hi.microsoft', 'hu.microsoft', 'is.microsoft', 'id.microsoft', 'it.microsoft', 'ja.microsoft', 'kn.microsoft', 'ko.microsoft', 'lv.microsoft', 'lt.microsoft', 'ml.microsoft', 'ms.microsoft', 'mr.microsoft', 'nb.microsoft', 'pl.microsoft', 'pt-Pt.microsoft', 'pa.microsoft', 'ro.microsoft', 'ru.microsoft', 'sr-cyrillic.microsoft', 'sr-latin.microsoft', 'sk.microsoft', 'sl.microsoft', 'sv.microsoft', 'ta.microsoft', 'te.microsoft', 'th.microsoft', 'tr.microsoft', 'uk.microsoft', 'ur.microsoft', 'vi.microsoft' ])
param searchAnalyzerName string = 'es.microsoft'
@description('Search language, only valid when semantic reranking is used.')
@allowed(['pt', 'es', 'en'])
param searchServiceLanguage string = 'es'
@description('Language used for speech recognition in the frontend.')
@allowed(['pt-BR', 'af-ZA', 'am-ET', 'ar-AE', 'ar-BH', 'ar-DZ', 'ar-EG', 'ar-IL', 'ar-IQ', 'ar-JO', 'ar-KW', 'ar-LB', 'ar-LY', 'ar-MA', 'ar-OM', 'ar-PS', 'ar-QA', 'ar-SA', 'ar-SY', 'ar-TN', 'ar-YE', 'az-AZ', 'bg-BG', 'bn-IN', 'bs-BA', 'ca-ES', 'cs-CZ', 'cy-GB', 'da-DK', 'de-AT', 'de-CH', 'de-DE', 'el-GR', 'en-AU', 'en-CA', 'en-GB', 'en-GH', 'en-HK', 'en-IE', 'en-IN', 'en-KE', 'en-NG', 'en-NZ', 'en-PH', 'en-SG', 'en-TZ', 'en-US', 'en-ZA', 'es-AR', 'es-BO', 'es-CL', 'es-CO', 'es-CR', 'es-CU', 'es-DO', 'es-EC', 'es-ES', 'es-GQ', 'es-GT', 'es-HN', 'es-MX', 'es-NI', 'es-PA', 'es-PE', 'es-PR', 'es-PY', 'es-SV', 'es-US', 'es-UY', 'es-VE', 'et-EE', 'eu-ES', 'fa-IR', 'fi-FI', 'fil-PH', 'fr-BE', 'fr-CA', 'fr-CH', 'fr-FR', 'ga-IE', 'gl-ES', 'gu-IN', 'he-IL', 'hi-IN', 'hr-HR', 'hu-HU', 'hy-AM', 'id-ID', 'is-IS', 'it-CH', 'it-IT', 'ja-JP', 'jv-ID', 'ka-GE', 'kk-KZ', 'km-KH', 'kn-IN', 'ko-KR', 'lo-LA', 'lt-LT', 'lv-LV', 'mk-MK', 'ml-IN', 'mn-MN', 'mr-IN', 'ms-MY', 'mt-MT', 'my-MM', 'nb-NO', 'ne-NP', 'nl-BE', 'nl-NL', 'pl-PL', 'ps-AF', 'pt-PT', 'ro-RO', 'ru-RU', 'si-LK', 'sk-SK', 'sl-SI', 'so-SO', 'sq-AL', 'sr-RS', 'sv-SE', 'sw-KE', 'sw-TZ', 'ta-IN', 'te-IN', 'th-TH', 'tr-TR', 'uk-UA', 'uz-UZ', 'vi-VN', 'wuu-CN', 'yue-CN', 'zh-CN', 'zh-CN-shandong', 'zh-CN-sichuan', 'zh-HK', 'zh-TW', 'zu-ZA' ])
param speechRecognitionLanguage string = 'es-ES'
@description('Language used for speech synthesis in the frontend.')
@allowed(['pt-BR', 'es-ES', 'es-MX','ar-EG', 'ar-SA', 'ca-ES', 'cs-CZ', 'da-DK', 'de-AT', 'de-CH', 'de-DE', 'en-AU', 'en-CA', 'en-GB', 'en-HK', 'en-IE', 'en-IN', 'en-US', 'es-ES', 'es-MX', 'fi-FI', 'fr-BE', 'fr-CA', 'fr-CH', 'fr-FR', 'hi-IN', 'hu-HU', 'id-ID', 'it-IT', 'ja-JP', 'ko-KR', 'nb-NO', 'nl-BE', 'nl-NL', 'pl-PL', 'pt-PT', 'ru-RU', 'sv-SE', 'th-TH', 'tr-TR', 'zh-CN', 'zh-HK', 'zh-TW'])
param speechSynthesisLanguage string = 'es-ES'
@description('Voice used for speech synthesis in the frontend.')
@allowed([ 'pt-BR-FranciscaNeural', 'es-MX-BeatrizNeural', 'en-US-RyanMultilingualNeural', 'de-DE-AmalaNeural', 'fr-FR-DeniseNeural'])
param speechSynthesisVoiceName string = 'es-MX-BeatrizNeural'

// openai
@description('GPT model used to answer user questions. Don\'t forget to check region availability.')
@allowed([ 'gpt-35-turbo-16k', 'gpt-4', 'gpt-4-32k' ])
param chatGptModelName string = 'gpt-35-turbo-16k'
@description('GPT model version.')
@allowed([ '0613' ])
param chatGptModelVersion string = '0613'
@description('GPT model deployment name.')
param chatGptDeploymentName string = 'chat'
var chatGptMonitoringDeploymentName = chatGptDeploymentName // can be changed manually after the provisioning to a different deployment name
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
@description('Enables LLM monitoring to generate conversation metrics.')
@allowed([true, false])
param chatGptLlmMonitoring bool = true

// search
@description('Orchestrator supports the following retrieval approaches: term, vector, hybrid(term + vector search), or use oyd feature of Azure OpenAI.')
@allowed(['term', 'vector', 'hybrid', 'oyd' ])
param retrievalApproach string = 'hybrid'
@description('Use semantic reranking on top of search results?.')
@allowed([true, false])
param useSemanticReranking bool = true

var searchServiceSkuName = networkIsolation?'standard2':'standard'
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
param chunkTokenOverlap string = '200'

// storage
@description('Name of the container where source documents will be stored.')
param storageContainerName string = 'documents'

@minLength(1)
@description('Primary location for all resources. No need to change since deployment() function will get the resource group location.')
// param location string = 'eastus'
param location string = deployment().location
@description('(optional) Id of the user or app to assign keyvault access. Keep it none if you don\'t want add any principal.')
param principalId string = 'none'

// Service names
@description('Cosmos DB Account Name. Use your own name convention or leave as it is to generate a random name.')
param dbAccountName string = 'dbgpt0${substring(uniqueString(guidValue), 0, 5)}'
@description('Cosmos DB Database Name. Use your own name convention or leave as it is to generate a random name.')
param dbDatabaseName string = 'db0${substring(uniqueString(guidValue), 0, 5)}'
@description('Key Vault Name. Use your own name convention or leave as it is to generate a random name.')
param keyVaultName string = 'kv0${substring(uniqueString(guidValue), 0, 5)}'
@description('Storage Account Name. Use your own name convention or leave as it is to generate a random name.')
param storageAccountName string = 'strag0${substring(uniqueString(guidValue), 0, 5)}'
@description('Cognitive services multi-service name. Use your own name convention or leave as it is to generate a random name.')
param cognitiveServiceName string = 'cs0${substring(uniqueString(guidValue), 0, 5)}'
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
@description('Virtual network name if using network isolation. Use your own name convention or leave as it is to generate a random name.')
param vnetName string = 'aivnet0${substring(uniqueString(guidValue), 0, 5)}'

var orchestratorEndpoint = 'https://${orchestratorFunctionAppName}.azurewebsites.net/api/orc'
var orchestratorUri = 'https://${orchestratorFunctionAppName}.azurewebsites.net'
var tags = { 'azd-env-name': environmentName }
var principalIdvar = (principalId != 'none') ? principalId : ''

// main

// resource group

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// networking

module vnet './core/network/vnet.bicep' = {
  name: vnetName
  scope: resourceGroup
  params: {
    name: vnetName
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    appServicePlanName: appServicePlan.outputs.name
  }
}

// DNSs Zones

module blobDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'blob-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.blob.core.windows.net' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

module documentsDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'documents-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.documents.azure.com' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

module vaultDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'vault-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.vaultcore.azure.net' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

module websitesDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'websites-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.azurewebsites.net' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''    
  }
}

module cognitiveservicesDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'cognitiveservices-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.cognitiveservices.azure.com' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

module openaiDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'openai-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.openai.azure.com' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

module searchDnsZone './core/network/private-dns-zones.bicep' = if (networkIsolation) {
  name: 'searchs-dnzones'
  scope: resourceGroup
  params: {
    dnsZoneName: 'privatelink.search.windows.net' 
    tags: tags
    virtualNetworkName: networkIsolation?vnet.outputs.name:''
  }
}

// VMs

module testvm './core/vm/dsvm.bicep' = if (networkIsolation && createBastion) {
  name: 'testvm'
  scope: resourceGroup
  params: {
    location: location
    resourceGroupName: resourceGroupName
    name:'testvm${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    aiSubId: (networkIsolation && createBastion)?vnet.outputs.aiSubId:''
    bastionSubId: (networkIsolation && createBastion)?vnet.outputs.bastionSubId:''
    vmUserPassword: vmUserPassword
    vmUserName: vmUserName
  }
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
    allowBlobPublicAccess: networkIsolation?false:true
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
    containers: [{name:containerName, publicAccess: networkIsolation?'None':'Container'}, {name:chunksContainerName}]
  }  
}

module storagepe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'storagepe'
  scope: resourceGroup
  params: {
    location: location
    name:'stragpe0${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?storage.outputs.id:''
    groupIds: ['blob']
    dnsZoneId: networkIsolation?blobDnsZone.outputs.id:''
  }
}


// Database
module cosmosAccount './core/db/cosmos.bicep' = {
  name: 'cosmosaccount'
  scope: resourceGroup
  params: {
    accountName: dbAccountName
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
    location: location
    containerName: 'conversations'
    databaseName: dbDatabaseName
    tags: tags    
  }
}

module cosmospe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'cosmospe'
  scope: resourceGroup
  params: {
    location: location
    name: 'dbgptpe0${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?cosmosAccount.outputs.id:''
    groupIds: ['Sql']
    dnsZoneId: networkIsolation?documentsDnsZone.outputs.id:''
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: keyVaultName
    location: location
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
    tags: tags
    principalId: principalIdvar
  }
}

module keyvaultpe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'keyvaultpe'
  scope: resourceGroup
  params: {
    location: location
    name:'kvpe0${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId:networkIsolation? keyVault.outputs.id:''
    groupIds: ['Vault']
    dnsZoneId: networkIsolation?vaultDnsZone.outputs.id:''
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
      name: 'P0v3'
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
    subnetId: vnet.outputs.appIntSubId
    vnetName: vnet.outputs.name
    networkIsolation: networkIsolation
    keyVaultName: keyVault.outputs.name
    storageAccountName: '${storageAccountName}orc'
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
        name: 'AZURE_SEARCH_USE_SEMANTIC'
        value: useSemanticReranking
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
        name: 'AZURE_OPENAI_CHATGPT_LLM_MONITORING'
        value: chatGptLlmMonitoring
      }
      {
        name: 'AZURE_OPENAI_CHATGPT_MONITORING_DEPLOYMENT'
        value: chatGptMonitoringDeploymentName
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
      {
        name: 'AzureWebJobsSecretStorageType'
        value: 'keyvault'
      }   
      {
        name: 'AzureWebJobsSecretStorageKeyVaultUri'
        value: keyVault.outputs.endpoint
      }
      {
        name: 'LOGLEVEL'
        value: 'INFO'
      }                         
    ]  
  }
}

module orchestratorPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'orchestratorPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'orchestratorPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?orchestrator.outputs.id:''
    groupIds: ['sites']
    dnsZoneId: networkIsolation?websitesDnsZone.outputs.id:''
  }
}

// Give the orchestrator access to KeyVault
module orchestratorKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'orchestrator-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: orchestrator.outputs.identityPrincipalId
  }
} 

module frontEnd  'core/host/appservice.bicep'  = {
  name: 'frontend'
  scope: resourceGroup
  params: {
    name: azureAppServiceName
    applicationInsightsName: appInsightsName
    subnetId: vnet.outputs.appIntSubId
    vnetName: vnet.outputs.name
    appCommandLine: 'python ./app.py'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    basicPublishingCredentials: networkIsolation?true:false
    appSettings: [
      {
        name: 'SPEECH_SYNTHESIS_VOICE_NAME'
        value: speechSynthesisVoiceName
      }
      {
        name: 'SPEECH_SYNTHESIS_LANGUAGE'
        value: speechSynthesisLanguage
      }      
      {
        name: 'SPEECH_RECOGNITION_LANGUAGE'
        value: speechRecognitionLanguage
      }
      {
        name: 'SPEECH_REGION'
        value: location
      }
      {
        name: 'ORCHESTRATOR_URI'
        value: orchestratorUri
      }
      {
        name: 'ORCHESTRATOR_ENDPOINT'
        value: orchestratorEndpoint
      }
      {
        name: 'AZURE_KEY_VAULT_ENDPOINT'
        value: keyVault.outputs.endpoint
      }
      {
        name: 'AZURE_KEY_VAULT_NAME'
        value: keyVault.outputs.name
      }
      {
        name: 'STORAGE_ACCOUNT'
        value: storageAccountName
      } 
      {
        name: 'LOGLEVEL'
        value: 'INFO'
      } 
    ]
  }
}

module frontendPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'frontendPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'frontendPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?frontEnd.outputs.id:''
    groupIds: ['sites']
    dnsZoneId: networkIsolation?websitesDnsZone.outputs.id:''
  }
}

// Give the App Service access to KeyVault
module appsericeKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'appservice-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: frontEnd.outputs.identityPrincipalId
  }
}

// Give the App Service access to Orchestrator Function
module appserviceOrchestratorAccess './core/host/functions-access.bicep' = {
  name: 'appservice-function-access'
  scope: resourceGroup
  params: {
    functionAppName: orchestrator.outputs.name
    principalId: frontEnd.outputs.identityPrincipalId
  }
}

module dataIngestion './core/host/functions.bicep' = {
  name: 'dataIngestion'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    subnetId: vnet.outputs.appIntSubId
    vnetName: vnet.outputs.name
    networkIsolation: networkIsolation
    storageAccountName: '${storageAccountName}ing'
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
        value: cognitiveServiceName
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
      {
        name: 'NETWORK_ISOLATION'
        value: networkIsolation
      }   
      {
        name: 'AzureWebJobsFeatureFlags'
        value: 'EnableWorkerIndexing'
      }
      {
        name: 'LOGLEVEL'
        value: 'INFO'
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

// Give the data ingestion access to blob storage
module dataIngestionBlobStorageAccess './core/security/blobstorage-access.bicep' = {
  name: 'data-ingestion-blobstorage-access'
  scope: resourceGroup
  params: {
    storageAccountName: storage.outputs.name
    principalId: dataIngestion.outputs.identityPrincipalId
  }
}

module ingestionPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'ingestionPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'ingestionPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?dataIngestion.outputs.id:''
    groupIds: ['sites']
    dnsZoneId: networkIsolation?websitesDnsZone.outputs.id:''
  }
}

module cognitiveServices 'core/ai/cognitiveservices.bicep' = {
  name: 'CognitiveServices'
  scope: resourceGroup
  params: {
    name: cognitiveServiceName
    location: location
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
    kind: 'CognitiveServices'
    tags: tags
    sku: {
      name: 'S0'
    }    
  }
}

module cognitiveServicesPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'cognitiveServicesPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'cognitiveServicesPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?cognitiveServices.outputs.id:''
    groupIds: ['account']
    dnsZoneId: networkIsolation?cognitiveservicesDnsZone.outputs.id:''
  }
}


module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: openAiServiceName
    location: location
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
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

module openAiPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'openAiPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'openAiPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?openAi.outputs.id:''
    groupIds: ['account']
    dnsZoneId: networkIsolation?openaiDnsZone.outputs.id:''
  }
}

module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: resourceGroup
  params: {
    name: searchServiceName
    location: location
    publicNetworkAccess: networkIsolation?'Disabled':'Enabled'
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

module searchStoragePrivatelink 'core/search/search-private-link.bicep' = if (networkIsolation) {
  name: 'searchStoragePrivatelink'
  scope: resourceGroup
  params: {
   name: '${searchServiceName}-storagelink'
   searchName: searchServiceName
   resourceId: storage.outputs.id
   groupId: 'blob'
  }
}

module searchFuncAppPrivatelink 'core/search/search-private-link.bicep' = if (networkIsolation) {
  name: 'searchFuncAppPrivatelink'
  scope: resourceGroup
  params: {
   name: '${searchServiceName}-funcapplink'
   searchName: searchServiceName
   resourceId: dataIngestion.outputs.id
    groupId: 'sites'
  }
}

module searchPe './core/network/private-endpoint.bicep' = if (networkIsolation) {
  name: 'searchPe'
  scope: resourceGroup
  params: {
    location: location
    name: 'searchPe${substring(uniqueString(guidValue), 0, 5)}'
    tags: tags
    subnetId: networkIsolation?vnet.outputs.aiSubId:''
    serviceId: networkIsolation?searchService.outputs.id:''
    groupIds: ['searchService']
    dnsZoneId: networkIsolation?searchDnsZone.outputs.id:''
  }
}

module keyVaultSecret './core/security/keyvault-secrets.bicep' = {
  name: 'keyvaultsecrets'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    secretValues: {
      azureSearchKey: {
        name: 'azureSearchKey'
        value: searchService.outputs.apiKey
      }
      formRecKey: {
        name: 'formRecKey'
        value: cognitiveServices.outputs.apiKey
      }
      speechKey: {
        name: 'speechKey'
        value: cognitiveServices.outputs.apiKey
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










//  not in use

// module delay './core/delay.bicep' = {
//   name: 'delay'
//   scope: resourceGroup
//   params: {
//     location: orchestrator.outputs.location
//     sleepSeconds: 360
//   }
// }
