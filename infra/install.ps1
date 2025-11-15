<#
    GPT-RAG Jumpbox Setup Script – Updated for Custom Script Extension (CSE)

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
  [string] $useUAI 
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


# ------------------------------
# Install Chocolatey
# ------------------------------
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

$env:Path += ";C:\ProgramData\chocolatey\bin"


# ------------------------------
# Install tooling
# ------------------------------
write-host "Installing Visual Studio Code"
choco upgrade vscode -y --ignoredetectedreboot --force

write-host "Installing Azure CLI"
choco install azure-cli -y --ignoredetectedreboot --force

# Add Azure CLI to PATH immediately
$env:PATH = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;$env:PATH"


write-host "Installing Git"
choco upgrade git -y --ignoredetectedreboot --force
$env:PATH = "C:\Program Files\Git\cmd;$env:PATH"


write-host "Installing Python 3.11"
choco install python311 -y --ignoredetectedreboot --force

Write-Host "Installing AZD..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"

Write-Host "Searching for installed AZD executable..."

$possibleAzdLocations = @(
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
# Install PowerShell Core, Notepad++, WSL, Docker
# ------------------------------
write-host "Installing PowerShell Core"
choco install powershell-core -y --ignoredetectedreboot --force

write-host "Installing Notepad++"
choco install notepadplusplus -y --ignoredetectedreboot --force


# WSL Setup
write-host "Enabling WSL features"
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

write-host "Updating WSL"
Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile ".\wsl_update_x64.msi"
Start-Process "msiexec.exe" -ArgumentList "/i .\wsl_update_x64.msi /quiet" -NoNewWindow -Wait
wsl.exe --update
wsl.exe --set-default-version 2


# Docker
write-host "Installing Docker Desktop"
choco install docker-desktop -y --ignoredetectedreboot --force


# ------------------------------
# Clone GPT-RAG repo
# ------------------------------
write-host "Cloning GPT-RAG repo"
mkdir C:\github -ea SilentlyContinue
cd C:\github
git clone https://github.com/azure/gpt-rag -b $release --depth 1


# ------------------------------
# Azure Login
# ------------------------------
write-host "Logging into Azure"
az login --identity

write-host "Logging into AZD"
& $azdExe auth login --managed-identity


# ------------------------------
# AZD initialization
# ------------------------------
cd C:\github\gpt-rag\
write-host "Initializing AZD environment"

& $azdExe init -e $AzdEnvName --subscription $azureSubscriptionID --location $azureLocation

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
# Clone dependent repos
# ------------------------------
$manifest = Get-Content "C:\github\gpt-rag\infra\manifest.json" | ConvertFrom-Json

foreach ($repo in $manifest.components) {
    $repoName = $repo.name
    $repoUrl  = $repo.repo
    $tag      = $repo.tag

    if (Test-Path "C:\github\$repoName") {
        write-host "Updating existing repository: $repoName"
        cd "C:\github\$repoName"
        git fetch --all
        git checkout $tag
    }
    else {
        write-host "Cloning repository: $repoName ($tag)"
        git clone -b $tag --depth 1 $repoUrl "C:\github\$repoName"
        copy-item C:\github\gpt-rag\.azure C:\github\$repoName -recurse -force
    }

    git config --global --add safe.directory "C:/github/$repoName"
}

# Always reboot to complete Docker Desktop and WSL2 setup
write-host "Installation completed successfully!";
write-host "Rebooting in 30 seconds to complete setup...";
$runTime = (Get-Date).AddMinutes(1).ToString("HH:mm")
schtasks /create /tn "FinishSetupReboot" /sc once /st $runTime /tr "shutdown /r /t 0 /c 'Rebooting after CSE setup'" /ru SYSTEM /f

Stop-Transcript
