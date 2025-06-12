#!/usr/bin/env pwsh
# Stop on errors and enforce strict mode
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# -----------------------------------------------------------------------------
# Default environment-variable values (override by setting $env:DEPLOY*)
# -----------------------------------------------------------------------------
$deployAppConfig     = $env:deployAppConfig     ?? 'true'
$deploySearchService = $env:deploySearchService ?? 'true'
$networkIsolation    = $env:networkIsolation    ?? 'false'

Write-Host "🔧 Running post-provision steps…`n"
Write-Host "📋 Current environment variables:"
foreach ($v in 'deployAppConfig','deploySearchService','networkIsolation') {
    $value = Get-Variable -Name $v -ValueOnly
    Write-Host "  $v = $value"
}

# -----------------------------------------------------------------------------
# Find the Python executable
# -----------------------------------------------------------------------------
$python = (Get-Command python3 -ErrorAction SilentlyContinue)?.Name
if (-not $python) { $python = (Get-Command python -ErrorAction Stop).Name }

# -----------------------------------------------------------------------------
# 0) Setup Python environment
# -----------------------------------------------------------------------------
Write-Host "`n📦 Creating temporary venv…"
& $python -m venv --without-pip config/.venv_temp

# Activate it (cross-platform)
if (Test-Path 'config/.venv_temp/Scripts/Activate.ps1') {
    & 'config/.venv_temp/Scripts/Activate.ps1'
} elseif (Test-Path 'config/.venv_temp/bin/Activate.ps1') {
    & 'config/.venv_temp/bin/Activate.ps1'
} else {
    Throw "Activation script not found in config/.venv_temp"
}

Write-Host "⬇️ Manually bootstrapping pip…"
Invoke-WebRequest https://bootstrap.pypa.io/get-pip.py -UseBasicParsing |
    & $python

Write-Host "⬇️ Installing requirements…"
pip install --upgrade pip
pip install -r config/requirements.txt

# -----------------------------------------------------------------------------
# 1) App Configuration Setup
# -----------------------------------------------------------------------------
Write-Host "`n📑 Seeding App Configuration…"
try {
    Write-Host "🚀 Running config.appconfig.setup…"
    & $python -m config.appconfig.setup
    Write-Host "✅ App Configuration script finished."
} catch {
    Write-Warning "❗️ Error during App Configuration Setup. Skipping it."
}

# -----------------------------------------------------------------------------
# 2) AI Foundry Setup
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "📑 AI Foundry Setup…"
try {
    Write-Host "🚀 Running config.aifoundry.setup…"
    & $python -m config.aifoundry.setup
    Write-Host "✅ AI Foundry setup script finished."
} catch {
    Write-Warning "❗️ Error during AI Foundry setup. Skipping it."
}


# -----------------------------------------------------------------------------
# 3) AI Search Setup
# -----------------------------------------------------------------------------
Write-Host ""
if ($deploySearchService.ToLower() -eq 'true') {
    Write-Host "🔍 AI Search setup…"
    try {
        Write-Host "🚀 Running config.search.setup…"
        & $python -m config.search.setup
        Write-Host "✅ Search setup script finished."
    } catch {
        Write-Warning "❗️ Error during Search setup. Skipping it."
    }
} else {
    Write-Warning "⚠️ Skipping AI Search setup (deploySearchService is not 'true')."
}

# -----------------------------------------------------------------------------
# 4) Zero Trust Information
# -----------------------------------------------------------------------------
Write-Host ""
if ($networkIsolation.ToLower() -eq 'true') {
    Write-Host "🔒 Access the Zero Trust bastion"
} else {
    Write-Host "🚧 Zero Trust not enabled; provisioning Basic architecture."
}

Write-Host "`n✅ postProvisioning completed.`n"

# -----------------------------------------------------------------------------
# Cleaning up
# -----------------------------------------------------------------------------
Write-Host "🧹 Cleaning Python environment up…"
# 'deactivate' is defined by the Activate.ps1 script
if (Get-Command deactivate -ErrorAction SilentlyContinue) {
    deactivate
}
Remove-Item -Recurse -Force config/.venv_temp
