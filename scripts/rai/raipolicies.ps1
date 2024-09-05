param (
[string]$Tenant,
[string]$Subscription,
[string]$ResourceGroup,
[string]$AoaiResourceName,
[string]$AoaiModelName,
[string]$RaiPolicyName,
[string]$RaiBlocklistName
)

Write-Host "RAI Script: Setting up AOAI content filters & blocklist"

$token = az account get-access-token --tenant "$Tenant" --query accessToken --output tsv

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Failed to get access token. Please manually sign-in to Azure account"
    az login --use-device-code
    $token = az account get-access-token --tenant "$Tenant" --query accessToken --output tsv
}

$headers = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json"
}

$baseURI = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# Creating a blocklist for AOAI account
$filePath = Join-Path -Path $PSScriptRoot -ChildPath 'raiblocklist.json'
$blocklistJson = (Get-Content -Path $filePath -Raw).Replace("{{BlocklistName}}", $RaiBlocklistName) | ConvertFrom-Json 

$blocklistName = $blocklistJson.blocklistname
$blocklistItems = $blocklistJson.blocklistItems

$blocklistBody = [PSCustomObject]@{
    properties = [PSCustomObject]@{
        description = "$($blocklistName) blocklist policy"
    }
}

$blocklistURI = $baseURI + "/raiBlocklists/$($blocklistName)?api-version=2023-10-01-preview"
Invoke-RestMethod -Uri $blocklistURI -Method Put -Body ($blocklistBody | ConvertTo-Json) -Headers $headers | Out-Null

$blocklistItemsURI = $baseURI + "/raiBlocklists/$($blocklistName)/raiBlocklistItems/$($blocklistName)Items?api-version=2023-10-01-preview"

# Remove previous items from blocklist 
# - This covers scenario where blocklist items get updated in existing deployment
do {
    Try {
        Invoke-RestMethod -Uri $blocklistItemsURI -Method Delete -Headers $headers | Out-Null
    } Catch {
        break
    }
} while ($true)

# Add items into blocklist
foreach ($item in $blocklistItems) {
    if ($item.pattern) {
        $blocklistItemsBody = [PSCustomObject]@{
            properties = [PSCustomObject]@{
            pattern = $item.pattern
            isRegex = $item.isRegex
            }
        }

        Invoke-RestMethod -Uri $blocklistItemsURI -Method Put -Body ($blocklistItemsBody | ConvertTo-Json) -Headers $headers | Out-Null
    }
}

# Creating a content filter policy for AOAI account
$filePath = Join-Path -Path $PSScriptRoot -ChildPath 'raipolicies.json'
$policyBody = (Get-Content -Path $filePath -Raw).Replace("{{PolicyName}}", $RaiPolicyName).Replace("{{BlocklistName}}", $blocklistName)

$policyURI = $baseURI + "/raiPolicies/$($RaiPolicyName)?api-version=2023-10-01-preview"
Invoke-RestMethod -Uri $policyURI -Method Put -Body $policyBody -Headers $headers | Out-Null

# Getting deployed AOAI model profile
$modelURI = $baseURI + "/deployments/$($AoaiModelName)?api-version=2023-10-01-preview"
$modelDeployments = Invoke-RestMethod -Uri $modelURI -Method Get -Headers $headers
$model = $modelDeployments | Where-Object name -eq $AoaiModelName | Select-Object -First 1

# Assign created policy to model profile
$updatedModel = [PSCustomObject]@{
    displayName = $ModelName
    sku         = $model.sku
    properties  = [PSCustomObject]@{
        model = $model.properties.model
        versionUpgradeOption = $model.properties.versionUpgradeOption
        raiPolicyName = $RaiPolicyName
    }
}
Invoke-RestMethod -Uri $modelURI -Method Put -Body ($updatedModel | ConvertTo-Json) -Headers $headers | Out-Null
