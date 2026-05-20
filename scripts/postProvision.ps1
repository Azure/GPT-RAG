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
Write-Host ""
if ($env:NETWORK_ISOLATION -and $env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Zero Trust enabled."
    Write-Host "Access to Azure resources is restricted to the VNet."
    Write-Host "Ensure you run scripts/postProvision.ps1 from within the VNet."
    Write-Host "If you are using a local machine, make sure you have a VPN connection to the VNet."
    Write-Host "You can also use the Test VM to access the environment and complete the setup."

    $runningFromJumpbox = $env:RUN_FROM_JUMPBOX -and $env:RUN_FROM_JUMPBOX.ToLower() -eq 'true'
    if (-not $runningFromJumpbox) {
        $answer = Read-Host "Are you running this script from inside the VNet or via VPN? [Y/n]"
        if ($answer.ToLower() -notmatch '^(y|yes)$') {
            Write-Host "❌ Please run this script from inside the VNet or with VPN access. Exiting."
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

#-------------------------------------------------------------------------------
# Setup Python environment
#-------------------------------------------------------------------------------
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:PYTHONPATH = if ($env:PYTHONPATH) { "$repoRoot;$($env:PYTHONPATH)" } else { $repoRoot }

Write-Host "🐍 Checking Python venv support..."
& python -c "import venv" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error @"
The selected Python interpreter does not support 'venv'.
Network-isolated post-provisioning requires a full Python installation with venv support.
If this is the AI Landing Zone jumpbox Python, track/fix the upstream jumpbox Python contract:
https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/67
"@
    exit 1
}

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
    Write-Host "🚀 Running config.aifoundry.setup..."
    & python -m config.aifoundry.setup
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
    & python -m config.containerapps.setup
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
    & python -m config.search.setup
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
