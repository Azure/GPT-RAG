<#
This script automates setting up and provisioning a Windows VM for Azure-based GPT-RAG development.

It will:
  • Start logging to C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt
  • Enable TLS 1.2+ for PowerShell
  • Install or upgrade Chocolatey, then use it to install/upgrade:
      – Visual Studio Code
      – Azure CLI
      – Git
      – Node.js
      – Python 3.11
      – Azure Developer CLI (azd) v1.20.3
      – PowerShell Core
      – Notepad++
  • Extend the C: drive to its maximum supported size
  • Enable and update WSL and schedule a one-time login task to:
      – Install VS Code extensions
  • Add key VS Code extensions: Bicep, Azure Functions, Python, Containers & PowerShell
  • Clone the GPT-RAG repositories (specific tags for gpt-rag, orchestrator, ingestion, UI, MCP)
  • Configure Git safe directories
  • Log into Azure CLI and azd with managed identity
  • Update the .azure\<env>\.env file with necessary environment variables
  • Reboot the VM if new software was installed

Parameters:
  -release                : Release tag for GPT-RAG (ex: v2.0.1)
  -azureTenantID          : Azure tenant ID (required)
  -azureSubscriptionID    : Azure subscription ID
  -AzureResourceGroupName : Resource group name
  -azureLocation          : Azure region (e.g., eastus)
  -AzdEnvName             : azd environment name
  -resourceToken          : App Configuration token
  -useUAI                 : Enable UAI integration flag

Prerequisites:
  • Windows 11 with admin rights
  • Internet access for downloads
  • Local user "testvmuser" for scheduled tasks
#>

Param (
  [Parameter(Mandatory = $true)]
  [string]
  $release,

  [string]
  $azureTenantID,

  [string]
  $azureSubscriptionID,

  [string]
  $AzureResourceGroupName,

  [string]
  $azureLocation,

  [string]
  $AzdEnvName,

  [string]
  $resourceToken,

  [string]
  $useUAI 
)

Start-Transcript -Path C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

$env:Path += ";C:\ProgramData\chocolatey\bin"

# Variable specifying the drive you want to extend  
$drive_letter = "C"  
# Script to get the partition sizes and then resize the volume  
$size = (Get-PartitionSupportedSize -DriveLetter $drive_letter)  
Resize-Partition -DriveLetter $drive_letter -Size $size.SizeMax 

write-host "Installing Visual Studio Code";
choco upgrade vscode -y --ignoredetectedreboot --force

write-host "Installing Azure CLI (forced, user-visible install)";
choco install azure-cli -y --ignoredetectedreboot --force

# Add Azure CLI to PATH (bypass 1024-char limit)
$oldPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$newPath = $oldPath + ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
[Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)
$env:PATH = $newPath  # makes 'az' available immediately in this session

write-host "Installing GIT";
choco upgrade git -y --ignoredetectedreboot --force
# Add Git to PATH
$oldPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$newPath = $oldPath + ";C:\Program Files\Git\cmd"
[Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)
$env:PATH = $newPath  # makes 'git' available immediately in this session

write-host "Installing Python311";
choco install python311 -y --ignoredetectedreboot --force
#choco install visualstudio2022enterprise -y --ignoredetectedreboot --force

write-host "Installing AZD";
choco install azd -y --ignoredetectedreboot --force
# Add AZD to PATH
$oldPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$newPath = $oldPath + ";C:\Program Files\Azure Dev CLI" 
[Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine) 

write-host "Installing Powershell Core";
choco install powershell-core -y --ignoredetectedreboot --force

# write-host "Installing Chrome";
#choco install googlechrome -y --ignoredetectedreboot --force

write-host "Installing Notepad++";
choco install notepadplusplus -y --ignoredetectedreboot --force

write-host "Enabling WSL";
# Enable WSL feature
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
# Enable Virtual Machine Platform (required for WSL2)
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

write-host "Enabling WSL";
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux, VirtualMachinePlatform -NoRestart

write-host "Updating WSL #1";
#https://learn.microsoft.com/en-us/windows/wsl/install-on-server
Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile ".\wsl_update_x64.msi"
Start-Process "msiexec.exe" -ArgumentList "/i .\wsl_update_x64.msi /quiet" -NoNewWindow -Wait

write-host "Updating WSL #2";
wsl.exe --update

# Set WSL2 as default version
write-host "Setting WSL2 as default version";
wsl.exe --set-default-version 2

write-host "Installing Docker Desktop (includes WSL2 setup)";
choco install docker-desktop -y --ignoredetectedreboot --force

# Add Docker to PATH
$oldPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$newPath = $oldPath + ";C:\Program Files\Docker\Docker\resources\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)
$env:PATH = $newPath

write-host "Configuring Docker Desktop to start with Windows";
$regPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Set-ItemProperty -Path $regPath -Name "Docker Desktop" -Value $dockerPath

# install extensions
# $install_content = "Start-Process `"C:\Program Files\Microsoft VS Code\bin\code.cmd`" -ArgumentList `"--install-extension`",`"ms-azuretools.vscode-bicep`",`"--force`" -wait`n"
# $install_content += "Start-Process `"C:\Program Files\Microsoft VS Code\bin\code.cmd`" -ArgumentList `"--install-extension`",`"ms-python.python`",`"--force`" -wait`n"
# $install_content += "Start-Process `"C:\Program Files\Microsoft VS Code\bin\code.cmd`" -ArgumentList `"--install-extension`",`"ms-vscode-remote.remote-containers`",`"--force`" -wait`n"
# $install_content += "Start-Process `"C:\Program Files\Microsoft VS Code\bin\code.cmd`" -ArgumentList `"--install-extension`",`"ms-vscode-powershell`",`"--force`" -wait`n"
# $install_content += "Start-Process `"C:\Program Files\Microsoft VS Code\bin\code.cmd`" -ArgumentList `"--install-extension`",`"ms-azuretools.vscode-azurefunctions`",`"--force`" -wait`n"
# $install_content += "Unregister-ScheduledTask -TaskName 'MyOneTimeSelfDeletingTask' -Confirm `$false`n"
# mkdir C:\temp -ea SilentlyContinue
# Set-Content "C:\temp\LoginInstall.ps1" $install_content
#create a one time self-deleting task to run after login - this will run WSL update, install VS Code extensions
# $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -File C:\temp\LoginInstall.ps1"
# $Trigger = New-ScheduledTaskTrigger -AtLogOn
# Register-ScheduledTask -TaskName "MyOneTimeSelfDeletingTask" -Action $Action -Trigger $Trigger -User "testvmuser" #-Settings $Settings

write-host "Downloading GPT-RAG repository";
mkdir C:\github -ea SilentlyContinue
cd C:\github
git clone https://github.com/azure/gpt-rag -b $release --depth 1

#add azd to path
$env:Path += ";C:\Program Files\Azure Dev CLI"

write-host "Logging into Azure CLI and AZD";
az login --identity
azd auth login --managed-identity

cd C:\github\gpt-rag\

write-host "Initializing AZD";
azd init -e $AzdEnvName --subscription $azureSubscriptionID --location $azureLocation 
azd env set AZURE_TENANT_ID $azureTenantID
azd env set AZURE_RESOURCE_GROUP $AzureResourceGroupName
azd env set AZURE_SUBSCRIPTION_ID $azureSubscriptionID
azd env set AZURE_LOCATION $azureLocation
azd env set AZURE_AI_FOUNDRY_LOCATION $azureLocation
azd env set APP_CONFIG_ENDPOINT "https://appcs-$resourceToken.azconfig.io"
azd env set NETWORK_ISOLATION true
azd env set USE_UAI $useUAI
azd env set RESOURCE_TOKEN $resourceToken
azd env set DEPLOY_SOFTWARE false

#load the manifest.json
$manifest = Get-Content "C:\github\gpt-rag\infra\manifest.json" | ConvertFrom-Json

foreach( $repo in $manifest.components) {
  $repoName = $repo.name
  $repoUrl = $repo.repo
  $tag = $repo.tag
  $release = $repo.release
  $branch = $release

  if (Test-Path "C:\github\$repoName") {
    write-host "Updating existing repository: $repoName $branch";
    cd "C:\github\$repoName"
    git fetch --all
    git checkout -b $branch
  } else {
    write-host "Cloning repository: $repoName from branch: $branch";
    cd c:\github
    git clone -b $branch --depth 1 $repoUrl "C:\github\$repoName"
    copy-item c:\github\gpt-rag\.azure c:\github\$repoName -recurse -container
    cd "C:\github\$repoName"
  }

  git config --global --add safe.directory C:/github/$repoName
}

# Always reboot to complete Docker Desktop and WSL2 setup
write-host "Installation completed successfully!";
write-host "Rebooting in 30 seconds to complete setup...";
$runTime = (Get-Date).AddMinutes(1).ToString("HH:mm")
schtasks /create /tn "FinishSetupReboot" /sc once /st $runTime /tr "shutdown /r /t 0 /c 'Rebooting after CSE setup'" /ru SYSTEM /f

Stop-Transcript
