# Helper Script to Get VNet Resource ID
# This script helps you get the full ARM Resource ID for an existing Virtual Network

param(
    [Parameter(Mandatory=$true)]
    [string]$VnetName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

Write-Host "Getting VNet Resource ID..." -ForegroundColor Cyan

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
}

# Get the VNet Resource ID
$resourceId = az network vnet show `
    --name $VnetName `
    --resource-group $ResourceGroupName `
    --query id `
    --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nVNet Resource ID:" -ForegroundColor Green
    Write-Host $resourceId -ForegroundColor White
    
    Write-Host "`nTo use this with azd, run:" -ForegroundColor Cyan
    Write-Host "azd env set EXISTING_VNET_RESOURCE_ID `"$resourceId`"" -ForegroundColor White
    
    # Copy to clipboard if available
    try {
        $resourceId | Set-Clipboard
        Write-Host "`n✓ Resource ID copied to clipboard!" -ForegroundColor Green
    }
    catch {
        Write-Host "`nNote: Could not copy to clipboard automatically." -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n✗ Failed to get VNet Resource ID" -ForegroundColor Red
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "  - VNet name is correct: $VnetName" -ForegroundColor Yellow
    Write-Host "  - Resource group name is correct: $ResourceGroupName" -ForegroundColor Yellow
    Write-Host "  - You have access to the VNet" -ForegroundColor Yellow
    if ($SubscriptionId) {
        Write-Host "  - Subscription ID is correct: $SubscriptionId" -ForegroundColor Yellow
    }
    exit 1
}
