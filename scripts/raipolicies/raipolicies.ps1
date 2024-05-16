param (
[string]$Tenant,
[string]$Subscription,
[string]$ResourceGroup,
[string]$AoaiResourceName,
[string]$AoaiModelName,
[string]$RaiPolicyName
)

Write-Host "RAI Script: Setting up AOAI content filter"

$token = (Get-AzAccessToken -TenantId $tenantId).Token

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Please manually sign-in to Azure account"
    Connect-AzAccount
    $token = (Get-AzAccessToken -TenantId $tenantId).Token
}

$headers = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json"
}

$baseURI = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# Creating a content filter policy for AOAI account
$filePath = Join-Path -Path $PSScriptRoot -ChildPath 'raipolicies.json'
$policyBody = (Get-Content -Path $filePath -Raw).Replace("{{PolicyName}}", $RaiPolicyName)
$policyURI = $baseURI + "/raiPolicies/$($RaiPolicyName)?api-version=2023-10-01-preview"
Invoke-RestMethod -Uri $policyURI -Method Put -Body $policyBody -Headers $headers

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
Invoke-RestMethod -Uri $modelURI -Method Put -Body ($updatedModel | ConvertTo-Json) -Headers $headers
