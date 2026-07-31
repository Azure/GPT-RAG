# Works from ...\gpt-rag or any subfolder
# PowerShell 7+ recommended
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
$ProgressPreference = 'SilentlyContinue'   # hide PS progress bars

function Docker-Ready {
  try {
    $null = & docker info 2>$null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

function Find-RepoRoot([string]$start) {
  $p = (Resolve-Path $start).Path
  while ($true) {
    if ((Split-Path $p -Leaf) -ieq 'gpt-rag' -or (Test-Path (Join-Path $p 'manifest.json'))) { return $p }
    $parent = Split-Path -Parent $p
    if ($parent -eq $p -or [string]::IsNullOrEmpty($parent)) { break }
    $p = $parent
  }
  return $null
}

function Tag-Exists([string]$repo, [string]$tag) {
  $o = git ls-remote --tags $repo $tag 2>$null
  return ($LASTEXITCODE -eq 0 -and $o)
}

function Branch-Exists([string]$repo, [string]$branch) {
  $o = git ls-remote --heads $repo $branch 2>$null
  return ($LASTEXITCODE -eq 0 -and $o)
}

function Parse-KeyValueLines([string[]]$lines) {
  $map = @{}
  foreach ($ln in $lines) {
    if ($ln -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      $k = $matches[1]; $v = $matches[2]
      $v = $v -replace '^\s*"(.*)"\s*$', '$1'
      $map[$k] = $v
    }
  }
  return $map
}

function Get-AzdEnv([string]$projectPath) {
  $vals = @{}
  if (Get-Command azd -ErrorAction SilentlyContinue) {
    try {
      Push-Location $projectPath
      $out = & azd env get-values 2>$null
      Pop-Location
      if ($LASTEXITCODE -eq 0 -and $out) { $vals = Parse-KeyValueLines $out }
    } catch { try { Pop-Location } catch {} }
  }
  if (-not $vals.ContainsKey('AZURE_RESOURCE_GROUP')) {
    $azDir = Join-Path $projectPath '.azure'
    if (Test-Path -LiteralPath $azDir) {
      $envDirs = Get-ChildItem -LiteralPath $azDir -Directory -ErrorAction SilentlyContinue
      foreach ($d in $envDirs) {
        $envFile = Join-Path $d.FullName '.env'
        if (Test-Path -LiteralPath $envFile) {
          $txt = Get-Content -LiteralPath $envFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
          $vals = Parse-KeyValueLines ($txt -split "`r?`n")
          break
        }
      }
    }
  }
  return [pscustomobject]$vals
}

function ResourceGroup-Exists([string]$rg, [string]$subscription) {
  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) not found; cannot verify resource group '$rg'."
    return $false
  }
  $args = @('group','exists','-n', $rg)
  if ($subscription) { $args += @('--subscription', $subscription) }
  $result = & az @args 2>$null
  return ($LASTEXITCODE -eq 0 -and ($result.Trim().ToLower() -eq 'true'))
}

# Prefer pwsh (PS7); fall back to Windows PowerShell only if pwsh is unavailable
$psExe = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction Stop).Source }

$start    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = Find-RepoRoot $start
if (-not $repoRoot) { Write-Error "Run this from inside a gpt-rag repo."; exit 1 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "Git not found in PATH."; exit 1 }

$manifestPath = Join-Path $repoRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Error "manifest.json not found at $manifestPath"; exit 1 }

$manifest   = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$baseDir    = Split-Path -Parent $repoRoot
$dotAzure   = Join-Path $repoRoot '.azure'
$globalEnv  = Get-AzdEnv -projectPath $repoRoot
$globalRG   = $globalEnv.AZURE_RESOURCE_GROUP
$globalSub  = $globalEnv.AZURE_SUBSCRIPTION_ID
$hostedMode = "$($globalEnv.DEPLOY_HOSTED_AGENT_ORCHESTRATION)".ToLowerInvariant() -match '^(1|true|t|yes|y)$'
$administrativePanel = $hostedMode -and ("$($globalEnv.DEPLOY_ADMINISTRATIVE_PANEL)".ToLowerInvariant() -match '^(1|true|t|yes|y)$')
$deploymentMode = if (-not $hostedMode) { 'classic' } elseif ($administrativePanel) { 'hosted-panel' } else { 'hosted-no-panel' }
$selectedComponents = if ($hostedMode) {
  @('gpt-rag-ui', 'gpt-rag-ingestion')
} else {
  @('gpt-rag-ui', 'gpt-rag-orchestrator', 'gpt-rag-ingestion')
}
Write-Host "GPT-RAG deployment mode: $deploymentMode" -ForegroundColor Cyan

# Make azd outputs available to component deploy scripts. In network-isolated
# deployments the jumpbox intentionally has no Docker, so components need
# ACR_TASK_AGENT_POOL/NETWORK_ISOLATION to select remote ACR builds.
foreach ($prop in $globalEnv.PSObject.Properties) {
  if ($null -ne $prop.Value -and "$($prop.Value)" -ne '') {
    Set-Item -Path "Env:$($prop.Name)" -Value "$($prop.Value)"
  }
}

$networkIsolation = "$($globalEnv.NETWORK_ISOLATION)".ToLowerInvariant() -eq 'true'
$runningFromJumpbox = "$($env:RUN_FROM_JUMPBOX)".ToLowerInvariant() -eq 'true'
if ($networkIsolation -and -not $runningFromJumpbox) {
  Write-Error "NETWORK_ISOLATION=true deployments must run from the jumpbox/VNet. Provision from the workstation, then run azd deploy from the jumpbox with RUN_FROM_JUMPBOX=true."
  exit 4
}

if (-not (Docker-Ready)) {
  if ($networkIsolation -or $globalEnv.ACR_TASK_AGENT_POOL) {
    Write-Host "Docker is not available; component deploys will use ACR remote builds." -ForegroundColor Yellow
  } else {
    Write-Host "Docker daemon is not running; component deploy scripts will fall back to ACR remote builds where supported." -ForegroundColor Yellow
  }
}

# Global RG check once (fail early)
if (-not $globalRG) { Write-Error "AZURE_RESOURCE_GROUP not found in env."; exit 2 }
if (-not (ResourceGroup-Exists -rg $globalRG -subscription $globalSub)) {
  Write-Error "Resource group '$globalRG'$(if($globalSub){" in subscription '$globalSub'"}). not found."
  exit 3
}

$hadErrors = $false

if ($hostedMode) {
  $hostedProject = Join-Path $repoRoot 'hosted-agent'
  if (-not (Test-Path -LiteralPath (Join-Path $hostedProject 'azure.yaml'))) {
    Write-Error "Hosted agent azd project not found at $hostedProject."
    exit 1
  }
  if (-not $globalEnv.HOSTED_AGENT_RESOURCE_SCOPE -or -not "$($globalEnv.HOSTED_AGENT_RESOURCE_SCOPE)".EndsWith('/.default')) {
    Write-Error "Hosted mode requires HOSTED_AGENT_RESOURCE_SCOPE as an explicit data-plane scope ending in '/.default'."
    exit 1
  }
  if (-not $globalEnv.AZURE_AI_PROJECT_ENDPOINT -or -not $globalEnv.AZURE_AI_PROJECT_RESOURCE_ID) {
    Write-Error "Hosted mode requires AZURE_AI_PROJECT_ENDPOINT and AZURE_AI_PROJECT_RESOURCE_ID from provisioning."
    exit 1
  }

  if (Test-Path -LiteralPath $dotAzure) {
    Copy-Item $dotAzure $hostedProject -Recurse -Force -Container
  }

  Push-Location $hostedProject
  try {
    & azd env set FOUNDRY_PROJECT_ENDPOINT "$($globalEnv.AZURE_AI_PROJECT_ENDPOINT)" --environment "$($globalEnv.AZURE_ENV_NAME)" --no-prompt | Out-Null
    & azd env set AZURE_AI_PROJECT_ID "$($globalEnv.AZURE_AI_PROJECT_RESOURCE_ID)" --environment "$($globalEnv.AZURE_ENV_NAME)" --no-prompt | Out-Null
    & azd deploy orchestrator-agent --environment "$($globalEnv.AZURE_ENV_NAME)" --no-prompt
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Hosted orchestrator deployment failed."
      exit $LASTEXITCODE
    }
    $hostedEnv = Get-AzdEnv -projectPath $hostedProject
  } finally {
    Pop-Location
  }

  $invocationsEndpoint = "$($hostedEnv.AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT)"
  if (-not $invocationsEndpoint) {
    Write-Error "Hosted deployment did not publish AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT."
    exit 1
  }
  Push-Location $repoRoot
  try {
    $hostedBaseUrlOutput = & python -m config.deployment.hosted --invocations-endpoint $invocationsEndpoint
    $hostedExitCode = $LASTEXITCODE
    $hostedBaseUrl = if ($hostedBaseUrlOutput) { "$hostedBaseUrlOutput".Trim() } else { '' }
    if ($hostedExitCode -ne 0 -or -not $hostedBaseUrl) {
      Write-Error "Hosted Invocations endpoint is not compatible with the UI endpoint contract."
      exit 1
    }
  } finally {
    Pop-Location
  }
  $env:HOSTED_AGENT_BASE_URL = $hostedBaseUrl
  $env:HOSTED_AGENT_RESOURCE_SCOPE = "$($globalEnv.HOSTED_AGENT_RESOURCE_SCOPE)"
  Push-Location $repoRoot
  try {
    & azd env set HOSTED_AGENT_BASE_URL $hostedBaseUrl --environment "$($globalEnv.AZURE_ENV_NAME)" --no-prompt | Out-Null
    & python -m config.deployment.appconfig --require-hosted-endpoint
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to publish the hosted-agent endpoint contract."
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

foreach ($c in $manifest.components) {
  $name = $c.name
  if ($name -notin $selectedComponents) {
    Write-Host "$name is not deployed in $deploymentMode mode." -ForegroundColor Yellow
    continue
  }
  $repo = $c.repo
  $expectedCommit = "$($c.commit)"
  $desiredTag    = if ($c.tag) { $c.tag } else { $manifest.release }
  $desiredBranch = $c.branch  # explicit branch only

  # Ref resolution (no implicit fallback)
  $refType = $null; $ref = $null
  if ($desiredTag) {
    if (Tag-Exists $repo $desiredTag) { $refType = 'tag'; $ref = $desiredTag }
    else { Write-Warning ("{0}: tag '{1}' not found. Skipping." -f $name, $desiredTag); continue }
  } elseif ($desiredBranch) {
    if (Branch-Exists $repo $desiredBranch) { $refType = 'branch'; $ref = $desiredBranch }
    else { Write-Warning ("{0}: branch '{1}' not found. Skipping." -f $name, $desiredBranch); continue }
  } else {
    Write-Warning ("{0}: neither tag nor branch specified. Skipping." -f $name); continue
  }

  # Target folder (sibling to gpt-rag)
  $target = Join-Path $baseDir $name
  Write-Host ("Deploying {0} ({1}:{2}) -> {3}" -f $name, $refType, $ref, $target) -ForegroundColor Cyan

  if (Test-Path -LiteralPath $target) {
    Write-Host ("  ℹ️  '{0}' already exists at {1}, verifying pin." -f $name, $target) -ForegroundColor Yellow
  } else {
    try {
      if ($refType -eq 'branch') {
        git clone --depth 1 --branch $ref --no-progress -q $repo $target 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
          throw "$name`: git clone failed."
        }
      } else {
        git clone --depth 1 --no-progress -q $repo $target 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
          throw "$name`: git clone failed."
        }
        git -C $target fetch --tags --force --depth 1 --no-progress -q origin $ref 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
          throw "$name`: git fetch for tag $ref failed."
        }
        git -C $target -c advice.detachedHead=false checkout -q -f $ref 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
          throw "$name`: git checkout for tag $ref failed."
        }
      }
      git config --global --add safe.directory ($target -replace '\\','/') 1>$null 2>$null
    }
    catch {
      Write-Error ("{0}: git operation failed. {1}" -f $name, $_.Exception.Message)
      $hadErrors = $true
      continue
    }
  }

  if ($expectedCommit) {
    $actualCommitOutput = & git -C $target rev-parse HEAD 2>$null
    $revParseExitCode = $LASTEXITCODE
    $actualCommit = if ($actualCommitOutput) { "$actualCommitOutput".Trim() } else { '' }
    if ($revParseExitCode -ne 0 -or $actualCommit -ne $expectedCommit) {
      Write-Error "$name must resolve to $expectedCommit but $target is at $actualCommit. Remove or relocate the stale sibling checkout."
      $hadErrors = $true
      continue
    }
  }

  # Copy shared azd env into the freshly cloned project
  if (Test-Path -LiteralPath $dotAzure) {
    Copy-Item $dotAzure $target -Recurse -Force -Container
  }

  # Run child deploy.ps1 from the component ROOT so 'docker build .' sees the Dockerfile there
  $deployPs = Join-Path $target 'scripts\deploy.ps1'
  if (Test-Path -LiteralPath $deployPs) {
    $logDir = Join-Path $target '.logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $log = Join-Path $logDir ("deploy_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

    Write-Host ("Running child deploy in {0}: scripts\deploy.ps1 -> {1}" -f $target, (Split-Path $log -Leaf))
    try {
      Push-Location $target
      $null = (& $psExe -NoProfile -ExecutionPolicy Bypass -File "scripts\deploy.ps1" 2>&1 | Tee-Object -FilePath $log)
      $exit = $LASTEXITCODE
      Pop-Location
      if ($exit -ne 0) {
        Write-Error ("{0}: deploy script failed with exit code {1}. See log: {2}" -f $name, $exit, $log)
        $hadErrors = $true
      } else {
        Write-Host ("{0}: deploy script finished. Log: {1}" -f $name, $log) -ForegroundColor Green
      }
    }
    catch {
      try { Pop-Location } catch {}
      Write-Error ("{0}: error launching deploy script. {1} (log: {2})" -f $name, $_.Exception.Message, $log)
      $hadErrors = $true
    }
  } else {
    Write-Host ("{0}: no scripts\deploy.ps1 found, skipping child deploy." -f $name)
  }
}

if ($hadErrors) { Write-Error "One or more components failed. See logs above."; exit 1 }

Write-Host "All components processed." -ForegroundColor Green
