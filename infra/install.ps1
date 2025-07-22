Param (
  [Parameter(Mandatory = $true)]
  [string]
  $azureTenantID,

  [string]
  $azureSubscriptionID,

  [string]
  $AzureResourceGroupName,

  [string]
  $AzdEnvName
)

Start-Transcript -Path C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

write-host "Installing Visual Studio Code";
choco upgrade vscode -y --ignoredetectedreboot --force

write-host "Installing Azure CLI";
choco upgrade azure-cli -y --ignoredetectedreboot --force

write-host "Installing GIT";
choco upgrade git -y --ignoredetectedreboot --force

write-host "Installing NODEJS";
choco upgrade nodejs -y --ignoredetectedreboot --force

write-host "Installing Python311";
choco install python311 -y --ignoredetectedreboot --force
#choco install visualstudio2022enterprise -y --ignoredetectedreboot --force
write-host "Installing AZD";
choco install azd -y --ignoredetectedreboot --force --version 1.14.100

write-host "Installing Powershell Core";
choco install powershell-core -y --ignoredetectedreboot --force

write-host "Installing Chrome";
#choco install googlechrome -y --ignoredetectedreboot --force

write-host "Installing Notepad++";
choco install notepadplusplus -y --ignoredetectedreboot --force

if (choco list --lo -r -e github-desktop) {
  Write-Host "'github-desktop' is installed"
}
else
{
  write-host "Installing Github Desktop";
  choco install github-desktop -y --ignoredetectedreboot --force
}

write-host "Updating WSL";
wsl.exe --update

if (choco list --lo -r -e docker-desktop) {
  Write-Host "'docker-desktop' is installed"
}
else
{
  write-host "Installing Docker Desktop";
  choco install docker-desktop -y --ignoredetectedreboot --force
}

#install extenstions
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-azuretools.vscode-bicep","--force" -wait
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-azuretools.vscode-azurefunctions","--force" -wait
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-python.python","--force" -wait

write-host "Downloading GPT-RAG repository";
mkdir C:\github -ea SilentlyContinue
cd C:\github
git clone https://github.com/azure/gpt-rag -b release/2.0.1
#git checkout cjg-zta
cd gpt-rag

git config --global --add safe.directory C:/github/gpt-rag

#add azd to path
$env:Path += ";C:\Program Files\Azure Dev CLI"

write-host "Logging into Azure CLI and AZD";
az login --identity --tenant $azureTenantID
azd auth login --managed-identity --tenant-id $azureTenantID

write-host "Initializing AZD";
azd init -e $AzdEnvName

#set variables if not present
$deploySoftware = $true
$content = Get-Content .azure\$($AzdEnvName)\.env
if ($content -notmatch "AZURE_SUBSCRIPTION_ID") {
  $content += "AZURE_SUBSCRIPTION_ID=$azureSubscriptionID"
}
if ($content -notmatch "AZURE_TENANT_ID") {
  $content += "AZURE_TENANT_ID=$azureTenantID"
}
if ($content -notmatch "AZURE_RESOURCE_GROUP") {
  $content += "AZURE_RESOURCE_GROUP=$AzureResourceGroupName"
}
if ($content -notmatch "DEPLOY_SOFTWARE") {
  $content += "DEPLOY_SOFTWARE=false"
}
else
{
  $deploySoftware = $false
  $content = $content -replace "DEPLOY_SOFTWARE=.*", "DEPLOY_SOFTWARE=false"
}

Set-Content .azure\$($AzdEnvName)\.env $content

write-host "Downloading GPT-RAG-ORCHESTRATOR repository";
cd C:\github
git clone https://github.com/azure/gpt-rag-orchestrator

git config --global --add safe.directory C:/github/gpt-rag-orchestrator -b release/2.0.0
copy c:\github\gpt-rag\.azure c:\github\gpt-rag-orchestrator\.azure

write-host "Downloading GPT-RAG-UI repository";
cd C:\github
git clone https://github.com/azure/gpt-rag-ui
copy c:\github\gpt-rag\.azure c:\github\gpt-rag-ui\.azure

git config --global --add safe.directory C:/github/gpt-rag-ui

write-host "Downloading GPT-RAG-MCP repository";
cd C:\github
git clone https://github.com/azure/gpt-rag-mcp -b release/0.2.0
copy c:\github\gpt-rag\.azure c:\github\gpt-rag-mcp\.azure

git config --global --add safe.directory C:/github/gpt-rag-mcp

if ($deploySoftware) {  
  write-host "Restarting the machine to complete installation";
  shutdown /r
}

Stop-Transcript