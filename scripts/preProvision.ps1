# predeployment-network-warning.ps1
# Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize infrastructure submodule
$projectRoot = Join-Path $PSScriptRoot ".."
$infraDir = Join-Path $projectRoot "infra"
$mainBicep = Join-Path $infraDir "main.bicep"

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
    Write-Host "  Infra repo: $infraUrl @ $infraRef (from .gitmodules)" -ForegroundColor Cyan

    # Remove the empty infra directory and clone at the correct tag
    if (Test-Path $infraDir) { Remove-Item -Path $infraDir -Recurse -Force }
    git -c advice.detachedHead=false clone --depth 1 --branch $infraRef $infraUrl $infraDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to clone infra repository ($infraUrl @ $infraRef)." -ForegroundColor Red
        exit 1
    }
    Write-Host "Infrastructure submodule cloned successfully." -ForegroundColor Green
}

foreach ($fileName in @("manifest.json", "main.parameters.json")) {
    $src = Join-Path $projectRoot $fileName
    $dst = Join-Path $infraDir $fileName
    if (Test-Path $src) {
        Write-Host "Applying project $fileName to infra..." -ForegroundColor Cyan
        Copy-Item -Path $src -Destination $dst -Force
    }
}

# Helper to match truthy values (1, true, t)
function Test-Truthy($value) {
    if (-not $value) { return $false }
    return $value -match '^(1|true|t)$'
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
