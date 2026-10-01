<#
    Jumpbox Setup Script – Updated for Custom Script Extension (CSE)

    Fixes included:
      • Correct AZD installation path
      • Guaranteed azd execution via absolute path
      • PATH not loading inside CSE session
      • Adds azd folder to PATH for current session and machine level
      • Uses & "C:\Program Files\Azure Dev CLI\azd.exe" for all azd commands
      • Repo clone/checkout stability improvements
#>

Param (
  [Parameter(Mandatory = $true)]
  [string] $release,

  [string] $azureTenantID,
  [string] $azureSubscriptionID,
  [string] $AzureResourceGroupName,
  [string] $azureLocation,
  [string] $AzdEnvName,
  [string] $resourceToken,
  [string] $useUAI,

  # Optional: additional Git repositories to clone into C:\github\ on the
  # jumpbox. Useful for downstream solution accelerators that consume this
  # landing zone as a Bicep module / git submodule and need their own app
  # repository present on the VM for post-provisioning data-plane scripts.
  # Pass as comma-separated strings (CSE command-line friendly):
  #   -ExtraRepoUrls  "https://github.com/org/repo-a.git,https://github.com/org/repo-b.git"
  #   -ExtraRepoTags  "v1.0.0,main"
  #   -ExtraRepoNames "repo-a,repo-b"
  # Tags default to "main"; names default to the repo URL basename.
  [string] $ExtraRepoUrls  = '',
  [string] $ExtraRepoTags  = '',
  [string] $ExtraRepoNames = ''
)

Start-Transcript -Path C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = "tls12"

Write-Host "`n==================== PARAMETERS ====================" -ForegroundColor Cyan
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    $name = $_.Key
    $value = if ([string]::IsNullOrWhiteSpace($_.Value)) { "<empty>" } else { $_.Value }
    Write-Host ("{0,-25}: {1}" -f $name, $value)
}
Write-Host "====================================================`n" -ForegroundColor Cyan


# ---------------------------------------------------------------------------
# Wall-clock budget (issue #82 — VMExtensionProvisioningTimeout)
# ---------------------------------------------------------------------------
# A Windows CustomScriptExtension has a FIXED 90-minute platform provisioning
# timeout (`VMExtensionProvisioningTimeout`) that the script cannot extend. If
# the bootstrap is still running at minute 90, ARM fails the extension with
# "the extension did not report a message" — even though every other resource
# provisioned successfully. Under Zero Trust all egress traverses the Azure
# Firewall, so package feeds / external downloads can be slow or transiently
# blocked, and the cumulative wall time of the (previously unbounded) installs
# and clones could exceed 90 minutes.
#
# To stay deterministically inside the window we:
#   * cap every network operation (choco --execution-timeout, -TimeoutSec on
#     Invoke-WebRequest, process-tree watchdog on az/azd, bounded git clones);
#   * track an overall wall-clock budget and SKIP optional steps (Python,
#     win-acme, component/extra repos) when the remaining budget is low; and
#   * keep CORE steps fatal so CSE only reports success when the jumpbox is
#     actually usable (Chocolatey + git/az/azd + main repo clone + azd auth/init).
$script:CseStartTime    = Get-Date
$script:CseWallBudgetSec = 4500   # 75 min of work; leaves headroom before the 90 min platform cap

function Get-RemainingBudgetSec {
    [int]($script:CseWallBudgetSec - ((Get-Date) - $script:CseStartTime).TotalSeconds)
}
function Test-BudgetAtLeast {
    param([Parameter(Mandatory = $true)][int]$Seconds)
    (Get-RemainingBudgetSec) -ge $Seconds
}

# Run a native executable with a hard wall-clock cap. Unlike Start-Job this
# keeps the child in the SAME identity (LocalSystem) and process environment,
# so az/azd auth caches written under the system profile remain visible to
# later steps. On timeout the entire process tree is killed (taskkill /T) so a
# hung azd/az download cannot keep CSE in `Transitioning` past the 90 min cap.
# Returns the process exit code (124 == timeout, 127 == failed to start).
function Invoke-NativeWithTimeout {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments        = @(),
        [int]$TimeoutSec            = 600,
        [string]$WorkingDirectory   = (Get-Location).Path,
        [string]$Label              = ''
    )
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = Split-Path $FilePath -Leaf }
    $stem    = ($Label -replace '\W', '_')
    $outFile = Join-Path $env:TEMP ("nwt_{0}_{1}.out" -f $stem, [guid]::NewGuid().ToString('N'))
    $errFile = "$outFile.err"
    Write-Host "[exec] $Label (timeout=${TimeoutSec}s): $FilePath $($Arguments -join ' ')"
    try {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
            -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        # PS 5.1: Start-Process -PassThru leaves $proc.ExitCode $null unless the
        # process Handle is cached BEFORE the process exits. Without this the CORE
        # callers (which throw on a non-zero exit) would treat every SUCCESSFUL run
        # as a fatal failure and abort the CSE (issue #82 regression). Touch .Handle
        # to force the runtime to retain it so .ExitCode populates after exit.
        $null = $proc.Handle
    } catch {
        Write-Warning "[exec] $Label failed to start: $_"
        return 127
    }
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Warning "[exec] $Label exceeded ${TimeoutSec}s wall clock; terminating process tree (PID $($proc.Id))."
        & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        $exit = 124
    } else {
        $exit = $proc.ExitCode
    }
    foreach ($f in @($outFile, $errFile)) {
        if (Test-Path $f) {
            $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($content)) { Write-Host $content }
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }
    return $exit
}


# ------------------------------
# Install Chocolatey (CORE — fatal on failure: every package below depends on it)
# ------------------------------
# The bootstrap download + install is bounded so a stalled feed through the
# firewall cannot hang CSE indefinitely (issue #82). The official install.ps1
# is fetched to a temp file with a connection timeout, then executed under a
# process-tree watchdog.
Set-ExecutionPolicy Bypass -Scope Process -Force
$chocoBootstrap = Join-Path $env:TEMP 'choco-install.ps1'
try {
    Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $chocoBootstrap -UseBasicParsing -TimeoutSec 120
    $chocoBootstrapExit = Invoke-NativeWithTimeout -FilePath 'powershell.exe' `
        -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $chocoBootstrap) `
        -TimeoutSec 600 -Label 'choco-bootstrap'
    Remove-Item $chocoBootstrap -Force -ErrorAction SilentlyContinue
    if ($chocoBootstrapExit -ne 0) {
        throw "Chocolatey bootstrap exited with code $chocoBootstrapExit"
    }
} catch {
    throw "FATAL: Chocolatey installation failed: $_. Cannot continue jumpbox bootstrap."
}

$env:Path += ";C:\ProgramData\chocolatey\bin"


# ------------------------------
# Install tooling (sequential — see issues #24, #30, #31)
# ------------------------------
# History:
#   * #24 (v1.1.1) parallelized the six choco installs via Start-Job to cut
#     CSE wall time. Worked but introduced two race classes:
#   * #30 (v1.1.3) — Windows Installer machine-wide mutex (`Global\_MSIExecute`)
#     contention on parallel MSI-backed packages → exit 1618 on losers.
#     Mitigated with Invoke-ChocoWithRetry (kept below).
#   * #31 (v1.1.3 amend) — *internal* Chocolatey file-lock race on
#     `C:\ProgramData\chocolatey\lib\chocolatey-compatibility.extension\.chocolateyPending`
#     (and similarly `chocolatey-core.extension`) when two jobs concurrently
#     auto-pull the same dependency package. This race surfaces as
#     ``Access to the path '...\.chocolateyPending' is denied.`` with choco
#     exiting 1 — NOT 1618 — so the retry helper bypasses it and the affected
#     package (e.g. powershell-core) is silently dropped.
#
# Fix (#31): stop parallelizing choco. Chocolatey is not designed for
# concurrent invocations on the same machine. We run the six installs in a
# sequential foreach loop, still through Invoke-ChocoWithRetry so genuine MSI
# 1618 contention from unrelated installers (e.g. Azure Update Manager)
# remains handled. The wall-time cost vs parallel is ~30–60 s, dominated
# anyway by Defender, antimalware, AZD-MSI download, and the post-CSE reboot.
#
# Implementation notes:
#   * AZD is installed via `choco install azd` instead of `aka.ms/install-azd.ps1`
#     so it goes through the same retry path. The path-discovery block below
#     still searches the legacy MSI locations as a fallback in case the
#     chocolatey package layout changes.
#   * Notepad++ was dropped — not used by any downstream automation.
#   * Quiet flags (`--no-progress --limitoutput --no-color`) cut log/console
#     overhead. `--ignoredetectedreboot --force` preserves existing behavior
#     (the script ends with a delayed reboot, see bottom of file).
#   * `--execution-timeout=600` caps each package at 10 minutes (issue #82).
#     Chocolatey's DEFAULT execution timeout is 2700s (45 min) PER package, so
#     five packages could otherwise consume up to ~225 minutes and blow past
#     the fixed 90-minute CSE platform timeout on their own. 600s is generous
#     for every package here (the largest, the Azure CLI MSI, installs well
#     inside it even on a cold network) while keeping the worst case bounded.
$chocoArgs = @('-y','--ignoredetectedreboot','--force','--no-progress','--limitoutput','--no-color','--execution-timeout=600')

# Retry helper kept for genuine MSI 1618 contention (e.g. another concurrent
# installer on the host such as Azure Update Manager). It does NOT retry on
# Chocolatey-internal file-lock failures (#31), which were the parallelization
# race; those cannot occur once we serialize.
#
# Criticality (issue #82): the helper previously swallowed every non-1618
# failure as a warning, so a failed/timed-out CORE tool (git, az, azd) let the
# script march on and "succeed" with a half-configured jumpbox. CORE packages
# now `throw` after the retry policy is exhausted; OPTIONAL packages (editors)
# stay non-fatal. An `--execution-timeout` hit surfaces as a non-1618 non-zero
# exit (and/or timeout text), which is treated as a terminal failure — not as
# MSI contention — so it is not retried into the 90-minute wall.
function Invoke-ChocoWithRetry {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('install','upgrade')][string]$Action,
        [Parameter(Mandatory=$true)][string]$Package,
        [Parameter(Mandatory=$true)][string[]]$ExtraArgs,
        [bool]$Critical = $false
    )
    $maxAttempts = 8
    $delay = 15
    for ($i = 1; $i -le $maxAttempts; $i++) {
        $output = & choco $Action $Package @ExtraArgs 2>&1 | Out-String
        $exit = $LASTEXITCODE
        Write-Output $output
        if ($exit -eq 0) {
            if ($i -gt 1) {
                Write-Output "[$Package] choco $Action succeeded on attempt $i/$maxAttempts after MSI lock contention."
            }
            return
        }
        $isMsiLockContention = ($output -match '\b1618\b') -or ($output -match 'Another installation currently in progress')
        if ($isMsiLockContention -and $i -lt $maxAttempts) {
            Write-Output "[$Package] MSI lock contention (exit=$exit, code 1618) on attempt $i/$maxAttempts; backing off ${delay}s..."
            Start-Sleep -Seconds $delay
            $delay = [Math]::Min($delay * 2, 120)
            continue
        }
        $isTimeout = ($output -match '(?i)execution[ -]?timeout') -or ($output -match '(?i)did not complete within')
        if ($isMsiLockContention) {
            $msg = "[$Package] choco $Action exhausted $maxAttempts retries due to persistent MSI lock contention (exit=$exit)."
        } elseif ($isTimeout) {
            $msg = "[$Package] choco $Action exceeded the per-package execution timeout (exit=$exit)."
        } else {
            $msg = "[$Package] choco $Action failed with exit=$exit (non-1618); not retrying."
        }
        if ($Critical) {
            throw "FATAL: $msg This is a core tool required for the jumpbox bootstrap."
        }
        Write-Warning "$msg Package is optional; continuing."
        return
    }
}

# Critical = $true ⇒ a terminal failure aborts the CSE (the jumpbox is unusable
# without it). Optional editors/shells (vscode, powershell-core) only warn.
$packages = @(
    @{ Name = 'vscode';          Action = 'upgrade'; Critical = $false }
    @{ Name = 'azure-cli';       Action = 'install'; Critical = $true  }
    @{ Name = 'git';             Action = 'upgrade'; Critical = $true  }
    @{ Name = 'powershell-core'; Action = 'install'; Critical = $false }
    @{ Name = 'azd';             Action = 'install'; Critical = $true  }
)

Write-Host "Starting sequential choco installs with MSI-retry hardening..."
foreach ($p in $packages) {
    Write-Host "`n--- choco $($p.Action) $($p.Name) ---"
    Invoke-ChocoWithRetry -Action $p.Action -Package $p.Name -ExtraArgs $chocoArgs -Critical:$p.Critical
}
Write-Host "Sequential choco installs finished. Budget remaining: $(Get-RemainingBudgetSec)s"

# ---------------------------------------------------------------------------
# Python 3.11 — installed from the official embeddable distribution rather
# than the Chocolatey `python311` package. The MSI behind the choco package
# silently produces a broken interpreter on this image (only `python.exe` and
# `pythonw.exe` end up under C:\Python311, while `Lib\encodings`,
# `python311.dll`, and the standard library are missing — `python --version`
# then fails with `Fatal Python error: init_fs_encoding: failed to get the
# Python codec of the filesystem encoding`, and reinstalling via the same MSI
# returns exit 1603 because the broken install is still registered with no
# clean uninstall path). See issue #48.
#
# The embeddable zip is hermetic (no MSI state, no installer, just unzip),
# always ships the full standard library + `python311.dll`, and is bit-for-
# bit reproducible across reboots. We then enable site-packages by patching
# `python311._pth` (uncomment `import site`) so `pip install` writes into
# `Lib\site-packages` like a normal installation, and bootstrap pip via the
# official `get-pip.py`. After that, `python` and `pip` work end-to-end for
# consumer postProvision / data-seed scripts that depend on
# `azure-cosmos`, `azure-search-documents`, `azure-identity`, etc.
# ---------------------------------------------------------------------------
$pythonVersion   = '3.11.9'
$pythonRoot      = 'C:\Python311'
$pythonZipUrl    = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
$pythonZipPath   = Join-Path $env:TEMP 'python-embed.zip'
$getPipUrl       = 'https://bootstrap.pypa.io/get-pip.py'
$getPipPath      = Join-Path $env:TEMP 'get-pip.py'
$pythonExe       = Join-Path $pythonRoot 'python.exe'
$pythonPthFile   = Join-Path $pythonRoot 'python311._pth'
$pythonScriptDir = Join-Path $pythonRoot 'Scripts'

Write-Host "`n--- Installing Python $pythonVersion (embeddable distribution) ---"

# Python is OPTIONAL for CSE success (only consumer postProvision/data-seed
# scripts need it). Skip it when the wall-clock budget is low so it cannot push
# the extension past the 90-minute platform timeout (issue #82).
if (-not (Test-BudgetAtLeast 240)) {
    Write-Warning "Skipping Python install - only $(Get-RemainingBudgetSec)s of CSE budget left. Install it manually on the jumpbox if a consumer script requires it."
} else {
try {
    if (Test-Path $pythonRoot) {
        Write-Host "Removing pre-existing $pythonRoot to guarantee a clean install"
        Remove-Item -Path $pythonRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $pythonRoot -Force | Out-Null

    Write-Host "Downloading $pythonZipUrl"
    Invoke-WebRequest -Uri $pythonZipUrl -OutFile $pythonZipPath -UseBasicParsing -TimeoutSec 300
    Write-Host "Extracting to $pythonRoot"
    Expand-Archive -Path $pythonZipPath -DestinationPath $pythonRoot -Force
    Remove-Item $pythonZipPath -Force -ErrorAction SilentlyContinue

    # The embeddable distribution disables `site` and ships a `_pth` file that
    # short-circuits sys.path discovery. Uncomment `import site` so pip-
    # installed packages under `Lib\site-packages` are importable, and so
    # tools that probe `site.getsitepackages()` work as expected.
    if (Test-Path $pythonPthFile) {
        $pthLines = Get-Content $pythonPthFile
        $pthLines = $pthLines | ForEach-Object {
            if ($_ -match '^\s*#\s*import\s+site\s*$') { 'import site' } else { $_ }
        }
        if (-not ($pthLines -contains 'import site')) {
            $pthLines += 'import site'
        }
        Set-Content -Path $pythonPthFile -Value $pthLines -Encoding ASCII
        Write-Host "Patched $pythonPthFile to enable site-packages"
    } else {
        Write-Warning "Expected $pythonPthFile not present after extraction"
    }

    Write-Host "Verifying interpreter integrity"
    & $pythonExe --version
    if ($LASTEXITCODE -ne 0) {
        throw "python.exe --version failed (exit=$LASTEXITCODE) immediately after extraction"
    }

    Write-Host "Bootstrapping pip via $getPipUrl"
    Invoke-WebRequest -Uri $getPipUrl -OutFile $getPipPath -UseBasicParsing -TimeoutSec 180
    & $pythonExe $getPipPath --no-warn-script-location
    if ($LASTEXITCODE -ne 0) {
        throw "get-pip.py failed (exit=$LASTEXITCODE)"
    }
    Remove-Item $getPipPath -Force -ErrorAction SilentlyContinue

    foreach ($dir in @($pythonRoot, $pythonScriptDir)) {
        try {
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            if ($machinePath -notlike "*$dir*") {
                [Environment]::SetEnvironmentVariable('Path', "$machinePath;$dir", 'Machine')
                Write-Host "Added $dir to MACHINE Path"
            }
        } catch {
            Write-Warning "Failed to update MACHINE Path with ${dir}: $_"
        }
    }

    # Make python/pip resolvable for the rest of this CSE run without waiting
    # for the post-CSE reboot.
    $env:PATH = "$pythonRoot;$pythonScriptDir;$env:PATH"

    Write-Host "Python $pythonVersion install verified at $pythonExe" -ForegroundColor Green
} catch {
    Write-Warning "Python install failed: $_. Consumer postProvision scripts that require Python on the jumpbox may need to install it manually."
}
}

# ---------------------------------------------------------------------------
# win-acme (ACME client) — default jumpbox installation for provider-agnostic
# certificate workflows under network isolation (issue #53).
#
# Why built-in:
# - Workstation path handles DNS provider updates (TXT / A records).
# - Jumpbox path handles issuance + Azure-side import from inside the VNet.
# - Avoids winget dependency (unreliable on this VM image/CSE context).
#
# Behavior:
# - Non-interactive and deterministic: re-installs a pinned x64 trimmed zip
#   on each run so state does not drift and CSE does not depend on GitHub API
#   release discovery/rate limits.
# - OPTIONAL for CSE success (issue #82): win-acme is a certificate convenience
#   tool, not a dependency of any other resource. It is therefore staged into a
#   temp directory first and only swapped into C:\tools\win-acme after a
#   successful download + extract + version check, so a failed/slow download
#   neither destroys a previously working install nor fails the whole CSE past
#   the 90-minute platform timeout. Failures are logged loudly and skipped; the
#   operator can re-run the certificate runbook or install win-acme manually.
# - Skipped entirely when the wall-clock budget is low.
# ---------------------------------------------------------------------------
$wacsDir             = 'C:\tools\win-acme'
$wacsExe             = Join-Path $wacsDir 'wacs.exe'
$winAcmeVersion      = '2.2.9.1701'
$winAcmeAssetName    = "win-acme.v$winAcmeVersion.x64.trimmed.zip"
$winAcmeDownloadUrl  = "https://github.com/win-acme/win-acme/releases/download/v$winAcmeVersion/$winAcmeAssetName"

Write-Host "`n--- Installing win-acme (ACME client) ---"
if (-not (Test-BudgetAtLeast 180)) {
    Write-Warning "Skipping win-acme install - only $(Get-RemainingBudgetSec)s of CSE budget left. Run the certificate runbook later or install win-acme manually from the jumpbox."
} else {
    $wacsStaging = Join-Path $env:TEMP ("win-acme-staging-{0}" -f [guid]::NewGuid().ToString('N'))
    $wacsZip     = Join-Path $env:TEMP $winAcmeAssetName
    try {
        if (Test-Path $wacsStaging) { Remove-Item $wacsStaging -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $wacsStaging -Force | Out-Null

        Write-Host "Downloading $winAcmeAssetName"
        Invoke-WebRequest -Uri $winAcmeDownloadUrl -OutFile $wacsZip -UseBasicParsing -TimeoutSec 180

        Write-Host "Extracting $winAcmeAssetName to staging"
        Expand-Archive -Path $wacsZip -DestinationPath $wacsStaging -Force
        Remove-Item -Path $wacsZip -Force -ErrorAction SilentlyContinue

        $stagedExe = Join-Path $wacsStaging 'wacs.exe'
        if (-not (Test-Path $stagedExe)) {
            throw "win-acme staging failed: expected executable not found at $stagedExe"
        }
        & $stagedExe --version
        if ($LASTEXITCODE -ne 0) {
            throw "win-acme version check failed (exit=$LASTEXITCODE)"
        }

        # Only now that the new build is verified do we replace the live dir.
        if (Test-Path $wacsDir) {
            Remove-Item -Path $wacsDir -Recurse -Force -ErrorAction Stop
        }
        New-Item -ItemType Directory -Path (Split-Path $wacsDir -Parent) -Force | Out-Null
        Move-Item -Path $wacsStaging -Destination $wacsDir -Force

        Write-Host "win-acme successfully installed at $wacsExe" -ForegroundColor Green
    } catch {
        Write-Error "win-acme installation failed (non-fatal): $_. Any previously installed win-acme at $wacsDir is left intact. Install it manually before running the certificate workflow."
        Remove-Item $wacsStaging -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $wacsZip -Force -ErrorAction SilentlyContinue
    }
}

# Refresh PATH for the rest of this CSE run so the tools above are resolvable
# without waiting for the post-CSE reboot.
$env:PATH = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;C:\ProgramData\chocolatey\bin;$env:PATH"

Write-Host "Searching for installed AZD executable..."

$possibleAzdLocations = @(
    "C:\ProgramData\chocolatey\bin\azd.exe",
    "C:\ProgramData\chocolatey\lib\azd\tools\azd.exe",
    "C:\Program Files\Azure Dev CLI\azd.exe",
    "C:\Program Files (x86)\Azure Dev CLI\azd.exe",
    "C:\ProgramData\azd\bin\azd.exe",
    "C:\Windows\System32\azd.exe",
    "C:\Windows\azd.exe",
    "C:\Users\testvmuser\.azure-dev\bin\azd.exe",
    "$env:LOCALAPPDATA\Programs\Azure Dev CLI\azd.exe",
    "$env:LOCALAPPDATA\Azure Dev CLI\azd.exe"
)

$azdExe = $null

foreach ($path in $possibleAzdLocations) {
    if (Test-Path $path) {
        $azdExe = $path
        break
    }
}

if (-not $azdExe) {
    Write-Host "ERROR: azd.exe not found after installation. Installation path changed or MSI failed." -ForegroundColor Red
    Write-Host "Dumping filesystem search for troubleshooting..."
    Get-ChildItem -Path "C:\" -Recurse -Filter "azd.exe" -ErrorAction SilentlyContinue | Select-Object FullName
    exit 1
} else {
    Write-Host "AZD successfully located at: $azdExe" -ForegroundColor Green
}

# Add to PATH for immediate use
$env:PATH = "$(Split-Path $azdExe);$env:PATH"
Write-Host "Updated PATH for this session: $env:PATH"

$azdDir = Split-Path $azdExe

try {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$azdDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$azdDir", "Machine")
        Write-Host "Added $azdDir to MACHINE Path"
    } else {
        Write-Host "AZD directory already present in MACHINE Path"
    }
} catch {
    Write-Host "Failed to update MACHINE Path: $_" -ForegroundColor Yellow
}

try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -and $userPath -notlike "*$azdDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$azdDir", "User")
        Write-Host "Added $azdDir to USER Path"
    } elseif (-not $userPath) {
        [Environment]::SetEnvironmentVariable("Path", $azdDir, "User")
        Write-Host "Initialized USER Path with AZD directory"
    } else {
        Write-Host "AZD directory already present in USER Path"
    }
} catch {
    Write-Host "Failed to update USER Path: $_" -ForegroundColor Yellow
}


# ------------------------------
# Docker intentionally NOT installed on this jumpbox.
#
# Rationale (see issue #14 — ACR Task agent pool for NI image builds):
#   - Windows Server's Moby engine cannot run privileged Linux containers required
#     by BuildKit, so `docker buildx` against linux/amd64 images never worked here.
#   - Docker Desktop is not supported on Windows Server and requires a paid Docker
#     Subscription above ~250 employees / ~$10M revenue.
#   - Image builds now run in the ACR Tasks agent pool deployed alongside ACR
#     (Bicep param: deployAcrTaskAgentPool). See the ACR_TASK_AGENT_POOL azd output.
#
# To build and push images from this jumpbox (or any client with ARM egress):
#   az acr build -r <acr> --agent-pool <ACR_TASK_AGENT_POOL> -t myapp:latest -f Dockerfile .
#
# To pause billing between builds:
#   az acr agentpool update -r <acr> -n <ACR_TASK_AGENT_POOL> --count 0
# ------------------------------
Write-Host "`n==================== IMAGE BUILD GUIDANCE ====================" -ForegroundColor Cyan
Write-Host "Docker is NOT installed on this jumpbox by design."
Write-Host "Use ACR Tasks agent pool for image builds:"
Write-Host "  az acr build -r <acr> --agent-pool <pool-name> -t myapp:latest -f Dockerfile ."
Write-Host "==============================================================`n" -ForegroundColor Cyan


# ------------------------------
# Clone Bicep PTN AIML Landing Zone repo
# ------------------------------
# All `git clone` invocations in this script run via Invoke-GitCloneWithTimeout
# (defined below) — see issues #32 and #33. A plain `git clone` over HTTPS has
# no upper bound on idle/zombie connections, and the Azure VM Guest Agent
# serializes every Run-Command behind the active CSE. So a single hanging
# clone can keep CSE in `Transitioning` for hours and freeze the entire VM
# operation queue (including operator remediation via `az vm run-command
# invoke`). The helper wraps each clone in a `Start-Job` with a hard wall
# clock cap, after which the job is forcibly stopped.
#
# The `Start-Job` child has no TTY, so Git Credential Manager can stall on
# discovery prompts that never resolve (#33 Bug A). We therefore force
# `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never`, and pass
# `-c credential.helper=` on the `git` command line to disable GCM for this
# one-shot invocation. (The earlier `GIT_CONFIG_COUNT/KEY_0/VALUE_0` env-var
# protocol approach was non-functional on Windows — PowerShell's
# `$env:VAR = ''` *deletes* the variable rather than setting it empty, so git
# aborted with `missing config value GIT_CONFIG_VALUE_0` before any network
# I/O — see #34.) Cold-start TLS on freshly booted NI VMs (Defender +post-choco) can take >60 s to complete the first
# byte, so `GIT_HTTP_LOW_SPEED_TIME` is loosened to 180 s and the wall clock
# to 900 s (#33 Bug B). The real `git` exit code is captured via a sentinel
# line in the job's output stream, with a `.git` directory existence
# fallback, so genuine non-zero exits are not silently swallowed (#33 Bug C).
# One automatic retry with a 15 s back-off covers single transient failures
# without becoming an infinite retry loop.
function Invoke-GitCloneWithTimeout {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Tag,
        [Parameter(Mandatory=$true)][string]$Destination,
        [int]$TimeoutSec       = 900,
        [int]$LowSpeedTimeSec  = 180,
        [int]$LowSpeedLimitBps = 1000,
        [int]$MaxAttempts      = 2
    )
    $gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    if (-not $gitExe) {
        $gitExe = 'C:\Program Files\Git\cmd\git.exe'
    }
    if (-not (Test-Path $gitExe)) {
        throw "FATAL: git.exe was not found. Expected Chocolatey Git at '$gitExe'."
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-Host "[clone] attempt ${attempt}/${MaxAttempts}: $Url (tag=$Tag) -> $Destination (timeout=${TimeoutSec}s)"
        if (Test-Path $Destination) {
            Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
        }

        $job = Start-Job -ScriptBlock {
            param($git, $u, $t, $d, $lim, $tsec)
            # No TTY in Start-Job: silence any chance of an interactive prompt.
            $env:GIT_TERMINAL_PROMPT      = '0'
            $env:GCM_INTERACTIVE          = 'Never'
            # Abort only on truly stuck transfers, not on cold TLS startup.
            $env:GIT_HTTP_LOW_SPEED_LIMIT = "$lim"
            $env:GIT_HTTP_LOW_SPEED_TIME  = "$tsec"
            # Disable Git Credential Manager for this public-clone path via
            # `-c credential.helper=` (one-shot empty value for this invocation
            # only). The previous GIT_CONFIG_* env-var protocol approach (#33)
            # was non-functional on Windows because PowerShell's `$env:VAR = ''`
            # *deletes* the variable instead of setting it to empty, so git
            # aborted with `missing config value GIT_CONFIG_VALUE_0` before any
            # network I/O. The `-c` flag avoids that footgun entirely (#34).
            $gitOutput = & $git -c credential.helper= clone -b $t --depth 1 --no-tags $u $d 2>&1 | ForEach-Object { $_.ToString() }
            $gitExit = $LASTEXITCODE
            $gitOutput | ForEach-Object { Write-Output $_ }
            "__GIT_EXIT__:$gitExit"   # surface the real exit code
        } -ArgumentList $gitExe, $Url, $Tag, $Destination, $LowSpeedLimitBps, $LowSpeedTimeSec

        $finished = Wait-Job $job -Timeout $TimeoutSec
        if (-not $finished) {
            Write-Warning "[clone] wall-clock timeout (${TimeoutSec}s) on attempt $attempt"
            Stop-Job  $job -ErrorAction SilentlyContinue
            Receive-Job $job -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_ }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            $exit = 124  # convention: 124 == timeout
        }
        else {
            $output = Receive-Job $job
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            $output | ForEach-Object { Write-Output $_ }
            $marker = $output | Where-Object { $_ -match '^__GIT_EXIT__:(\-?\d+)$' } | Select-Object -Last 1
            if ($marker -and $marker -match '^__GIT_EXIT__:(\-?\d+)$') {
                $exit = [int]$Matches[1]
            }
            elseif (Test-Path (Join-Path $Destination '.git')) {
                $exit = 0
            }
            else {
                $exit = 1
            }
        }

        if ($exit -eq 0) {
            $script:LASTEXITCODE = 0
            return
        }
        Write-Warning "[clone] attempt $attempt failed (exit=$exit)"
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds 15 }
        else { $script:LASTEXITCODE = $exit; return }
    }
}

write-host "Cloning Bicep PTN AIML Landing Zone repo"
mkdir C:\github -ea SilentlyContinue
cd C:\github
Invoke-GitCloneWithTimeout -Url 'https://github.com/azure/bicep-ptn-aiml-landing-zone' -Tag $release -Destination 'C:\github\ai-lz'
if ($LASTEXITCODE -ne 0) {
    throw "Failed to clone Bicep PTN AIML Landing Zone repo (release=$release, exit=$LASTEXITCODE). Cannot continue jumpbox bootstrap."
}


# ------------------------------
# Azure Login (CORE)
# ------------------------------
# `az login --identity` and `azd auth login --managed-identity` authenticate
# against IMDS (169.254.169.254) rather than through the firewall, but `azd`'s
# auth/init can still reach out to the network (e.g. azd downloads the Bicep
# CLI from downloads.bicep.azure.com on first run), so the azd calls run under
# the process-tree watchdog to keep them bounded (issue #82). They run as the
# same LocalSystem identity, so the auth cache written under the system profile
# stays visible to the later `azd env set` calls.
write-host "Logging into Azure"
az login --identity

# CSE is non-interactive. azd first-run tooling discovery prompts otherwise
# block `azd init` until the watchdog kills it.
$env:AZD_SKIP_FIRST_RUN = 'true'

write-host "Logging into AZD"
$azdAuthExit = Invoke-NativeWithTimeout -FilePath $azdExe -Arguments @('auth', 'login', '--managed-identity') -TimeoutSec 180 -Label 'azd-auth-login'
if ($azdAuthExit -ne 0) {
    throw "FATAL: 'azd auth login --managed-identity' failed (exit=$azdAuthExit). Cannot initialize the azd environment on the jumpbox."
}


# ------------------------------
# AZD initialization
# ------------------------------
cd C:\github\ai-lz\
write-host "Initializing AZD environment"

$azdInitExit = Invoke-NativeWithTimeout -FilePath $azdExe -Arguments @('init', '-e', $AzdEnvName, '--subscription', $azureSubscriptionID, '--location', $azureLocation) -WorkingDirectory 'C:\github\ai-lz' -TimeoutSec 300 -Label 'azd-init'
if ($azdInitExit -ne 0) {
    throw "FATAL: 'azd init' failed (exit=$azdInitExit). Cannot initialize the azd environment on the jumpbox."
}

& $azdExe env set AZURE_TENANT_ID $azureTenantID
& $azdExe env set AZURE_RESOURCE_GROUP $AzureResourceGroupName
& $azdExe env set AZURE_SUBSCRIPTION_ID $azureSubscriptionID
& $azdExe env set AZURE_LOCATION $azureLocation
& $azdExe env set AZURE_AI_FOUNDRY_LOCATION $azureLocation
& $azdExe env set APP_CONFIG_ENDPOINT "https://appcs-$resourceToken.azconfig.io"
& $azdExe env set NETWORK_ISOLATION true
& $azdExe env set USE_UAI $useUAI
& $azdExe env set RESOURCE_TOKEN $resourceToken
& $azdExe env set DEPLOY_SOFTWARE false


# ------------------------------
# Clone dependent repos (OPTIONAL — best-effort, budget-aware)
# ------------------------------
# These component repos are convenience clones for downstream accelerators and
# are NOT required for CSE success. Each clone is bounded by
# Invoke-GitCloneWithTimeout; we additionally skip the remaining repos once the
# wall-clock budget runs low so they cannot push CSE past the 90-minute platform
# timeout (issue #82). The previous "update existing → git fetch --all /
# git checkout" branch was UNBOUNDED (no timeout on a hung fetch) and, because
# `forceUpdateTag` re-runs the CSE on every deployment, was a real re-run hang
# risk; we now always delete-and-reclone through the bounded helper instead.
$manifest = Get-Content "C:\github\ai-lz\manifest.json" | ConvertFrom-Json

foreach ($repo in $manifest.components) {
    $repoName = $repo.name
    $repoUrl  = $repo.repo
    $tag      = $repo.tag

    if (-not (Test-BudgetAtLeast 240)) {
        write-warning "Skipping remaining component repos (including '$repoName') - only $(Get-RemainingBudgetSec)s of CSE budget left. Clone them manually on the jumpbox if needed."
        break
    }

    $cloneTimeout = [Math]::Min(900, [Math]::Max(120, (Get-RemainingBudgetSec) - 120))
    write-host "Cloning repository: $repoName ($tag)"
    Invoke-GitCloneWithTimeout -Url $repoUrl -Tag $tag -Destination "C:\github\$repoName" -TimeoutSec $cloneTimeout
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "C:\github\$repoName")) {
        write-warning "git clone failed for component repository '$repoName' ($tag) from '$repoUrl' (exit code $LASTEXITCODE). Skipping .azure context copy and safe-directory config."
        continue
    }
    copy-item C:\github\ai-lz\.azure C:\github\$repoName -recurse -force

    git config --global --add safe.directory "C:/github/$repoName"
}

# ------------------------------
# Clone extra repos derived from manifest.json#components (forwarded by main.bicep)
# ------------------------------
# The Bicep module derives -ExtraRepoUrls/-ExtraRepoTags/-ExtraRepoNames from
# the consumer's overlay `manifest.json#components`, so downstream solution
# accelerators (e.g. GPT-RAG, live-voice-practice) keep a single source of
# truth (their manifest.json) for both release versioning and jumpbox repo
# bootstrapping. See issues #21 and #22.
#
# Note: each split is wrapped in @(...) to force array context. Without it,
# PowerShell 5.1 collapses a single-element pipeline result into a scalar
# string, and `$arr[0]` then returns the FIRST CHARACTER of the URL/tag/name
# instead of the value itself (issues #22, #23 repro).
#
# Important: the @(...) MUST be on the right-hand side of a plain assignment.
# In the form `$x = if (...) { @(...) } else { @(...) }`, the `if` is an
# expression and PowerShell 5.1's pipeline output processor unwraps the
# single-element result back to a scalar — that was the residual bug from
# v1.1.1 caught in #23. So we use plain `if` statements with `@(...)` on
# the assignment RHS instead of `if`-as-expression.
if (-not [string]::IsNullOrWhiteSpace($ExtraRepoUrls)) {
    $extraUrls = @($ExtraRepoUrls -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    $extraTags = @()
    if (-not [string]::IsNullOrWhiteSpace($ExtraRepoTags)) {
        $extraTags = @($ExtraRepoTags -split ',' | ForEach-Object { $_.Trim() })
    }

    $extraNames = @()
    if (-not [string]::IsNullOrWhiteSpace($ExtraRepoNames)) {
        $extraNames = @($ExtraRepoNames -split ',' | ForEach-Object { $_.Trim() })
    }

    for ($i = 0; $i -lt $extraUrls.Count; $i++) {
        $url  = $extraUrls[$i]
        $tag  = if ($i -lt $extraTags.Count  -and $extraTags[$i])  { $extraTags[$i]  } else { 'main' }
        $name = if ($i -lt $extraNames.Count -and $extraNames[$i]) { $extraNames[$i] } else { (($url -split '/')[-1]) -replace '\.git$','' }

        if (-not (Test-BudgetAtLeast 240)) {
            write-warning "Skipping remaining extra repos (including '$name') - only $(Get-RemainingBudgetSec)s of CSE budget left. Clone them manually on the jumpbox if needed."
            break
        }

        # Always delete-and-reclone through the bounded helper. The previous
        # "update existing → git fetch --all / git checkout" branch was
        # unbounded and could hang CSE on a re-run (forceUpdateTag). See #82.
        write-host "Cloning extra repository: $name ($tag) from $url"
        $cloneTimeout = [Math]::Min(900, [Math]::Max(120, (Get-RemainingBudgetSec) - 120))
        Invoke-GitCloneWithTimeout -Url $url -Tag $tag -Destination "C:\github\$name" -TimeoutSec $cloneTimeout
        # Surface git clone failures in the CSE transcript. The CSE itself
        # will not fail because of this (we don't want a single failed
        # extra clone to roll back the entire jumpbox bootstrap), but the
        # operator gets a clear signal in C:\WindowsAzure\Logs\.
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path "C:\github\$name")) {
            write-warning "git clone failed for extra repository '$name' ($tag) from '$url' (exit code $LASTEXITCODE). Skipping .azure context copy and safe-directory config."
            continue
        }
        copy-item C:\github\ai-lz\.azure "C:\github\$name" -recurse -force

        git config --global --add safe.directory "C:/github/$name"
    }
}

# Reboot to finalize Chocolatey-installed tools (Git, Python, VS Code, PowerShell Core)
# that flagged a pending reboot. Delay by 120s so the Custom Script Extension (CSE)
# agent has enough time (~30s) to report the final Succeeded status back to ARM
# before the VM goes down. A shorter delay (or an immediate reboot) causes the ARM
# provisioningState to stay permanently at "Updating", which breaks
# `az vm extension wait` and any deployment that depends on CSE completion.
write-host "Installation completed successfully!";
write-host "Total CSE wall time: $([int]((Get-Date) - $script:CseStartTime).TotalSeconds)s (budget $($script:CseWallBudgetSec)s, remaining $(Get-RemainingBudgetSec)s)."
write-host "Rebooting in 120 seconds to complete setup...";
shutdown /r /t 120 /c "Rebooting after CSE setup to finalize installed tooling"

Stop-Transcript
