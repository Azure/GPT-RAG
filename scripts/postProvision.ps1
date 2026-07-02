# postProvision.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps..."
Write-Host ""

#-------------------------------------------------------------------------------
# Mirror azd environment variables into process environment
# This avoids persisting secrets in the User environment (registry)
#-------------------------------------------------------------------------------
& azd env get-values | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    $k = $matches[1]
    $v = $matches[2] -replace '^"|"$'
    Set-Item -Path Env:$k -Value $v
  }
}

#-------------------------------------------------------------------------------
# Zero Trust Information
#-------------------------------------------------------------------------------
function Test-Truthy {
    param([AllowNull()][string]$Value)
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match '^(1|true|t|yes|y)$'
}

Write-Host ""
if (Test-Truthy $env:NETWORK_ISOLATION) {
    Write-Host "🔒 Zero Trust enabled."
    Write-Host "Access to Azure resources is restricted to the VNet."
    Write-Host "Ensure you run scripts/postProvision.ps1 from within the VNet."
    Write-Host "If you are using a local machine, make sure you have a VPN connection to the VNet."
    Write-Host "You can also use the Test VM to access the environment and complete the setup."

    $runningFromJumpbox = Test-Truthy $env:RUN_FROM_JUMPBOX
    if (-not $runningFromJumpbox) {
        if ($env:RUN_FROM_JUMPBOX -and $env:RUN_FROM_JUMPBOX.ToLower() -match '^(false|0|no|skip)$') {
            Write-Host "⏭️ RUN_FROM_JUMPBOX=$($env:RUN_FROM_JUMPBOX); skipping data-plane post-provisioning."
            exit 0
        }
        if (Test-Truthy $env:AZURE_SKIP_NETWORK_ISOLATION_WARNING) {
            Write-Host "⏭️ AZURE_SKIP_NETWORK_ISOLATION_WARNING=$($env:AZURE_SKIP_NETWORK_ISOLATION_WARNING); skipping local data-plane post-provisioning."
            Write-Host "   Re-run from the jumpbox with RUN_FROM_JUMPBOX=true."
            exit 0
        }
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $answer = Read-Host "Are you running this script from inside the VNet or via VPN? [Y/n]"
            if ($answer.ToLower() -notmatch '^(y|yes)$') {
                Write-Host "❌ Please run this script from inside the VNet or with VPN access. Exiting."
                exit 0
            }
        } else {
            Write-Host "⏭️ Non-interactive shell outside the VNet; skipping data-plane post-provisioning."
            Write-Host "   Re-run from the jumpbox with RUN_FROM_JUMPBOX=true."
            exit 0
        }
    }
} else {
    Write-Host "🚧 Provisioning basic architecture."
}

#-------------------------------------------------------------------------------
# Container APP API Keys Warning
#-------------------------------------------------------------------------------
Write-Host ""
if ($env:USE_CAPP_API_KEY -and $env:USE_CAPP_API_KEY.ToLower() -eq 'true') {
    Write-Host "🔑 Using API Key for Container Apps access."
    Write-Host "⚠️ IMPORTANT: Each App API Key was initialized with resourceToken."
    Write-Host "    Please update to a custom API key ASAP."
}

#-------------------------------------------------------------------------------
# Check required environment variable
#-------------------------------------------------------------------------------
Write-Host "📋 Checking required environment variables..."
$requiredVars = @('APP_CONFIG_ENDPOINT')
$missing = @()
foreach ($v in $requiredVars) {
    $val = [Environment]::GetEnvironmentVariable($v)
    if (-not $val) { $missing += $v; Write-Host "  $v=<missing>" -ForegroundColor Yellow } else { Write-Host "  $v=$val" }
}
if ($missing.Count -gt 0) {
    Write-Error "Missing required variables: $($missing -join ', ')."
    exit 1
}

function Get-RequiredEnvValue {
    param([Parameter(Mandatory = $true)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Error "Missing required environment variable '$Name'."
        exit 1
    }
    return $value
}

function Get-OptionalEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Default = ''
    )
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Invoke-NativeCommand {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-AzTsv {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description,
        [switch]$Required
    )
    $output = Invoke-NativeCommand { & az @Arguments -o tsv 2>$null }
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
        if ($Required) {
            Write-Error "Failed to resolve $Description."
            exit 1
        }
        return ''
    }
    return ($output | Select-Object -First 1).Trim()
}

function Get-AppConfigResourceName {
    param([Parameter(Mandatory = $true)][string]$Endpoint)
    return (($Endpoint -replace '^https?://', '') -replace '\.azconfig\.io/?$', '')
}

function ConvertTo-FlatJsonString {
    param([Parameter(Mandatory = $true)]$Value)
    return ($Value | ConvertTo-Json -Depth 50 -Compress)
}

function Set-GptRagAppConfiguration {
    param(
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Write-Host "⚙️ Populating GPT-RAG App Configuration settings (label=$Label)..."
    Invoke-NativeCommand { az config set extension.use_dynamic_install=yes_without_prompt 2>$null | Out-Null }

    $resourceGroup = Get-RequiredEnvValue 'AZURE_RESOURCE_GROUP'
    $subscriptionId = Get-OptionalEnvValue 'AZURE_SUBSCRIPTION_ID'
    if (-not $subscriptionId) {
        $subscriptionId = Invoke-AzTsv -Arguments @('account', 'show', '--query', 'id') -Description 'current subscription id' -Required
    }

    $tenantId = Get-OptionalEnvValue 'AZURE_TENANT_ID'
    if (-not $tenantId) {
        $tenantId = Invoke-AzTsv -Arguments @('account', 'show', '--query', 'tenantId') -Description 'current tenant id' -Required
    }

    $resourceToken = Get-OptionalEnvValue 'RESOURCE_TOKEN'
    if (-not $resourceToken -and $Endpoint -match 'appcs-?([a-z0-9]{8,})\.azconfig\.io') {
        $resourceToken = $matches[1]
    }
    if (-not $resourceToken) {
        Write-Error "RESOURCE_TOKEN could not be resolved; cannot populate GPT-RAG App Configuration deterministically."
        exit 1
    }

    $location = Get-OptionalEnvValue 'AZURE_LOCATION' (Get-OptionalEnvValue 'LOCATION')
    $environmentName = Get-OptionalEnvValue 'AZURE_ENV_NAME' (Get-OptionalEnvValue 'ENVIRONMENT_NAME')
    $deploymentName = Get-OptionalEnvValue 'DEPLOYMENT_NAME'
    $release = Get-OptionalEnvValue 'RELEASE'

    $appConfigName = Get-AppConfigResourceName -Endpoint $Endpoint
    $nameSuffix = $resourceToken

    # --- CAF-aware resource discovery (v3.1.0) ---
    # AI Landing Zone v2.2.0 defaults to caf naming; resource names no longer follow the
    # legacy "<prefix>-$nameSuffix" pattern. Discover actual names by listing resources
    # in the RG; fall back to the legacy derivation only when discovery finds nothing.
    function _resolveResource {
        param([string]$Type, [string]$Fallback, [scriptblock]$Filter = $null)
        try {
            $json = az resource list -g $resourceGroup --resource-type $Type -o json 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $json) { return $Fallback }
            $items = $json | ConvertFrom-Json
            if ($null -eq $items) { return $Fallback }
            if ($Filter) { $items = @($items | Where-Object $Filter) }
            if ($items.Count -eq 1) { return $items[0].name }
            if ($items.Count -eq 0) { return $Fallback }
            Write-Warning "Multiple '$Type' resources matched; falling back to legacy name '$Fallback'."
            return $Fallback
        } catch {
            return $Fallback
        }
    }

    # Storage: main workload vs AI Foundry storage (prefix "staif")
    $storageName = _resolveResource `
        -Type 'Microsoft.Storage/storageAccounts' `
        -Fallback "st$nameSuffix" `
        -Filter { -not $_.name.StartsWith('staif') }
    $foundryStorageName = _resolveResource `
        -Type 'Microsoft.Storage/storageAccounts' `
        -Fallback "staif$nameSuffix" `
        -Filter { $_.name.StartsWith('staif') }

    # Key Vault: main workload vs AI Foundry KV (prefix "kv-ai")
    $keyVaultName = _resolveResource `
        -Type 'Microsoft.KeyVault/vaults' `
        -Fallback "kv-$nameSuffix" `
        -Filter { -not $_.name.StartsWith('kv-ai') }

    # Cosmos: main vs AI Foundry-project cosmos (prefix "cosmos-aif")
    $cosmosName = _resolveResource `
        -Type 'Microsoft.DocumentDB/databaseAccounts' `
        -Fallback "cosmos-$nameSuffix" `
        -Filter { -not $_.name.StartsWith('cosmos-aif') }

    # Search: main vs AI Foundry-project search (prefix "srch-aif")
    $searchName = _resolveResource `
        -Type 'Microsoft.Search/searchServices' `
        -Fallback "srch-$nameSuffix" `
        -Filter { -not $_.name.StartsWith('srch-aif') }

    # AI Foundry Cognitive account (kind = AIServices) — LZ v2.2.0 deploys a single one
    $foundryName = _resolveResource `
        -Type 'Microsoft.CognitiveServices/accounts' `
        -Fallback "aif-$nameSuffix"

    # AI Foundry project (child of foundry account) — resolve via CLI
    $foundryProjectName = 'aifoundry-default-project'
    try {
        $projJson = az cognitiveservices account list-projects -g $resourceGroup -n $foundryName -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $projJson) {
            $projs = $projJson | ConvertFrom-Json
            if ($projs.Count -ge 1) { $foundryProjectName = $projs[0].name }
        }
    } catch { }

    # Container Registry / Container Apps Env / Log Analytics / App Insights
    $acrName = _resolveResource `
        -Type 'Microsoft.ContainerRegistry/registries' `
        -Fallback "cr$nameSuffix"
    $containerEnvName = _resolveResource `
        -Type 'Microsoft.App/managedEnvironments' `
        -Fallback "cae-$nameSuffix"
    $logAnalyticsName = _resolveResource `
        -Type 'Microsoft.OperationalInsights/workspaces' `
        -Fallback "log-$nameSuffix"
    $appInsightsName = _resolveResource `
        -Type 'Microsoft.Insights/components' `
        -Fallback "appi-$nameSuffix"

    # Container apps use the RESOURCE_TOKEN suffix from GPT-RAG's own bicep — this is
    # stable across naming modes.
    $frontendAppName = "ca-$nameSuffix-frontend"
    $orchestratorAppName = "ca-$nameSuffix-orchestrator"
    $dataIngestAppName = "ca-$nameSuffix-dataingest"

    # Cosmos database name — introspect the account to get the actual DB name
    $databaseName = "cosmos-db$nameSuffix"
    try {
        $dbJson = az cosmosdb sql database list -g $resourceGroup -a $cosmosName -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $dbJson) {
            $dbs = $dbJson | ConvertFrom-Json
            if ($dbs.Count -eq 1) { $databaseName = $dbs[0].name }
        }
    } catch { }

    Write-Host "🔎 Resolved resource names:"
    Write-Host "   Foundry:          $foundryName / $foundryProjectName"
    Write-Host "   Storage:          $storageName (main), $foundryStorageName (foundry)"
    Write-Host "   Cosmos / DB:      $cosmosName / $databaseName"
    Write-Host "   Search:           $searchName"
    Write-Host "   Key Vault:        $keyVaultName"
    Write-Host "   ACR / CAE:        $acrName / $containerEnvName"
    Write-Host "   Observability:    $logAnalyticsName / $appInsightsName"
    Write-Host "   Container apps:   $frontendAppName, $orchestratorAppName, $dataIngestAppName"

    $resourceGroupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
    $keyVaultResourceId = "$resourceGroupId/providers/Microsoft.KeyVault/vaults/$keyVaultName"
    $storageResourceId = "$resourceGroupId/providers/Microsoft.Storage/storageAccounts/$storageName"
    $cosmosResourceId = "$resourceGroupId/providers/Microsoft.DocumentDB/databaseAccounts/$cosmosName"
    $searchResourceId = "$resourceGroupId/providers/Microsoft.Search/searchServices/$searchName"
    $foundryResourceId = "$resourceGroupId/providers/Microsoft.CognitiveServices/accounts/$foundryName"
    $foundryProjectResourceId = "$foundryResourceId/projects/$foundryProjectName"
    $containerEnvResourceId = "$resourceGroupId/providers/Microsoft.App/managedEnvironments/$containerEnvName"
    $appInsightsResourceId = "$resourceGroupId/providers/Microsoft.Insights/components/$appInsightsName"
    $logAnalyticsResourceId = "$resourceGroupId/providers/Microsoft.OperationalInsights/workspaces/$logAnalyticsName"

    $frontendFqdn = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $frontendAppName, '--query', 'properties.configuration.ingress.fqdn') -Description "$frontendAppName FQDN" -Required
    $orchestratorFqdn = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $orchestratorAppName, '--query', 'properties.configuration.ingress.fqdn') -Description "$orchestratorAppName FQDN" -Required
    $dataIngestFqdn = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $dataIngestAppName, '--query', 'properties.configuration.ingress.fqdn') -Description "$dataIngestAppName FQDN" -Required

    $frontendPrincipalId = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $frontendAppName, '--query', 'identity.principalId') -Description "$frontendAppName principal id"
    $orchestratorPrincipalId = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $orchestratorAppName, '--query', 'identity.principalId') -Description "$orchestratorAppName principal id"
    $dataIngestPrincipalId = Invoke-AzTsv -Arguments @('containerapp', 'show', '-g', $resourceGroup, '-n', $dataIngestAppName, '--query', 'identity.principalId') -Description "$dataIngestAppName principal id"
    $containerEnvPrincipalId = Invoke-AzTsv -Arguments @('resource', 'show', '--ids', $containerEnvResourceId, '--query', 'identity.principalId') -Description 'Container Apps Environment principal id'
    $searchPrincipalId = Invoke-AzTsv -Arguments @('resource', 'show', '--ids', $searchResourceId, '--query', 'identity.principalId') -Description 'Search service principal id'

    $appInsightsConnectionString = Invoke-AzTsv -Arguments @('resource', 'show', '--ids', $appInsightsResourceId, '--query', 'properties.ConnectionString') -Description 'Application Insights connection string'
    $appInsightsInstrumentationKey = Invoke-AzTsv -Arguments @('resource', 'show', '--ids', $appInsightsResourceId, '--query', 'properties.InstrumentationKey') -Description 'Application Insights instrumentation key'

    $containerApps = @(
        [ordered]@{ name = $orchestratorAppName; serviceName = 'orchestrator'; canonical_name = 'ORCHESTRATOR_APP'; principalId = $orchestratorPrincipalId; fqdn = $orchestratorFqdn },
        [ordered]@{ name = $frontendAppName; serviceName = 'frontend'; canonical_name = 'FRONTEND_APP'; principalId = $frontendPrincipalId; fqdn = $frontendFqdn },
        [ordered]@{ name = $dataIngestAppName; serviceName = 'dataingest'; canonical_name = 'DATA_INGEST_APP'; principalId = $dataIngestPrincipalId; fqdn = $dataIngestFqdn }
    )

    $modelDeployments = @(
        [ordered]@{ canonical_name = 'CHAT_DEPLOYMENT_NAME'; capacity = 100; model = [ordered]@{ format = 'OpenAI'; name = 'gpt-5-nano'; version = '2025-08-07' }; name = 'chat'; version = '2025-08-07'; apiVersion = '2025-12-01-preview'; endpoint = "https://$foundryName.openai.azure.com/" },
        [ordered]@{ canonical_name = 'EMBEDDING_DEPLOYMENT_NAME'; capacity = 100; model = [ordered]@{ format = 'OpenAI'; name = 'text-embedding-3-large'; version = '1' }; name = 'text-embedding'; version = '1'; apiVersion = '2025-01-01-preview'; endpoint = "https://$foundryName.openai.azure.com/" }
    )

    $retrievalBackend = Get-OptionalEnvValue 'RETRIEVAL_BACKEND' 'foundry_iq'
    $foundryIqPattern = Get-OptionalEnvValue 'FOUNDRY_IQ_PATTERN' 'azureBlob'
    $ragIndexName = "ragindex-$resourceToken"
    $knowledgeBaseName = Get-OptionalEnvValue 'KNOWLEDGE_BASE_NAME' "$ragIndexName-rag-kb"
    $knowledgeBaseConnectionName = Get-OptionalEnvValue 'KNOWLEDGE_BASE_CONNECTION_NAME' "$environmentName-knowledge-base-connection"
    $knowledgeBaseEndpoint = if ($retrievalBackend -eq 'foundry_iq') {
        Get-OptionalEnvValue 'KNOWLEDGE_BASE_ENDPOINT' "https://$searchName.search.windows.net"
    }
    else {
        ''
    }
    $knowledgeBaseConnectionId = if ($retrievalBackend -eq 'foundry_iq') {
        Get-OptionalEnvValue 'KNOWLEDGE_BASE_CONNECTION_ID' "$resourceGroupId/providers/Microsoft.CognitiveServices/accounts/$foundryName/projects/$foundryProjectName/connections/$knowledgeBaseConnectionName"
    }
    else {
        ''
    }
    $foundryIqDefaultKnowledgeSourceName = if ($foundryIqPattern -eq 'searchIndex') {
        "$ragIndexName-rag-ks"
    }
    else {
        "$ragIndexName-blob-ks"
    }
    $foundryIqKnowledgeSourceName = if ($retrievalBackend -eq 'foundry_iq') {
        Get-OptionalEnvValue 'FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME' $foundryIqDefaultKnowledgeSourceName
    }
    else {
        ''
    }
    $foundryIqKnowledgeSourceKind = if ($retrievalBackend -eq 'foundry_iq') {
        Get-OptionalEnvValue 'FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND' $foundryIqPattern
    }
    else {
        ''
    }
    $effectiveKnowledgeBaseName = if ($retrievalBackend -eq 'foundry_iq') { $knowledgeBaseName } else { '' }

    $foundryIqConversationKnowledgeSourceName = if ($retrievalBackend -eq 'foundry_iq') {
        Get-OptionalEnvValue 'FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME' "$ragIndexName-conv-ks"
    }
    else {
        ''
    }

    $settings = [ordered]@{
        AZURE_TENANT_ID = $tenantId
        SUBSCRIPTION_ID = $subscriptionId
        AZURE_RESOURCE_GROUP = $resourceGroup
        LOCATION = $location
        ENVIRONMENT_NAME = $environmentName
        DEPLOYMENT_NAME = $deploymentName
        RESOURCE_TOKEN = $resourceToken
        SEARCH_RAG_INDEX_NAME = $ragIndexName
        ENABLE_AGENTIC_RETRIEVAL = (Get-OptionalEnvValue 'ENABLE_AGENTIC_RETRIEVAL' 'false')
        RETRIEVAL_BACKEND = $retrievalBackend
        FOUNDRY_IQ_PATTERN = $foundryIqPattern
        FOUNDRY_IQ_API_VERSION = (Get-OptionalEnvValue 'FOUNDRY_IQ_API_VERSION' '2026-05-01-preview')
        FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN = (Get-OptionalEnvValue 'FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN' 'free')
        FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME = $foundryIqKnowledgeSourceName
        FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND = $foundryIqKnowledgeSourceKind
        FOUNDRY_IQ_STORAGE_CONTAINER_NAME = (Get-OptionalEnvValue 'FOUNDRY_IQ_STORAGE_CONTAINER_NAME' 'documents')
        FOUNDRY_IQ_STORAGE_FOLDER_PATH = (Get-OptionalEnvValue 'FOUNDRY_IQ_STORAGE_FOLDER_PATH')
        FOUNDRY_IQ_IS_ADLS_GEN2 = (Get-OptionalEnvValue 'FOUNDRY_IQ_IS_ADLS_GEN2' 'false')
        FOUNDRY_IQ_CONTENT_EXTRACTION_MODE = (Get-OptionalEnvValue 'FOUNDRY_IQ_CONTENT_EXTRACTION_MODE' 'standard')
        FOUNDRY_IQ_AI_SERVICES_ENDPOINT = (Get-OptionalEnvValue 'FOUNDRY_IQ_AI_SERVICES_ENDPOINT' "https://$foundryName.services.ai.azure.com/")
        FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS = (Get-OptionalEnvValue 'FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS' '["rbacScope"]')
        FOUNDRY_IQ_SEARCH_INDEX_NAME = (Get-OptionalEnvValue 'FOUNDRY_IQ_SEARCH_INDEX_NAME' $ragIndexName)
        FOUNDRY_IQ_SEMANTIC_CONFIGURATION_NAME = (Get-OptionalEnvValue 'FOUNDRY_IQ_SEMANTIC_CONFIGURATION_NAME' 'semantic-config')
        FOUNDRY_IQ_FILTER_ADD_ON_ENABLED = (Get-OptionalEnvValue 'FOUNDRY_IQ_FILTER_ADD_ON_ENABLED' 'false')
        FOUNDRY_IQ_SECURITY_FIELD_NAME = (Get-OptionalEnvValue 'FOUNDRY_IQ_SECURITY_FIELD_NAME' 'metadata_security_id')
        FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS = (Get-OptionalEnvValue 'FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS')
        FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED = (Get-OptionalEnvValue 'FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED' 'false')
        FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME = $foundryIqConversationKnowledgeSourceName
        NETWORK_ISOLATION = (Get-OptionalEnvValue 'NETWORK_ISOLATION' 'false')
        USE_UAI = (Get-OptionalEnvValue 'USE_UAI' 'false')
        USE_CAPP_API_KEY = (Get-OptionalEnvValue 'USE_CAPP_API_KEY' 'false')
        LOG_LEVEL = 'INFO'
        ENABLE_CONSOLE_LOGGING = 'true'
        RELEASE = $release
        APPLICATIONINSIGHTS_CONNECTION_STRING = $appInsightsConnectionString
        APPLICATIONINSIGHTS__INSTRUMENTATIONKEY = $appInsightsInstrumentationKey

        KEY_VAULT_RESOURCE_ID = $keyVaultResourceId
        STORAGE_ACCOUNT_RESOURCE_ID = $storageResourceId
        APP_INSIGHTS_RESOURCE_ID = $appInsightsResourceId
        LOG_ANALYTICS_RESOURCE_ID = $logAnalyticsResourceId
        CONTAINER_ENV_RESOURCE_ID = $containerEnvResourceId
        AI_FOUNDRY_ACCOUNT_RESOURCE_ID = $foundryResourceId
        AI_FOUNDRY_PROJECT_RESOURCE_ID = $foundryProjectResourceId
        SEARCH_SERVICE_UAI_RESOURCE_ID = ''
        KNOWLEDGE_BASE_CONNECTION_ID = $knowledgeBaseConnectionId
        SEARCH_SERVICE_RESOURCE_ID = $searchResourceId
        AZURE_SPEECH_RESOURCE_ID = (Get-OptionalEnvValue 'AZURE_SPEECH_RESOURCE_ID')
        COSMOS_DB_ACCOUNT_RESOURCE_ID = $cosmosResourceId

        AI_FOUNDRY_ACCOUNT_NAME = $foundryName
        AI_FOUNDRY_PROJECT_NAME = $foundryProjectName
        AI_FOUNDRY_STORAGE_ACCOUNT_NAME = $foundryStorageName
        APP_CONFIG_NAME = $appConfigName
        APP_INSIGHTS_NAME = $appInsightsName
        CONTAINER_ENV_NAME = $containerEnvName
        CONTAINER_REGISTRY_NAME = $acrName
        CONTAINER_REGISTRY_LOGIN_SERVER = "$acrName.azurecr.io"
        DATABASE_ACCOUNT_NAME = $cosmosName
        DATABASE_NAME = $databaseName
        SEARCH_SERVICE_NAME = $searchName
        AZURE_SPEECH_RESOURCE_NAME = (Get-OptionalEnvValue 'AZURE_SPEECH_RESOURCE_NAME')
        AZURE_SPEECH_REGION = (Get-OptionalEnvValue 'AZURE_SPEECH_REGION')
        STORAGE_ACCOUNT_NAME = $storageName

        DEPLOY_APP_CONFIG = (Get-OptionalEnvValue 'DEPLOY_APP_CONFIG' 'true')
        DEPLOY_KEY_VAULT = (Get-OptionalEnvValue 'DEPLOY_KEY_VAULT' 'true')
        DEPLOY_LOG_ANALYTICS = (Get-OptionalEnvValue 'DEPLOY_LOG_ANALYTICS' 'true')
        DEPLOY_APP_INSIGHTS = (Get-OptionalEnvValue 'DEPLOY_APP_INSIGHTS' 'true')
        DEPLOY_SEARCH_SERVICE = (Get-OptionalEnvValue 'DEPLOY_SEARCH_SERVICE' 'true')
        DEPLOY_SPEECH_SERVICE = (Get-OptionalEnvValue 'DEPLOY_SPEECH_SERVICE' 'false')
        DEPLOY_STORAGE_ACCOUNT = (Get-OptionalEnvValue 'DEPLOY_STORAGE_ACCOUNT' 'true')
        DEPLOY_COSMOS_DB = (Get-OptionalEnvValue 'DEPLOY_COSMOS_DB' 'true')
        DEPLOY_CONTAINER_APPS = (Get-OptionalEnvValue 'DEPLOY_CONTAINER_APPS' 'true')
        DEPLOY_CONTAINER_REGISTRY = (Get-OptionalEnvValue 'DEPLOY_CONTAINER_REGISTRY' 'true')
        DEPLOY_CONTAINER_ENV = (Get-OptionalEnvValue 'DEPLOY_CONTAINER_ENV' 'true')

        KEY_VAULT_URI = "https://$keyVaultName.vault.azure.net/"
        STORAGE_BLOB_ENDPOINT = "https://$storageName.blob.core.windows.net/"
        AI_FOUNDRY_ACCOUNT_ENDPOINT = "https://$foundryName.cognitiveservices.azure.com/"
        AI_FOUNDRY_PROJECT_ENDPOINT = "https://$foundryName.services.ai.azure.com/api/projects/$foundryProjectName"
        SEARCH_SERVICE_QUERY_ENDPOINT = "https://$searchName.search.windows.net"
        KNOWLEDGE_BASE_ENDPOINT = $knowledgeBaseEndpoint
        AZURE_SPEECH_ENDPOINT = (Get-OptionalEnvValue 'AZURE_SPEECH_ENDPOINT')
        COSMOS_DB_ENDPOINT = "https://$cosmosName.documents.azure.com:443/"

        SEARCH_CONNECTION_ID = ''
        KNOWLEDGE_BASE_NAME = $effectiveKnowledgeBaseName
        BING_CONNECTION_ID = ''
        CONTAINER_ENV_PRINCIPAL_ID = $containerEnvPrincipalId
        SEARCH_SERVICE_PRINCIPAL_ID = $searchPrincipalId

        ORCHESTRATOR_APP_ENDPOINT = "https://$orchestratorFqdn"
        FRONTEND_APP_ENDPOINT = "https://$frontendFqdn"
        DATA_INGEST_APP_ENDPOINT = "https://$dataIngestFqdn"
        ORCHESTRATOR_APP_NAME = $orchestratorAppName
        FRONTEND_APP_NAME = $frontendAppName
        DATA_INGEST_APP_NAME = $dataIngestAppName

        CHAT_DEPLOYMENT_NAME = 'chat'
        EMBEDDING_DEPLOYMENT_NAME = 'text-embedding'
        CONVERSATIONS_DATABASE_CONTAINER = 'conversations'
        DATASOURCES_DATABASE_CONTAINER = 'datasources'
        PROMPTS_CONTAINER = 'prompts'
        MCP_CONTAINER = 'mcp'
        DOCUMENTS_IMAGES_STORAGE_CONTAINER = 'documents-images'
        DOCUMENTS_STORAGE_CONTAINER = 'documents'
        CONVERSATION_CACHE_STORAGE_CONTAINER = 'conversation-cache'
        CONVERSATION_DOCUMENTS_STORAGE_CONTAINER = 'conversation-documents'
        NL2SQL_STORAGE_CONTAINER = 'nl2sql'
        CONTAINER_APPS = (ConvertTo-FlatJsonString $containerApps)
        MODEL_DEPLOYMENTS = (ConvertTo-FlatJsonString $modelDeployments)
    }

    $flatSettings = [ordered]@{}
    foreach ($key in $settings.Keys) {
        $value = $settings[$key]
        $flatSettings[$key] = if ($null -eq $value) { '' } else { "$value" }
    }

    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "gpt-rag-appconfig-$([Guid]::NewGuid().ToString('N')).json"
    try {
        $flatSettings | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $tempFile -Encoding UTF8
        $importOutput = Invoke-NativeCommand {
            az appconfig kv import `
                --endpoint $Endpoint `
                --source file `
                --format json `
                --path $tempFile `
                --label $Label `
                --content-type 'text/plain' `
                --auth-mode login `
                --yes 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to import GPT-RAG App Configuration settings: $importOutput"
            exit 1
        }
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }

    Write-Host "✅ GPT-RAG App Configuration populated ($($flatSettings.Count) keys)."
}

Set-GptRagAppConfiguration -Endpoint (Get-RequiredEnvValue 'APP_CONFIG_ENDPOINT') -Label 'gpt-rag'

#-------------------------------------------------------------------------------
# Setup Python environment
#-------------------------------------------------------------------------------
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:PYTHONPATH = if ($env:PYTHONPATH) { "$repoRoot;$($env:PYTHONPATH)" } else { $repoRoot }
$env:GPT_RAG_REPO_ROOT = $repoRoot
Set-Location $repoRoot

function Invoke-PythonModule {
    param([Parameter(Mandatory = $true)][string]$ModuleName)
    Invoke-NativeCommand { & python -c "import os, runpy, sys; sys.path.insert(0, os.environ['GPT_RAG_REPO_ROOT']); runpy.run_module('$ModuleName', run_name='__main__')" }
}

Write-Host "🐍 Checking Python venv support..."
Invoke-NativeCommand { & python -c "import venv" 2>$null }
$venvSupported = ($LASTEXITCODE -eq 0)
if ($venvSupported) {
    Write-Host "📦 Creating temporary venv..."
    Invoke-NativeCommand { python -m venv --without-pip config/.venv_temp }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # Activate the venv
    & config/.venv_temp/Scripts/Activate.ps1

    Write-Host "⬇️ Manually bootstrapping pip..."
    Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -UseBasicParsing |
        Select-Object -ExpandProperty Content |
        & python
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "⚠️ Python venv is unavailable; using the current Python interpreter and site-packages."
    Write-Host "   This matches the AI Landing Zone jumpbox Python contract used by other solution accelerators."
    Invoke-NativeCommand { & python -m pip --version }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Python pip is required for post-provisioning but is not available on the selected interpreter."
        exit 1
    }
}

Write-Host "⬇️ Installing requirements..."
Invoke-NativeCommand { & python -m pip install --upgrade pip }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Invoke-NativeCommand { & python -m pip install -r config/requirements.txt }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

#-------------------------------------------------------------------------------
# 1) AI Foundry Setup
#-------------------------------------------------------------------------------
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "`n📑 AI Foundry Setup..."
    Write-Host "🚀 Running config.aifoundry.setup..."
    Invoke-PythonModule -ModuleName 'config.aifoundry.setup'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "✅ AI Foundry setup script finished."
} else {
    Write-Host "⏭️  Skipping AI Foundry setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# 2) Container Apps Setup
#-------------------------------------------------------------------------------
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "`n🔍 ContainerApp setup..."
    Write-Host "🚀 Running config.containerapps.setup..."
    Invoke-PythonModule -ModuleName 'config.containerapps.setup'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "✅ Container Apps setup script finished."
} else {
    Write-Host "⏭️  Skipping Container Apps setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# 3) AI Search Setup
#-------------------------------------------------------------------------------
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "🔍 AI Search setup..."
    Write-Host "🚀 Running config.search.setup..."
    Invoke-PythonModule -ModuleName 'config.search.setup'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "✅ Search setup script finished."
} else {
    Write-Host "⏭️  Skipping Search setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# Cleaning up
#-------------------------------------------------------------------------------
# Write-Host "`n🧹 Cleaning Python environment up..."
# if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
# # Try to stop any python processes that reference the temporary venv to avoid file locks
# $venvPattern = "config\\.venv_temp"
# try {
#     $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match $venvPattern) }
# } catch {
#     # Fallback if Get-CimInstance isn't available for some reason
#     $procs = @()
# }

# if ($procs -and $procs.Count -gt 0) {
#     Write-Host "Stopping processes referencing venv:"
#     foreach ($p in $procs) {
#         Write-Host "  Stopping pid $($p.ProcessId) - $($p.Name)"
#         try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
#     }
#     Start-Sleep -Seconds 1
# }

# # Retry removal with exponential backoff to handle transient locks
# $maxRetries = 5
# for ($i = 1; $i -le $maxRetries; $i++) {
#     try {
#         Remove-Item -Recurse -Force config/.venv_temp -ErrorAction Stop
#         Write-Host "Removed venv directory."
#         break
#     } catch {
#         if ($i -eq $maxRetries) {
#             Write-Host "⚠️ Failed to remove venv after $maxRetries attempts: $($_.Exception.Message)"
#         } else {
#             Write-Host ("Retry {0}/{1}: waiting and retrying..." -f $i, $maxRetries)
#             Start-Sleep -Seconds (2 * $i)
#         }
#     }
# }

Write-Host "`n✅ postProvisioning completed."
