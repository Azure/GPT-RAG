# postProvision.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps..."
Write-Host ""

#-------------------------------------------------------------------------------
# Mirroring azd env variables in system env variables
#-------------------------------------------------------------------------------
& azd env get-values | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    $k = $matches[1]
    $v = $matches[2] -replace '^"|"$'
    [Environment]::SetEnvironmentVariable($k, $v, "User")
  }
}

#-------------------------------------------------------------------------------
# Zero Trust Information
#-------------------------------------------------------------------------------
Write-Host ""
if ($env:NETWORK_ISOLATION -and $env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Zero Trust enabled."
    Write-Host "🚧 NOTE: If app config failed, run the azd provision again - this is due to token timeout restrictions."
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
    Write-Host "⚠️  Missing required variables: $($missing -join ', '). Skipping configuration steps that depend on them." -ForegroundColor Yellow
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
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "`n📑 AI Foundry Setup..."
    try {
        Write-Host "🚀 Running config.aifoundry.setup..."
        & python -m config.aifoundry.setup
        Write-Host "✅ AI Foundry setup script finished."
    } catch {
        Write-Host "❗ Error during AI Foundry setup. Skipping it."
    }
} else {
    Write-Host "⏭️  Skipping AI Foundry setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# 2) Container Apps Setup
#-------------------------------------------------------------------------------
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "`n🔍 ContainerApp setup..."
    try {
        Write-Host "🚀 Running config.containerapps.setup..."
        & python -m config.containerapps.setup
        Write-Host "✅ Container Apps setup script finished."
    } catch {
        Write-Host "❗ Error during Container Apps setup. Skipping it."
    }
} else {
    Write-Host "⏭️  Skipping Container Apps setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# 3) AI Search Setup
#-------------------------------------------------------------------------------
if (-not $missing.Contains('APP_CONFIG_ENDPOINT')) {
    Write-Host "🔍 AI Search setup..."
    try {
        Write-Host "🚀 Running config.search.setup..."
        & python -m config.search.setup
        Write-Host "✅ Search setup script finished."
    } catch {
        Write-Host "❗ Error during Search setup. Skipping it."
    }
} else {
    Write-Host "⏭️  Skipping Search setup (missing APP_CONFIG_ENDPOINT)."
}

#-------------------------------------------------------------------------------
# Cleaning up
#-------------------------------------------------------------------------------
Write-Host "`n🧹 Cleaning Python environment up..."
if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
# Try to stop any python processes that reference the temporary venv to avoid file locks
$venvPattern = "config\\.venv_temp"
try {
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match $venvPattern) }
} catch {
    # Fallback if Get-CimInstance isn't available for some reason
    $procs = @()
}

if ($procs -and $procs.Count -gt 0) {
    Write-Host "Stopping processes referencing venv:"
    foreach ($p in $procs) {
        Write-Host "  Stopping pid $($p.ProcessId) - $($p.Name)"
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
    }
    Start-Sleep -Seconds 1
}

# Retry removal with exponential backoff to handle transient locks
$maxRetries = 5
for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        Remove-Item -Recurse -Force config/.venv_temp -ErrorAction Stop
        Write-Host "Removed venv directory."
        break
    } catch {
        if ($i -eq $maxRetries) {
            Write-Host "⚠️ Failed to remove venv after $maxRetries attempts: $($_.Exception.Message)"
        } else {
            Write-Host ("Retry {0}/{1}: waiting and retrying..." -f $i, $maxRetries)
            Start-Sleep -Seconds (2 * $i)
        }
    }
}

Write-Host "`n✅ postProvisioning completed."
