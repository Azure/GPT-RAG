#!/usr/bin/env pwsh
# Stop on errors and enforce strict mode
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# -----------------------------------------------------------------------------
# Default environment-variable values (override by setting $env:DEPLOY*)
# -----------------------------------------------------------------------------
$deployAppConfig     = $env:deployAppConfig     ?? 'true'
$deployContainerApps = $env:deployContainerApps ?? 'true'
$deploySearchService = $env:deploySearchService ?? 'true'
$networkIsolation    = $env:networkIsolation    ?? 'false'

Write-Host "🔧 Running post-provision steps…`n"
Write-Host "📋 Current environment variables:"
foreach ($v in 'deployAppConfig','deployContainerApps','deploySearchService','networkIsolation') {
    $value = Get-Variable -Name $v -ValueOnly
    Write-Host "  $v = $value"
}

# -----------------------------------------------------------------------------
# Find the Python executable
# -----------------------------------------------------------------------------
$python = $null

# Try python3 (exclude stubs in WindowsApps)
$cmd = Get-Command python3 -ErrorAction SilentlyContinue |
       Where-Object { -not ($_.Source -like '*WindowsApps*') }
if ($cmd) { $python = $cmd.Name }

# Fallback to python
if (-not $python) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue |
           Where-Object { -not ($_.Source -like '*WindowsApps*') }
    if ($cmd) { $python = $cmd.Name }
}

# Fallback to Windows py launcher
if (-not $python) {
    $cmd = Get-Command py -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Name }
}

if (-not $python) {
    Throw "Python executable not found. Install Python or ensure it's on PATH."
}

Write-Host "`n🐍 Using Python: $python"

# -----------------------------------------------------------------------------
# 0) Setup Python environment
# -----------------------------------------------------------------------------
Write-Host "`n📦 Creating temporary venv…"
& $python -m venv config/.venv_temp
& config/.venv_temp/Scripts/Activate.ps1  

Write-Host "⬇️ Installing requirements…"
& $python -m pip install --upgrade pip
& $python -m pip install -r config/requirements.txt

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
# 3) Container Apps Setup
# -----------------------------------------------------------------------------
Write-Host ""
if ($deployContainerApps.ToLower() -eq 'true') {
    Write-Host "🔍 Container Apps setup…"
    try {
        Write-Host "🚀 Running config.containerapps.setup…"
        & $python -m config.containerapps.setup
        Write-Host "✅ Container Apps setup script finished."
    } catch {
        Write-Warning "❗️ Error during Container Apps setup. Skipping it."
    }
} else {
    Write-Warning "⚠️ Skipping Container Apps setup (deployContainerApps is not 'true')."
}

# -----------------------------------------------------------------------------
# 4) AI Search Setup
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
# 5) Zero Trust Information
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
Write-Host "🧼 Temporary files removed. All done!"
