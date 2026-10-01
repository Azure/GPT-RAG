<#
.SYNOPSIS
    Create or update the GPT-RAG Foundry IQ Pattern B knowledge source and knowledge base.

.DESCRIPTION
    Uses Azure AI Search data-plane REST APIs to register an existing GPT-RAG
    Azure AI Search index as a Foundry IQ searchIndex knowledge source, then
    creates or updates a knowledge base that references it.

    This script is intentionally post-provision rather than Bicep because
    knowledge sources and knowledge bases are Azure AI Search data-plane
    objects. It uses the signed-in Azure CLI identity and requires Search
    Service Contributor on the target search service.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SearchEndpoint,

    [Parameter(Mandatory)]
    [string]$KnowledgeBaseName,

    [Parameter(Mandatory)]
    [string]$KnowledgeSourceName,

    [Parameter(Mandatory)]
    [string]$SearchIndexName,

    [Parameter(Mandatory)]
    [string]$SemanticConfigurationName,

    [string]$ApiVersion = '2026-05-01-preview',

    [string[]]$SourceDataFields = @('id', 'title', 'filepath', 'url', 'content'),

    [string[]]$SearchFields = @('content'),

    [string]$BaseFilter = '',

    [ValidateSet('', 'free', 'standard')]
    [string]$KnowledgeRetrievalBillingPlan = '',

    [string]$SearchServiceResourceId = '',

    [string]$Description = 'GPT-RAG Azure AI Search index registered as a Foundry IQ Pattern B knowledge source.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SearchToken {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI is required. Install az and run az login.'
    }

    $token = & az account get-access-token --scope 'https://search.azure.com/.default' --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw 'Could not acquire an Azure AI Search data-plane token. Run az login and verify Search Service Contributor permissions.'
    }
    return $token.Trim()
}

function Get-ArmToken {
    $token = & az account get-access-token --scope 'https://management.azure.com/.default' --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw 'Could not acquire an Azure Resource Manager token. Run az login and verify permissions on the search service.'
    }
    return $token.Trim()
}

function Invoke-SearchRest {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [object]$Body
    )

    $endpoint = $SearchEndpoint.TrimEnd('/')
    $uri = '{0}/{1}?api-version={2}' -f $endpoint, $Path.TrimStart('/'), $ApiVersion
    $headers = @{
        Authorization = "Bearer $script:SearchToken"
        'Content-Type' = 'application/json'
    }

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }

    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json
}

function ConvertTo-FieldReferences {
    param([string[]]$Names)

    $refs = @()
    foreach ($name in $Names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $refs += @{ name = $name.Trim() }
    }
    return $refs
}

function Set-KnowledgeRetrievalBillingPlan {
    if ([string]::IsNullOrWhiteSpace($KnowledgeRetrievalBillingPlan)) { return }
    if ([string]::IsNullOrWhiteSpace($SearchServiceResourceId)) {
        throw 'SearchServiceResourceId is required when KnowledgeRetrievalBillingPlan is set.'
    }

    $armToken = Get-ArmToken
    $uri = 'https://management.azure.com{0}?api-version=2026-03-01-preview' -f $SearchServiceResourceId
    $body = @{
        properties = @{
            knowledgeRetrieval = $KnowledgeRetrievalBillingPlan
        }
    } | ConvertTo-Json -Depth 10

    Invoke-RestMethod -Method 'PATCH' -Uri $uri -Headers @{
        Authorization = "Bearer $armToken"
        'Content-Type' = 'application/json'
    } -Body $body | Out-Null
}

function Test-SearchIndexForFoundryIq {
    $index = Invoke-SearchRest -Method 'GET' -Path "indexes/$SearchIndexName" -Body $null

    $semanticConfigs = @()
    if ($index.semantic -and $index.semantic.configurations) {
        $semanticConfigs = @($index.semantic.configurations | ForEach-Object { $_.name })
    }
    if ($semanticConfigs -notcontains $SemanticConfigurationName) {
        throw "Search index '$SearchIndexName' does not define semantic configuration '$SemanticConfigurationName'. Foundry IQ agentic retrieval requires a semantic configuration."
    }

    $fieldNames = @($index.fields | ForEach-Object { $_.name })
    foreach ($field in @($SourceDataFields + $SearchFields)) {
        if ([string]::IsNullOrWhiteSpace($field)) { continue }
        if ($fieldNames -notcontains $field) {
            throw "Search index '$SearchIndexName' does not contain configured field '$field'."
        }
    }
}

$script:SearchToken = Get-SearchToken

if (-not [string]::IsNullOrWhiteSpace($KnowledgeRetrievalBillingPlan) -and $PSCmdlet.ShouldProcess($SearchServiceResourceId, "Set knowledgeRetrieval billing plan to '$KnowledgeRetrievalBillingPlan'")) {
    Set-KnowledgeRetrievalBillingPlan
}

Write-Host "[foundry-iq] Validating search index '$SearchIndexName' at '$SearchEndpoint'."
Test-SearchIndexForFoundryIq

$searchIndexParameters = @{
    searchIndexName = $SearchIndexName
    semanticConfigurationName = $SemanticConfigurationName
    sourceDataFields = ConvertTo-FieldReferences -Names $SourceDataFields
}
$searchFieldReferences = ConvertTo-FieldReferences -Names $SearchFields
if ($searchFieldReferences.Count -gt 0) {
    $searchIndexParameters.searchFields = $searchFieldReferences
}
if (-not [string]::IsNullOrWhiteSpace($BaseFilter)) {
    if ($ApiVersion -ne '2026-05-01-preview') {
        throw 'BaseFilter requires API version 2026-05-01-preview.'
    }
    $searchIndexParameters.baseFilter = $BaseFilter
}

$knowledgeSourceBody = @{
    name = $KnowledgeSourceName
    kind = 'searchIndex'
    description = $Description
    encryptionKey = $null
    searchIndexParameters = $searchIndexParameters
}

$knowledgeBaseBody = @{
    name = $KnowledgeBaseName
    description = 'GPT-RAG Foundry IQ knowledge base.'
    retrievalInstructions = $null
    answerInstructions = $null
    outputMode = $null
    knowledgeSources = @(
        @{ name = $KnowledgeSourceName }
    )
    models = @()
    encryptionKey = $null
    retrievalReasoningEffort = @{
        kind = 'low'
    }
}

if ($PSCmdlet.ShouldProcess($KnowledgeSourceName, 'Create or update Foundry IQ knowledge source')) {
    Invoke-SearchRest -Method 'PUT' -Path "knowledgesources/$KnowledgeSourceName" -Body $knowledgeSourceBody | Out-Null
    Write-Host "[foundry-iq] Knowledge source '$KnowledgeSourceName' is configured."
}

if ($PSCmdlet.ShouldProcess($KnowledgeBaseName, 'Create or update Foundry IQ knowledge base')) {
    Invoke-SearchRest -Method 'PUT' -Path "knowledgebases/$KnowledgeBaseName" -Body $knowledgeBaseBody | Out-Null
    Write-Host "[foundry-iq] Knowledge base '$KnowledgeBaseName' is configured."
}
