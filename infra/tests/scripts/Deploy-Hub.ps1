<#
.SYNOPSIS
  Deploy the AI LZ test hub to `rg-ailz-hub` in the configured subscription.

.DESCRIPTION
  Idempotent wrapper around `az deployment group create` that:
    1. Verifies the active az subscription matches the expected test subscription
       (default: 9788a92c-2f71-4629-8173-7ad449cb50e1).
    2. Creates the `rg-ailz-hub` resource group if it does not exist.
    3. Deploys `tests/hub/main.bicep` with `tests/hub/main.parameters.json`.
    4. Captures all hub deployment outputs (VNet id, firewall private IP, LAW id,
       Bastion id) into `tests/hub/.outputs.json` so the subsequent spoke
       deployment can consume them.

  This is part of the issue #58 v2.0.0 hub-spoke integration test harness.

.PARAMETER SubscriptionId
  Azure subscription to deploy into. Defaults to the AI LZ test subscription.

.PARAMETER ResourceGroupName
  Hub resource group name. Defaults to `rg-ailz-hub` per the test convention.

.PARAMETER Location
  Azure region. Defaults to `eastus2`.

.PARAMETER DeploymentName
  Name of the ARM deployment. Defaults to a timestamped value so re-runs do not
  collide in the deployment history.

.PARAMETER WhatIf
  Run `az deployment group what-if` and print the change preview without
  applying changes.

.EXAMPLE
  pwsh tests/scripts/Deploy-Hub.ps1

.EXAMPLE
  pwsh tests/scripts/Deploy-Hub.ps1 -WhatIf
#>
[CmdletBinding()]
param(
  [string]$SubscriptionId = '9788a92c-2f71-4629-8173-7ad449cb50e1',
  [string]$ResourceGroupName = 'rg-ailz-hub',
  [string]$Location = 'eastus2',
  [string]$DeploymentName = "ailz-hub-$(Get-Date -Format 'yyyyMMddHHmm')",
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$bicepFile  = Join-Path $repoRoot 'tests' 'hub' 'main.bicep'
$paramsFile = Join-Path $repoRoot 'tests' 'hub' 'main.parameters.json'
$outputFile = Join-Path $repoRoot 'tests' 'hub' '.outputs.json'

Write-Host "AI LZ test hub deployment" -ForegroundColor Cyan
Write-Host "  Subscription   : $SubscriptionId" -ForegroundColor DarkGray
Write-Host "  Resource group : $ResourceGroupName" -ForegroundColor DarkGray
Write-Host "  Location       : $Location" -ForegroundColor DarkGray
Write-Host "  Deployment     : $DeploymentName" -ForegroundColor DarkGray
Write-Host ""

# 1) Subscription guard --------------------------------------------------------

$currentSub = (az account show --query id -o tsv)
if ($LASTEXITCODE -ne 0) {
  throw "az account show failed. Run `az login` first."
}

if ($currentSub -ne $SubscriptionId) {
  Write-Host "Switching active subscription from $currentSub to $SubscriptionId" -ForegroundColor Yellow
  az account set --subscription $SubscriptionId
  if ($LASTEXITCODE -ne 0) {
    throw "az account set failed for subscription $SubscriptionId."
  }
}

# 2) Resource group ------------------------------------------------------------

$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($rgExists -eq $false) {
  Write-Host "Creating resource group $ResourceGroupName in $Location..." -ForegroundColor Cyan
  az group create --name $ResourceGroupName --location $Location --tags purpose=ailz-v2-test scope=hub | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "az group create failed." }
} else {
  Write-Host "Resource group $ResourceGroupName already exists; skipping creation." -ForegroundColor DarkGray
}

# 3) Deploy --------------------------------------------------------------------

if ($WhatIf) {
  Write-Host ""
  Write-Host "Running what-if (no changes will be applied)..." -ForegroundColor Yellow
  az deployment group what-if `
    --resource-group $ResourceGroupName `
    --name $DeploymentName `
    --template-file $bicepFile `
    --parameters $paramsFile
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Deploying hub (this takes ~25-30 minutes for Firewall + Bastion)..." -ForegroundColor Cyan
az deployment group create `
  --resource-group $ResourceGroupName `
  --name $DeploymentName `
  --template-file $bicepFile `
  --parameters $paramsFile `
  --output none
if ($LASTEXITCODE -ne 0) { throw "Hub deployment failed (exit $LASTEXITCODE). Inspect: az deployment group show -g $ResourceGroupName -n $DeploymentName" }

# 4) Capture outputs -----------------------------------------------------------

Write-Host ""
Write-Host "Capturing hub outputs to $outputFile" -ForegroundColor Cyan
$outputs = az deployment group show `
  --resource-group $ResourceGroupName `
  --name $DeploymentName `
  --query properties.outputs `
  -o json | ConvertFrom-Json

$flattened = [ordered]@{}
foreach ($k in $outputs.PSObject.Properties.Name) {
  $flattened[$k] = $outputs.$k.value
}
$flattened['_meta'] = [ordered]@{
  subscriptionId = $SubscriptionId
  resourceGroup  = $ResourceGroupName
  location       = $Location
  deploymentName = $DeploymentName
  capturedUtc    = (Get-Date).ToUniversalTime().ToString('o')
}

$flattened | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile -Encoding UTF8

Write-Host ""
Write-Host "Hub deployment complete." -ForegroundColor Green
Write-Host "  hubVnetResourceId         = $($flattened.hubVnetResourceId)"
Write-Host "  firewallPrivateIp         = $($flattened.firewallPrivateIp)"
Write-Host "  bastionResourceId         = $($flattened.bastionResourceId)"
Write-Host "  logAnalyticsResourceId    = $($flattened.logAnalyticsWorkspaceResourceId)"
Write-Host ""
Write-Host "Pass these values to the spoke deployment via `azd env set` — see tests/README.md." -ForegroundColor DarkGray
