$tenantId = "your-tenant-id"
$subscriptionId = "your-subscription-id"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco upgrade vscode -y --ignoredetectedreboot --force
choco upgrade azure-cli -y --ignoredetectedreboot --force
choco upgrade git -y --ignoredetectedreboot --force
choco upgrade nodejs -y --ignoredetectedreboot --force

choco install python311 -y --ignoredetectedreboot --force
#choco install visualstudio2022enterprise -y --ignoredetectedreboot --force
choco install github-desktop -y --ignoredetectedreboot --force
choco install azd -y --ignoredetectedreboot --force
choco install powershell-core -y --ignoredetectedreboot --force

#install extenstions
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-azuretools.vscode-bicep","--force" -wait

npm install -g @azure/static-web-apps-cli
npm install -g typescript

#setup git

#download the repo(s)
mkdir c:\github
cd c:\github
git clone https://github.com/Azure/GPT-RAG
git clone https://github.com/givenscj/ai-document-processor/tree/cjg-zta

#pull sub repos
cd GPT-RAG

#login
az login --tenant $tenantId
az account set --subscription $subscriptionId
azd auth login --tenant-id $tenantId

#set env variables...
#set env variables...ZTA or non-ZTA
azd env set AZURE_NETWORK_ISOLATION false
azd env set AZURE_ZERO_TRUST false

#provision
azd provision

Set-ExecutionPolicy unrestricted
 
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
-Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force

#get the components
cd scripts
.\fetchComponents.ps1

cd..
azd deploy

#check region

#check quotas



