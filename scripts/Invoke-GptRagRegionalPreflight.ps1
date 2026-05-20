param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ParametersPath = (Join-Path $ProjectRoot 'main.parameters.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Truthy {
    param([string]$Value)
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match '^(1|true|t|yes|y)$'
}

if (Test-Truthy $env:GPT_RAG_REGIONAL_PREFLIGHT_SKIP) {
    Write-Host "Skipping GPT-RAG regional preflight (GPT_RAG_REGIONAL_PREFLIGHT_SKIP=$env:GPT_RAG_REGIONAL_PREFLIGHT_SKIP)." -ForegroundColor Yellow
    exit 0
}

function Normalize-Location {
    param([Parameter(Mandatory = $true)][string]$Location)
    return ($Location -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

function Read-AzdEnv {
    $values = @{}
    $output = & azd env get-values 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) { return $values }
    foreach ($line in $output) {
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = ($matches[2].Trim() -replace '^"|"$', '')
            $values[$key] = $value
        }
    }
    return $values
}

function Resolve-ParameterValue {
    param(
        [AllowNull()]$Value,
        [hashtable]$AzdEnv
    )
    if ($null -eq $Value) { return $null }
    if ($Value -isnot [string]) { return $Value }
    if ($Value -match '^\$\{([^}=]+)(?:=([^}]*))?\}$') {
        $name = $matches[1]
        $default = if ($matches.Count -gt 2) { $matches[2] } else { '' }
        $envValue = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) { return $envValue }
        if ($AzdEnv.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($AzdEnv[$name])) { return $AzdEnv[$name] }
        return $default
    }
    return $Value
}

function Convert-ToBool {
    param([AllowNull()]$Value, [bool]$Default = $false)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }
    if ([string]::IsNullOrWhiteSpace("$Value")) { return $Default }
    return "$Value" -match '^(1|true|t|yes|y)$'
}

function Invoke-AzJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & az @Arguments -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($output | Out-String))) { return $null }
    return (($output | Out-String) | ConvertFrom-Json)
}

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Pass','Warn','Fail')][string]$Level,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $script:Checks.Add([pscustomobject]@{ Level = $Level; Name = $Name; Message = $Message }) | Out-Null
}

function Test-ProviderLocation {
    param(
        [Parameter(Mandatory = $true)][string]$ProviderNamespace,
        [Parameter(Mandatory = $true)][string]$ResourceType,
        [Parameter(Mandatory = $true)][string]$Location,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )
    $provider = Invoke-AzJson @('provider', 'show', '--namespace', $ProviderNamespace)
    if (-not $provider) {
        Add-Check Warn $DisplayName "Could not query provider $ProviderNamespace. Ensure Azure CLI is logged in and the provider is registered."
        return
    }
    if ($provider.registrationState -and $provider.registrationState -ne 'Registered') {
        Add-Check Fail $DisplayName "Provider $ProviderNamespace is $($provider.registrationState), not Registered."
        return
    }
    $resourceTypeInfo = @($provider.resourceTypes | Where-Object { $_.resourceType -eq $ResourceType } | Select-Object -First 1)
    if (-not $resourceTypeInfo) {
        Add-Check Warn $DisplayName "Provider $ProviderNamespace did not report resource type $ResourceType."
        return
    }
    $target = Normalize-Location $Location
    $supported = @($resourceTypeInfo.locations | ForEach-Object { Normalize-Location $_ }) -contains $target
    if ($supported) {
        Add-Check Pass $DisplayName "$DisplayName is listed as supported in $Location."
    } else {
        Add-Check Fail $DisplayName "$DisplayName is not listed as supported in $Location."
    }
}

function Test-ModelQuota {
    param(
        [Parameter(Mandatory = $true)]$ModelDeployments,
        [Parameter(Mandatory = $true)][string]$Location
    )
    $usage = Invoke-AzJson @('cognitiveservices', 'usage', 'list', '--location', $Location)
    if (-not $usage) {
        Add-Check Fail 'Azure OpenAI model quota' "Could not read Cognitive Services usage/quota for $Location. Run 'az cognitiveservices usage list --location $Location' and verify Microsoft.CognitiveServices registration."
        return
    }

    $quotaFailures = @()
    foreach ($deployment in @($ModelDeployments)) {
        if (-not $deployment.model -or $deployment.model.format -ne 'OpenAI') { continue }
        $modelName = [string]$deployment.model.name
        $skuName = [string]$deployment.sku.name
        $capacity = [double]$deployment.sku.capacity
        $quotaName = "OpenAI.$skuName.$modelName"
        $quota = @($usage | Where-Object { $_.name.value -eq $quotaName } | Select-Object -First 1)
        if (-not $quota) {
            $quotaFailures += "No quota entry '$quotaName' found in $Location."
            continue
        }
        $current = [double]$quota.currentValue
        $limit = [double]$quota.limit
        $available = $limit - $current
        if ($available -lt $capacity) {
            $quotaFailures += "$quotaName requires $capacity, available $available (usage $current / limit $limit)."
        } else {
            Add-Check Pass "Model quota: $modelName" "$quotaName has $available available in $Location; requested $capacity."
        }
    }

    if ($quotaFailures.Count -gt 0) {
        Add-Check Fail 'Azure OpenAI model quota' ($quotaFailures -join ' ')
        Add-ModelRegionSuggestions -ModelDeployments $ModelDeployments -CurrentLocation $Location
    }
}

function Add-ModelRegionSuggestions {
    param(
        [Parameter(Mandatory = $true)]$ModelDeployments,
        [Parameter(Mandatory = $true)][string]$CurrentLocation
    )
    $candidateRegions = if ($env:GPT_RAG_PREFLIGHT_CANDIDATE_REGIONS) {
        $env:GPT_RAG_PREFLIGHT_CANDIDATE_REGIONS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
        @('swedencentral', 'eastus', 'eastus2', 'westeurope', 'francecentral')
    }
    $suggestions = @()
    foreach ($region in $candidateRegions | Where-Object { $_ -ne $CurrentLocation }) {
        $usage = Invoke-AzJson @('cognitiveservices', 'usage', 'list', '--location', $region)
        if (-not $usage) { continue }
        $ok = $true
        foreach ($deployment in @($ModelDeployments)) {
            if (-not $deployment.model -or $deployment.model.format -ne 'OpenAI') { continue }
            $quotaName = "OpenAI.$($deployment.sku.name).$($deployment.model.name)"
            $quota = @($usage | Where-Object { $_.name.value -eq $quotaName } | Select-Object -First 1)
            if (-not $quota) { $ok = $false; break }
            if (([double]$quota.limit - [double]$quota.currentValue) -lt [double]$deployment.sku.capacity) { $ok = $false; break }
        }
        if ($ok) { $suggestions += $region }
    }
    if ($suggestions.Count -gt 0) {
        Add-Check Warn 'Suggested regions' "Model quota appears sufficient in: $($suggestions -join ', ')."
    }
}

function Test-VmSku {
    param(
        [Parameter(Mandatory = $true)][string]$Location,
        [Parameter(Mandatory = $true)][string]$VmSize
    )
    $sku = Invoke-AzJson @('vm', 'list-skus', '--location', $Location, '--size', $VmSize, '--all')
    $match = $sku | Where-Object { $_.name -eq $VmSize } | Select-Object -First 1
    if (-not $match) {
        Add-Check Fail 'Jumpbox VM SKU' "VM size $VmSize was not found in $Location."
        return
    }
    $restrictions = @()
    if ($match.PSObject.Properties.Name -contains 'restrictions') {
        $restrictions = @($match.restrictions | Where-Object { $_ })
    }
    if ($restrictions.Count -gt 0) {
        $messages = $restrictions | ForEach-Object {
            $reason = if ($_.reasonCode) { $_.reasonCode } else { 'Restricted' }
            "$reason ($($_.type): $($_.values -join ','))"
        }
        Add-Check Fail 'Jumpbox VM SKU' "VM size $VmSize is restricted in ${Location}: $($messages -join '; ')."
    } else {
        Add-Check Pass 'Jumpbox VM SKU' "VM size $VmSize is available in $Location for this subscription."
    }
}

if (-not (Test-Path $ParametersPath)) {
    Write-Host "GPT-RAG regional preflight could not find parameters file: $ParametersPath" -ForegroundColor Red
    exit 2
}

Write-Host "Running GPT-RAG regional preflight checks..." -ForegroundColor Cyan

$script:Checks = [System.Collections.Generic.List[object]]::new()
$azdEnv = Read-AzdEnv
$parameters = (Get-Content -LiteralPath $ParametersPath -Raw | ConvertFrom-Json).parameters

$azdSubscriptionId = if ($azdEnv.ContainsKey('AZURE_SUBSCRIPTION_ID')) { $azdEnv['AZURE_SUBSCRIPTION_ID'] } else { [Environment]::GetEnvironmentVariable('AZURE_SUBSCRIPTION_ID') }
$account = Invoke-AzJson @('account', 'show')
if (-not $account) {
    Add-Check Fail 'Azure CLI login' "Azure CLI is not logged in. Run 'az login' before provisioning."
} elseif ($azdSubscriptionId -and $account.id -ne $azdSubscriptionId) {
    Add-Check Fail 'Azure subscription' "Azure CLI is using subscription $($account.id), but azd env expects $azdSubscriptionId. Run 'az account set --subscription $azdSubscriptionId'."
} else {
    Add-Check Pass 'Azure subscription' "Azure CLI subscription matches azd environment ($($account.id))."
}

$location = Resolve-ParameterValue $parameters.location.value $azdEnv
$aiFoundryLocation = Resolve-ParameterValue $parameters.aiFoundryLocation.value $azdEnv
$cosmosLocation = Resolve-ParameterValue $parameters.cosmosLocation.value $azdEnv
if ([string]::IsNullOrWhiteSpace($aiFoundryLocation)) { $aiFoundryLocation = $location }
if ([string]::IsNullOrWhiteSpace($cosmosLocation)) { $cosmosLocation = $location }

if ([string]::IsNullOrWhiteSpace($location)) {
    Add-Check Fail 'Azure region' "AZURE_LOCATION is not set in the azd environment."
} else {
    Add-Check Pass 'Azure region' "Primary location: $location."
}

$vmSize = Resolve-ParameterValue $parameters.vmSize.value $azdEnv
$deployVm = Convert-ToBool (Resolve-ParameterValue $parameters.deployVM.value $azdEnv) $true
$deploySearch = Convert-ToBool (Resolve-ParameterValue $parameters.deploySearchService.value $azdEnv) $true
$deployCosmos = Convert-ToBool (Resolve-ParameterValue $parameters.deployCosmosDb.value $azdEnv) $true
$deployContainerApps = Convert-ToBool (Resolve-ParameterValue $parameters.deployContainerApps.value $azdEnv) $true
$deployContainerEnv = Convert-ToBool (Resolve-ParameterValue $parameters.deployContainerEnv.value $azdEnv) $true
$deployAiFoundry = Convert-ToBool (Resolve-ParameterValue $parameters.deployAiFoundry.value $azdEnv) $true

if ($location) {
    if ($deployVm -and $vmSize) { Test-VmSku -Location $location -VmSize $vmSize }
    if ($deploySearch) { Test-ProviderLocation -ProviderNamespace 'Microsoft.Search' -ResourceType 'searchServices' -Location $location -DisplayName 'Azure AI Search' }
    if ($deployCosmos) {
        Test-ProviderLocation -ProviderNamespace 'Microsoft.DocumentDB' -ResourceType 'databaseAccounts' -Location $cosmosLocation -DisplayName 'Azure Cosmos DB'
        Add-Check Warn 'Azure Cosmos DB capacity' "Cosmos DB transient regional capacity (for example high-demand ServiceUnavailable) is not exposed by a reliable pre-create quota API; this preflight validates provider/location support only."
    }
    if ($deployContainerApps -or $deployContainerEnv) { Test-ProviderLocation -ProviderNamespace 'Microsoft.App' -ResourceType 'managedEnvironments' -Location $location -DisplayName 'Azure Container Apps Environment' }
}

if ($deployAiFoundry) {
    Test-ProviderLocation -ProviderNamespace 'Microsoft.CognitiveServices' -ResourceType 'accounts' -Location $aiFoundryLocation -DisplayName 'Azure AI Foundry / Cognitive Services'
    Test-ModelQuota -ModelDeployments $parameters.modelDeploymentList.value -Location $aiFoundryLocation
}

$failures = @($script:Checks | Where-Object { $_.Level -eq 'Fail' })
$warnings = @($script:Checks | Where-Object { $_.Level -eq 'Warn' })

foreach ($check in $script:Checks) {
    $color = switch ($check.Level) { 'Pass' { 'Green' } 'Warn' { 'Yellow' } 'Fail' { 'Red' } }
    Write-Host ("[{0}] {1}: {2}" -f $check.Level.ToUpperInvariant(), $check.Name, $check.Message) -ForegroundColor $color
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "GPT-RAG regional preflight failed before provisioning. Choose a supported region or adjust quota/SKU settings, then rerun azd provision." -ForegroundColor Red
    exit 2
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "GPT-RAG regional preflight completed with warnings. Provisioning can continue, but Azure may still fail on transient regional capacity." -ForegroundColor Yellow
} else {
    Write-Host "GPT-RAG regional preflight checks passed." -ForegroundColor Green
}

exit 0
