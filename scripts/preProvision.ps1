# predeployment-network-warning.ps1
# Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#-------------------------------------------------------------------------------
# Mirror azd environment variables into process environment
# This avoids persisting secrets in the User environment (registry), and makes
# any previously-persisted GPT-RAG topology markers (AZURE_RESOURCE_GROUP,
# APP_CONFIG_ENDPOINT, DEPLOYMENT_TOPOLOGY, ...) visible to the topology
# resolution step below on a second/subsequent 'azd provision' run.
#-------------------------------------------------------------------------------
& azd env get-values | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    $k = $matches[1]
    $v = $matches[2] -replace '^"|"$'
    Set-Item -Path Env:$k -Value $v
  }
}

# Initialize infrastructure submodule
$projectRoot = Join-Path $PSScriptRoot ".."
$infraDir = Join-Path $projectRoot "infra"
$mainBicep = Join-Path $infraDir "main.bicep"
$manifestSource = Join-Path $projectRoot "manifest.json"
if (-not (Test-Path $manifestSource)) {
    Write-Host "Error: manifest.json is required to verify the infrastructure release pin." -ForegroundColor Red
    exit 1
}
$expectedInfraCommit = (Get-Content -LiteralPath $manifestSource -Raw | ConvertFrom-Json).ailz_commit

Write-Host "Initializing infrastructure submodule..." -ForegroundColor Cyan
git submodule update --init --recursive 2>$null

# Fallback: when the repo was scaffolded via 'azd init' (ZIP download), the git
# index has no submodule gitlink entries, so 'git submodule update' silently does
# nothing and infra/ remains empty.  Detect that case and clone the landing-zone
# repo directly.
if (-not (Test-Path $mainBicep)) {
    Write-Host "Submodule content not found. Cloning infra repo directly (azd init scenario)..." -ForegroundColor Cyan

    # Extract infra repo URL and branch from .gitmodules
    $gitmodulesPath = Join-Path $projectRoot ".gitmodules"
    $infraUrl = $null
    $infraRef = "main"  # safe default
    if (Test-Path $gitmodulesPath) {
        $urlMatch = Select-String -Path $gitmodulesPath -Pattern 'url\s*=\s*(.+)' | Select-Object -First 1
        if ($urlMatch) { $infraUrl = $urlMatch.Matches.Groups[1].Value.Trim() }
        $branchMatch = Select-String -Path $gitmodulesPath -Pattern 'branch\s*=\s*(.+)' | Select-Object -First 1
        if ($branchMatch) { $infraRef = $branchMatch.Matches.Groups[1].Value.Trim() }
    }
    if (-not $infraUrl) {
        Write-Host "Error: Could not determine infra repository URL from .gitmodules." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Infra repo: $infraUrl @ $infraRef, pinned to $expectedInfraCommit" -ForegroundColor Cyan

    # Remove the empty directory and materialize the exact manifest pin. The
    # configured branch can advance independently of this integration commit.
    if (Test-Path $infraDir) { Remove-Item -Path $infraDir -Recurse -Force }
    git clone --filter=blob:none --no-checkout $infraUrl $infraDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to clone infra repository ($infraUrl)." -ForegroundColor Red
        exit 1
    }
    git -C $infraDir fetch --depth 1 origin $expectedInfraCommit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to fetch infra commit $expectedInfraCommit." -ForegroundColor Red
        exit 1
    }
    git -C $infraDir -c advice.detachedHead=false checkout --detach $expectedInfraCommit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to check out infra commit $expectedInfraCommit." -ForegroundColor Red
        exit 1
    }
    Write-Host "Infrastructure submodule cloned successfully." -ForegroundColor Green
}

$actualInfraCommitOutput = & git -C $infraDir rev-parse HEAD 2>$null
$revParseExitCode = $LASTEXITCODE
$actualInfraCommit = if ($actualInfraCommitOutput) { "$actualInfraCommitOutput".Trim() } else { '' }
if ($revParseExitCode -ne 0 -or -not $expectedInfraCommit -or $actualInfraCommit -ne $expectedInfraCommit) {
    Write-Host "Error: infra must resolve to $expectedInfraCommit but is at $actualInfraCommit." -ForegroundColor Red
    exit 1
}
if (Test-Path $manifestSource) {
    Write-Host "Applying project manifest.json to infra..." -ForegroundColor Cyan
    Copy-Item -Path $manifestSource -Destination (Join-Path $infraDir "manifest.json") -Force
}

$parameterSource = Join-Path $projectRoot "main.parameters.json"
$parameterDestination = Join-Path $infraDir "main.parameters.json"

# ADR-0001 rev. 5: resolve and materialize the GPT-RAG deployment topology
# (fresh default, sticky existing/persisted-classic, explicit override, or a
# fail-closed error with migration guidance on conflicting persisted signals)
# before composing main.parameters.json. Materializing DEPLOYMENT_TOPOLOGY
# (and the paired legacy flags) into both the process environment and the azd
# environment here is what lets preDeploy/postProvision read back the exact
# same decision later via 'config.deployment.topology --describe', with no
# further Azure CLI lookups and no duplicated detection logic.
Write-Host "Resolving GPT-RAG deployment topology..." -ForegroundColor Cyan
Push-Location $projectRoot
try {
    $topologyOutput = & python -m config.deployment.topology
    $topologyExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($topologyExitCode -ne 0) {
    Write-Host "Error: GPT-RAG deployment topology resolution failed." -ForegroundColor Red
    exit $topologyExitCode
}
$azureEnvName = $env:AZURE_ENV_NAME
foreach ($line in $topologyOutput) {
    if ("$line" -match '^([^=]+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2]
        Set-Item -Path "Env:$name" -Value $value
        if ($azureEnvName) {
            & azd env set $name $value --environment $azureEnvName --no-prompt | Out-Null
        } else {
            & azd env set $name $value --no-prompt | Out-Null
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to persist deployment topology setting $name." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
}

Write-Host "Composing GPT-RAG deployment mode..." -ForegroundColor Cyan
Push-Location $projectRoot
try {
    $hostedSourceCommit = (
        Get-Content -LiteralPath $manifestSource -Raw |
            ConvertFrom-Json
    ).components |
        Where-Object { $_.name -eq 'gpt-rag-orchestrator' } |
        Select-Object -ExpandProperty commit -First 1
    & python -m config.deployment.composition `
        --input $parameterSource `
        --output $parameterDestination `
        --hosted-source-commit $hostedSourceCommit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: GPT-RAG deployment mode composition failed." -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

# Helper to match truthy values (1, true, t)
function Test-Truthy($value) {
    if (-not $value) { return $false }
    return $value -match '^(1|true|t)$'
}

# GPT-RAG regional readiness preflight
$regionalPreflightScript = Join-Path $PSScriptRoot "Invoke-RegionalPreflight.ps1"
if ((Test-Path $regionalPreflightScript) -and (-not (Test-Truthy $env:PREFLIGHT_SKIP)) -and (-not (Test-Truthy $env:GPT_RAG_REGIONAL_PREFLIGHT_SKIP))) {
    Write-Host "Running GPT-RAG regional preflight..." -ForegroundColor Cyan
    & pwsh -NoProfile -File $regionalPreflightScript -ProjectRoot $projectRoot -ParameterFile $parameterDestination
    if ($LASTEXITCODE -ne 0) {
        Write-Host "GPT-RAG regional preflight failed. Fix the reported blockers, or set GPT_RAG_REGIONAL_PREFLIGHT_SKIP=true to bypass only this check." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# AI Landing Zone v2.0.4+ preflight validation
# https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.4/scripts/Invoke-PreflightChecks.ps1
# Covers parameter/topology/BYO/IP checks plus regional readiness (subscription drift,
# provider/location, AI Search & Cosmos capacity warnings, jumpbox VM SKU, model quota).
$preflightScript = Join-Path $infraDir "scripts/Invoke-PreflightChecks.ps1"
if ((Test-Path $preflightScript) -and (-not (Test-Truthy $env:PREFLIGHT_SKIP))) {
    Write-Host "Running landing-zone preflight checks..." -ForegroundColor Cyan
    & pwsh -NoProfile -File $preflightScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Preflight checks failed. Fix the reported parameter issues, or set PREFLIGHT_SKIP=true to bypass." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# 1) Network Isolation Warning
# Accept both historical and current variable names
$networkIsolation = $env:AZURE_NETWORK_ISOLATION
if (-not $networkIsolation) { $networkIsolation = $env:NETWORK_ISOLATION }
$skipWarning = $env:AZURE_SKIP_NETWORK_ISOLATION_WARNING

if (Test-Truthy $skipWarning) { exit 0 }

if (Test-Truthy $networkIsolation) {
    Write-Host "Warning!" -ForegroundColor Yellow -NoNewline
    Write-Host " Network isolation is enabled." -ForegroundColor Yellow
    Write-Host " - After provisioning, you must switch to the" -NoNewline
    Write-Host " Jumpbox / Bastion" -ForegroundColor Green -NoNewline
    Write-Host " to continue deploying components." -ForegroundColor Yellow
    Write-Host " - Infrastructure will only be reachable from within the private network.`n" -ForegroundColor Yellow

    $prompt = "? Continue with Zero Trust provisioning? [Y/n]: "
    Write-Host $prompt -ForegroundColor Blue -NoNewline
    $confirmation = Read-Host
    if ($confirmation -and $confirmation -notin 'Y','y') { exit 1 }
}

exit 0
