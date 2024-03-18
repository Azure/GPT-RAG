$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Blue
$NC = [ConsoleColor]::White

$storageAccountName = $env:AZURE_STORAGE_ACCOUNT_NAME
$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME

# Disable public access to storage account blob containers (commmented to be done during provisioning)
# az storage account update --name $storageAccountName --resource-group $resourceGroupName --allow-blob-public-access false

if ($env:AZURE_ZERO_TRUST -eq "FALSE") {
    exit 0
}

Write-Host "For accessing the Zero Trust infrastructure, from the Azure Portal:"
Write-Host "Virtual Machine: $($env:AZURE_VM_NAME)"
Write-Host "Select connect using Bastion with:"
Write-Host "  username: $($env:AZURE_VM_USERNAME)"
Write-Host "  Key Vault/Secret: $($env:AZURE_VM_KV_NAME)/$($env:AZURE_VM_KV_SEC_NAME)"
