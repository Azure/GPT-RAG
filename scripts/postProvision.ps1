# postProvision.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps..."
Write-Host ""

#-------------------------------------------------------------------------------
# Zero Trust Information
#-------------------------------------------------------------------------------
Write-Host ""
if ($env:NETWORK_ISOLATION -and $env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Zero Trust enabled."
    Write-Host "Access to Azure resources is restricted to the VNet."
    Write-Host "Ensure you run scripts/postProvision.ps1 from within the VNet."
    Write-Host "If you are using a local machine, make sure you have a VPN connection to the VNet."
    Write-Host "You can also use the Test VM to access the environment and complete the setup."
    $answer = Read-Host "Are you running this script from inside the VNet or via VPN? [Y/n]"
    if ($answer.ToLower() -notmatch '^(y|yes)$') {
        Write-Host "❌ Please run this script from inside the VNet or with VPN access. Exiting."
        exit 0
    }
} else {
    Write-Host "🚧 Provisioning basic architecture."
}

#-------------------------------------------------------------------------------
# Check required environment variable
#-------------------------------------------------------------------------------
Write-Host "📋 Current environment variables:"
$vars = @('APP_CONFIG_ENDPOINT')
foreach ($v in $vars) {
    $value = [Environment]::GetEnvironmentVariable($v)
    if (-not $value) { $value = '<unset>' }
    Write-Host "  $v=$value"
}

if (-not [Environment]::GetEnvironmentVariable('APP_CONFIG_ENDPOINT')) {
    Write-Host "❗ APP_CONFIG_ENDPOINT environment variable must be set before running this script."
    exit 1
}

#-------------------------------------------------------------------------------
# Setup Python environment
#-------------------------------------------------------------------------------
Write-Host "📦 Creating temporary venv..."
python -m venv --without-pip config/.venv_temp

# Activate the venv
& config/.venv_temp/Scripts/Activate.ps1

Write-Host "⬇️ Manually bootstrapping pip..."
Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -UseBasicParsing |
    Select-Object -ExpandProperty Content |
    & python

Write-Host "⬇️ Installing requirements..."
& python -m pip install --upgrade pip
& python -m pip install -r config/requirements.txt

#-------------------------------------------------------------------------------
# 1) AI Foundry Setup
#-------------------------------------------------------------------------------
Write-Host "`n📑 AI Foundry Setup..."
try {
    Write-Host "🚀 Running config.aifoundry.setup..."
    & python -m config.aifoundry.setup
    Write-Host "✅ AI Foundry setup script finished."
} catch {
    Write-Host "❗ Error during AI Foundry setup. Skipping it."
}

#-------------------------------------------------------------------------------
# 2) Container Apps Setup
#-------------------------------------------------------------------------------
Write-Host "`n🔍 ContainerApp setup..."
try {
    Write-Host "🚀 Running config.containerapps.setup..."
    & python -m config.containerapps.setup
    Write-Host "✅ Container Apps setup script finished."
} catch {
    Write-Host "❗ Error during Container Apps setup. Skipping it."
}

#-------------------------------------------------------------------------------
# 3) AI Search Setup
#-------------------------------------------------------------------------------
Write-Host "🔍 AI Search setup..."
try {
    Write-Host "🚀 Running config.search.setup..."
    & python -m config.search.setup
    Write-Host "✅ Search setup script finished."
} catch {
    Write-Host "❗ Error during Search setup. Skipping it."
}

#-------------------------------------------------------------------------------
# Cleaning up
#-------------------------------------------------------------------------------
Write-Host "`n🧹 Cleaning Python environment up..."
if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
Remove-Item -Recurse -Force config/.venv_temp

Write-Host "`n✅ postProvisioning completed."
