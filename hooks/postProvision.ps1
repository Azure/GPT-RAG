# postProvision.ps1 — run post-provision steps in PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Helper: default an env var to 'false' if unset or empty
function Get-EnvDefault($name, $default='false') {
    $val = [Environment]::GetEnvironmentVariable($name)
    return if ($val) { $val } else { $default }
}

# Load and default all flags
$azureInstallAoai             = Get-EnvDefault 'AZURE_INSTALL_AOAI'
$azureInstallSearchService    = Get-EnvDefault 'AZURE_INSTALL_SEARCH_SERVICE'
$azureInstallAIFoundry        = Get-EnvDefault 'AZURE_INSTALL_AI_FOUNDRY'
$azureConfigureRBAC           = Get-EnvDefault 'AZURE_CONFIGURE_RBAC'
$azureNetworkIsolation        = Get-EnvDefault 'AZURE_NETWORK_ISOLATION'
$azureInstallContainerApps    = Get-EnvDefault 'AZURE_INSTALL_CONTAINER_APPS'

Write-Host "🔧 Running post-provision steps…"
Write-Host "📋 Current environment variables:"
foreach ($v in 'AZURE_INSTALL_AOAI','AZURE_INSTALL_SEARCH_SERVICE','AZURE_INSTALL_AI_FOUNDRY','AZURE_CONFIGURE_RBAC','AZURE_NETWORK_ISOLATION','AZURE_INSTALL_CONTAINER_APPS') {
    $val = [Environment]::GetEnvironmentVariable($v)
    if (-not $val) { $val = '<unset>' }
    Write-Host "  $v=$val"
}

###############################################################################
# Setup Python environment
###############################################################################
Write-Host "`n📦 Creating temporary venv…"
$venvPath = 'config/.venv_temp'
python -m venv $venvPath

Write-Host "→ Activating venv…"
& "$venvPath/Scripts/Activate.ps1"

Write-Host "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r config/requirements.txt

###############################################################################
# 1) App Configuration Setup
###############################################################################
Write-Host "`n📑 Seeding App Configuration…"
try {
    Write-Host "🚀 Running config.appconfig.seed_config…"
    python -m config.appconfig.seed_config
    Write-Host "✅ App Configuration script finished."
} catch {
    Write-Host "❗️ Error during App Configuration Setup. Skipping it." -ForegroundColor Yellow
}

###############################################################################
# 2) RBAC Setup
###############################################################################
Write-Host ""
if ($azureConfigureRBAC.ToLower() -eq 'true') {
    Write-Host "📑 RBAC Setup…"
    try {
        Write-Host "🚀 Running config.rbac.rbac_setup…"
        python -m config.rbac.rbac_setup
        Write-Host "✅ RBAC setup script finished."
    } catch {
        Write-Host "❗️ Error during RBAC setup. Skipping it." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skipping RBAC setup (AZURE_CONFIGURE_RBAC is not 'true')."
}

###############################################################################
# 3) AOAI Setup
###############################################################################
Write-Host ""
if ($azureInstallAoai.ToLower() -eq 'true') {
    Write-Host "📑 AOAI Setup…"
    try {
        Write-Host "🚀 Running config.aoai.raipolicies…"
        python -m config.aoai.raipolicies
        Write-Host "✅ AOAI setup script finished."
    } catch {
        Write-Host "❗️ Error during AOAI setup. Skipping it." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skipping AOAI setup (AZURE_INSTALL_AOAI is not 'true')."
}

###############################################################################
# 4) AI Foundry Setup
###############################################################################
Write-Host ""
if ($azureInstallAIFoundry.ToLower() -eq 'true') {
    Write-Host "📑 AI Foundry Setup…"
    try {
        Write-Host "🚀 Running config.aifoundry.aifoundry_setup…"
        python -m config.aifoundry.aifoundry_setup
        Write-Host "✅ AI Foundry setup script finished."
    } catch {
        Write-Host "❗️ Error during AI Foundry setup. Skipping it." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skipping AI Foundry setup (AZURE_INSTALL_AI_FOUNDRY is not 'true')."
}

###############################################################################
# 5) AI Search Setup
###############################################################################
Write-Host ""
if ($azureInstallSearchService.ToLower() -eq 'true') {
    Write-Host "🔍 AI Search setup…"
    try {
        Write-Host "🚀 Running config.search.search_setup…"
        python -m config.search.search_setup
        Write-Host "✅ Search setup script finished."
    } catch {
        Write-Host "❗️ Error during Search setup. Skipping it." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skipping AI Search setup (AZURE_INSTALL_SEARCH_SERVICE is not 'true')."
}

###############################################################################
# 6) Container Apps Setup
###############################################################################
Write-Host ""
if ($azureInstallContainerApps.ToLower() -eq 'true') {
    Write-Host "🔍 Container Apps setup…"
    try {
        Write-Host "🚀 Running config.containerapps.capp_setup…"
        python -m config.containerapps.capp_setup
        Write-Host "✅ Container Apps setup script finished."
    } catch {
        Write-Host "❗️ Error during Container Apps setup. Skipping it." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Skipping Container Apps setup (AZURE_INSTALL_CONTAINER_APPS is not 'true')."
}

###############################################################################
# 7) Zero Trust Information
###############################################################################
Write-Host ""
if ($azureNetworkIsolation.ToLower() -eq 'true') {
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM: $env:AZURE_VM_NAME"
    Write-Host "  User: $env:AZURE_VM_USER_NAME"
    Write-Host "  Credentials: $env:AZURE_BASTION_KV_NAME/$env:AZURE_VM_KV_SEC_NAME"
} else {
    Write-Host "🚧 Zero Trust not enabled; provisioning Standard architecture."
}

Write-Host "`n✅ postProvisioning completed."

###############################################################################
# Cleaning up
###############################################################################
Write-Host "`n🧹 Cleaning Python environment up…"
deactivate
Remove-Item -Recurse -Force $venvPath
