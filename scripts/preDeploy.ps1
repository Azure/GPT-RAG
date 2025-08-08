# Works from ...\gpt-rag or any subfolder
# PowerShell 7+ recommended
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
$ProgressPreference = 'SilentlyContinue'   # hide PS progress bars

if ($env:AZURE_ZERO_TRUST -eq "TRUE") {
  $c = Read-Host -Prompt "Zero Trust enabled. Confirm resources are reachable (VM+Bastion)? [Y/n]"
  if ($c -ne "Y" -and $c -ne "y" -and $c) { exit 0 }
}

function Docker-Ready {
  try {
    $null = & docker info 2>$null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

# Hard preflight: require Docker daemon
if (-not (Docker-Ready)) {
  Write-Host "Docker daemon is not running. Start Docker Desktop and try again"
  exit 11
}

function Find-RepoRoot([string]$start) {
  $p = (Resolve-Path $start).Path
  while ($true) {
    if ((Split-Path $p -Leaf) -ieq 'gpt-rag' -or (Test-Path (Join-Path $p 'infra\manifest.json'))) { return $p }
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

$manifestPath = Join-Path $repoRoot 'infra\manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Error "manifest.json not found at $manifestPath"; exit 1 }

$manifest   = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$baseDir    = Split-Path -Parent $repoRoot
$dotAzure   = Join-Path $repoRoot '.azure'
$globalEnv  = Get-AzdEnv -projectPath $repoRoot
$globalRG   = $globalEnv.AZURE_RESOURCE_GROUP
$globalSub  = $globalEnv.AZURE_SUBSCRIPTION_ID

# Global RG check once (fail early)
if (-not $globalRG) { Write-Error "AZURE_RESOURCE_GROUP not found in env."; exit 2 }
if (-not (ResourceGroup-Exists -rg $globalRG -subscription $globalSub)) {
  Write-Error "Resource group '$globalRG'$(if($globalSub){" in subscription '$globalSub'"}). not found."
  exit 3
}

$hadErrors = $false

foreach ($c in $manifest.components) {
  $name = $c.name
  $repo = $c.repo
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

  if (Test-Path -LiteralPath $target) { Remove-Item -Recurse -Force -LiteralPath $target }

  try {
    if ($refType -eq 'branch') {
      git clone --depth 1 --branch $ref --no-progress -q $repo $target 1>$null 2>$null
    } else {
      git clone --depth 1 --no-progress -q $repo $target 1>$null 2>$null
      git -C $target fetch --tags --force --depth 1 --no-progress -q origin $ref 1>$null 2>$null
      git -C $target -c advice.detachedHead=false checkout -q -f $ref 1>$null 2>$null
    }
    git config --global --add safe.directory ($target -replace '\\','/') 1>$null 2>$null
  }
  catch {
    Write-Error ("{0}: git operation failed. {1}" -f $name, $_.Exception.Message)
    $hadErrors = $true
    continue
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
