$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Blue
$NC = [ConsoleColor]::White

$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$tenantId = $env:AZURE_TENANT_ID

# Disable public access to storage account blob containers (commmented to be done during provisioning)
# az storage account update --name $storageAccountName --resource-group $resourceGroupName --allow-blob-public-access false

# Creating a new RAI policy and attaching to deployed OpenAI model.
$aoaiResourceName = $env:AZURE_OPENAI_SERVICE_NAME
$aoaiModelName = $env:AZURE_OPENAI_MODEL_NAME

# RAI script: AOAI content filters
$RAIscript = Join-Path -Path $PSScriptRoot -ChildPath 'rai\raipolicies.ps1'
& $RAIscript -Tenant $tenantId -Subscription $subscriptionId -ResourceGroup $resourceGroupName -AoaiResourceName $aoaiResourceName -AoaiModelName $aoaiModelName -RaiPolicyName 'MainRAIpolicy' -RaiBlocklistName 'MainBlockListPolicy'

if ($env:AZURE_ZERO_TRUST -eq "FALSE") {
    exit 0
}

Write-Host "For accessing the Zero Trust infrastructure, from the Azure Portal:"
Write-Host "Virtual Machine: $($env:AZURE_VM_NAME)"
Write-Host "Select connect using Bastion with:"
Write-Host "  username: $($env:AZURE_VM_USERNAME)"
Write-Host "  Key Vault/Secret: $($env:AZURE_VM_KV_NAME)/$($env:AZURE_VM_KV_SEC_NAME)"
