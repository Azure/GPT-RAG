<#
.SYNOPSIS
    Creates the reverse hub→spoke VNet peering after the spoke is deployed.

.DESCRIPTION
    The spoke→hub peering is created automatically by main.bicep when
    `hubIntegrationHubVnetResourceId` is set and
    `hubIntegrationCreateHubPeering=true` (default). The reverse direction
    (hub→spoke) must be created separately because the spoke deployment
    typically does not have write access to the hub resource group in real
    landing-zone topologies.

    This script:
      1. Reads the spoke VNet resource ID from `azd env get-values` (or
         from the explicit `-SpokeVnetResourceId` parameter).
      2. Reads the hub VNet resource ID from `tests/hub/.outputs.json` (or
         from the explicit `-HubVnetResourceId` parameter).
      3. Creates a `to-spoke-<spokeVnetName>` peering on the hub VNet with
         `allowForwardedTraffic=true` so the hub firewall can forward
         spoke return traffic.

    The peering propagates routes both ways once both sides are connected.

.PARAMETER HubVnetResourceId
    Resource ID of the hub VNet (must match what was passed to the spoke
    deployment as `hubIntegrationHubVnetResourceId`). Defaults to the value
    captured in `tests/hub/.outputs.json` by `Deploy-Hub.ps1`.

.PARAMETER SpokeVnetResourceId
    Resource ID of the spoke VNet. Defaults to `azd env get-values |
    Select-String VNET_RESOURCE_ID`.

.PARAMETER PeeringName
    Override the auto-generated peering name (`to-spoke-<spokeVnetName>`).

.EXAMPLE
    pwsh ./tests/scripts/Add-HubSpokePeering.ps1
    Pick up both VNet IDs from local state and create the reverse peering.

.EXAMPLE
    pwsh ./tests/scripts/Add-HubSpokePeering.ps1 `
        -SpokeVnetResourceId '/subscriptions/.../virtualNetworks/myspoke'
    Reverse-peer to an explicitly-named spoke VNet (useful when running
    from a workstation that doesn't have azd state for the spoke env).
#>
[CmdletBinding()]
param(
    [string]$HubVnetResourceId,
    [string]$SpokeVnetResourceId,
    [string]$PeeringName,
    [string]$HubOutputsPath = (Join-Path $PSScriptRoot '..\hub\.outputs.json'),
    [switch]$AllowGatewayTransit,
    [switch]$UseRemoteGateways
)

$ErrorActionPreference = 'Stop'

function Get-ResourceIdParts {
    param([Parameter(Mandatory)][string]$Id)
    $parts = $Id.TrimStart('/').Split('/')
    if ($parts.Count -lt 8) { throw "Invalid resource ID: $Id" }
    return @{
        SubscriptionId    = $parts[1]
        ResourceGroupName = $parts[3]
        Name              = $parts[7]
    }
}

if (-not $HubVnetResourceId) {
    if (-not (Test-Path $HubOutputsPath)) {
        throw "Hub outputs file not found at $HubOutputsPath. Run Deploy-Hub.ps1 first or pass -HubVnetResourceId explicitly."
    }
    $hubOutputs = Get-Content $HubOutputsPath -Raw | ConvertFrom-Json
    $HubVnetResourceId = $hubOutputs.hubVnetResourceId
}

if (-not $SpokeVnetResourceId) {
    Write-Host "Reading spoke VNET_RESOURCE_ID from azd environment..."
    $azdValues = & azd env get-values 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read azd environment. Pass -SpokeVnetResourceId explicitly."
    }
    $match = $azdValues | Select-String -Pattern '^VNET_RESOURCE_ID="?([^"\r\n]+)"?$'
    if (-not $match) {
        throw "VNET_RESOURCE_ID not found in azd env output. Pass -SpokeVnetResourceId explicitly."
    }
    $SpokeVnetResourceId = $match.Matches[0].Groups[1].Value
}

if (-not $SpokeVnetResourceId) { throw "Spoke VNet resource ID could not be determined." }
if (-not $HubVnetResourceId)   { throw "Hub VNet resource ID could not be determined." }

$hub   = Get-ResourceIdParts -Id $HubVnetResourceId
$spoke = Get-ResourceIdParts -Id $SpokeVnetResourceId

if (-not $PeeringName) { $PeeringName = "to-spoke-$($spoke.Name)" }

Write-Host ""
Write-Host "Reverse peering plan:" -ForegroundColor Cyan
Write-Host "  Hub VNet         : $($hub.Name) (RG=$($hub.ResourceGroupName), Sub=$($hub.SubscriptionId))"
Write-Host "  Spoke VNet       : $($spoke.Name) (RG=$($spoke.ResourceGroupName), Sub=$($spoke.SubscriptionId))"
Write-Host "  Peering name     : $PeeringName"
Write-Host "  AllowGatewayTransit : $($AllowGatewayTransit.IsPresent)"
Write-Host "  UseRemoteGateways   : $($UseRemoteGateways.IsPresent)"
Write-Host ""

$azArgs = @(
    'network', 'vnet', 'peering', 'create',
    '--name', $PeeringName,
    '--resource-group', $hub.ResourceGroupName,
    '--subscription', $hub.SubscriptionId,
    '--vnet-name', $hub.Name,
    '--remote-vnet', $SpokeVnetResourceId,
    '--allow-vnet-access', 'true',
    '--allow-forwarded-traffic', 'true'
)
if ($AllowGatewayTransit) { $azArgs += @('--allow-gateway-transit', 'true') }
if ($UseRemoteGateways)   { $azArgs += @('--use-remote-gateways',   'true') }

Write-Host "Creating reverse peering..."
& az @azArgs --output none
if ($LASTEXITCODE -ne 0) { throw "Peering creation failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "Reverse peering created. Verify both directions show 'Connected':" -ForegroundColor Green
Write-Host "  az network vnet peering list -g $($hub.ResourceGroupName) --vnet-name $($hub.Name) --query '[].{name:name,state:peeringState}' -o table"
Write-Host "  az network vnet peering list -g $($spoke.ResourceGroupName) --vnet-name $($spoke.Name) --query '[].{name:name,state:peeringState}' -o table"
