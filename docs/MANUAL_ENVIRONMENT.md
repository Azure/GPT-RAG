# Environment Vars Settings for Manual Installation

The applications (orchestrator, data ingestion, and frontend web app) use information obtained from environment variables. These variables are stored as App Settings in each application. When using the automated procedure, you don't need to worry about this. However, for the manual procedure, you'll need to set these variables manually. On this page, you have an example of how to set these variables using the Azure CLI. You will need to adjust the commands to correctly reflect the names of your applications and parameters.

## Environment Variables for Orchestrator

```powershell
az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings APPINSIGHTS_INSTRUMENTATIONKEY="replace-by-the-instrumentation-key"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings APPLICATIONINSIGHTS_CONNECTION_STRING="app-insights-connection-string"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_DB_ID="dbgpt0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_DB_NAME="db0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_ENDPOINT="https://kv0-randomsufix.vault.azure.net/"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_NAME="kv0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_API_VERSION="2024-02-15-preview"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_CHATGPT_DEPLOYMENT="chat"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_CHATGPT_LLM_MONITORING="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_CHATGPT_MODEL="gpt-4o"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_EMBEDDING_MODEL="text-embedding-ada-002"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_LOAD_BALANCING="false"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_RESOURCE="oai0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_STREAM="false"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_API_VERSION="2023-10-01-Preview"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_APPROACH="hybrid"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_INDEX="ragindex"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_SERVICE="search0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_USE_SEMANTIC="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AzureWebJobsStorage="app-insights-connection-string"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings BING_RETRIEVAL="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings BING_SEARCH_TOP_K="2"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings BUILD_FLAGS="UseExpressBuild"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ENABLE_ORYX_BUILD="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings FUNCTIONS_EXTENSION_VERSION="~4"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings FUNCTIONS_WORKER_RUNTIME="python"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings LOGLEVEL="INFO"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ORCHESTRATOR_MESSAGES_LANGUAGE="en"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings RETRIEVAL_PRIORITY="bing"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SCM_DO_BUILD_DURING_DEPLOYMENT="1"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_RETREIVAL="false"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings WEBSITE_CONTENTAZUREFILECONNECTIONSTRING="functionstorageconnectionstring"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings WEBSITE_CONTENTSHARE="fnorch0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings XDG_CACHE_HOME="/tmp/.cache"
```

## Environment Variables for Data Ingestion

```powershell
az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings APPINSIGHTS_INSTRUMENTATIONKEY="app-insights-instrumentation-key"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings APPLICATIONINSIGHTS_CONNECTION_STRING="app-insights-connection-string"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_FORMREC_SERVICE="cs0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_ENDPOINT="https://kv0-randomsufix.vault.azure.net/"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_NAME="kv0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_API_VERSION="2024-02-15-preview"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_EMBEDDING_DEPLOYMENT="text-embedding-ada-002"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_OPENAI_SERVICE_NAME="oai0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_SEARCH_APPROACH="hybrid"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings Azure

WebJobsFeatureFlags="EnableWorkerIndexing"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AzureWebJobsStorage="functionstorageconnectionstring"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings DOCINT_API_VERSION="2023-07-31"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ENABLE_ORYX_BUILD="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings FUNCTION_APP_NAME="fninges0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings FUNCTIONS_EXTENSION_VERSION="~4"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings FUNCTIONS_WORKER_RUNTIME="python"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings LOGLEVEL="INFO"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings MIN_CHUNK_SIZE="100"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings NETWORK_ISOLATION="false"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings NUM_TOKENS="2048"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SCM_DO_BUILD_DURING_DEPLOYMENT="true"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_ANALYZER_NAME="standard"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_API_VERSION="2023-10-01-Preview"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_INDEX_INTERVAL="PT1H"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_INDEX_NAME="ragindex"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SEARCH_SERVICE="search0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings STORAGE_ACCOUNT_NAME="strag0randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings STORAGE_CONTAINER="documents"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings TOKEN_OVERLAP="200"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings WEBSITE_CONTENTAZUREFILECONNECTIONSTRING="functionstorageconnectionstring"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings WEBSITE_CONTENTSHARE="fninges0-randomsufix"
```

## Environment Variables for Frontend App Service

```powershell
az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings APPLICATIONINSIGHTS_CONNECTION_STRING="app-insights-instrumentation-key"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_ENDPOINT="https://kv0-randomsufix.vault.azure.net/"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings AZURE_KEY_VAULT_NAME="kv0-randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ENABLE_ORYX_BUILD="True"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings LOGLEVEL="INFO"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ORCHESTRATOR_ENDPOINT="https://fnorch0-randomsufix.azurewebsites.net/api/orc"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings ORCHESTRATOR_URI="https://fnorch0-randomsufix.azurewebsites.net"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SCM_DO_BUILD_DURING_DEPLOYMENT="True"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SPEECH_RECOGNITION_LANGUAGE="en-US"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SPEECH_REGION="your-region"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SPEECH_SYNTHESIS_LANGUAGE="en-US"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings SPEECH_SYNTHESIS_VOICE_NAME="en-US-RyanMultilingualNeural"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings STORAGE_ACCOUNT="strag0randomsufix"

az functionapp config appsettings set --name <FUNCTION_APP_NAME> --resource-group <RESOURCE_GROUP> --settings WEBSITE_HTTPLOGGING_RETENTION_DAYS="1"
```