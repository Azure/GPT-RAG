## Provides a head's up to user for AZURE_NETWORK_ISOLATION

# Check if AZURE_NETWORK_ISOLATION environment variable is defined
if (-not $env:AZURE_NETWORK_ISOLATION) {
    exit 0
}

# Check if AZURE_NETWORK_ISOLATION environment variable is set to a positive value
if ($env:AZURE_NETWORK_ISOLATION -match '^[1-9][0-9]*$' -or $env:AZURE_NETWORK_ISOLATION -match '^[Tt][Rr][Uu][Ee]$' -or $env:AZURE_NETWORK_ISOLATION -match '^[Tt]$') {
    
    # Display a heads up warning
    Write-Host "Heads up! AZURE_NETWORK_ISOLATION is set to a positive value."

    # Prompt for user confirmation
    $confirmation = Read-Host "Continue with the script? [Y/n]: "

    # Check if the confirmation is positive
    if ($confirmation -ne "Y" -and $confirmation -ne "y" -and $confirmation) {
        exit 1
    }
}

$useACA = $env:AZURE_USE_ACA
$useAKS = $env:AZURE_USE_AKS
$useMCP = $env:AZURE_USE_MCP
$resourcePrefix = $env:AZURE_RESOURCE_PREFIX

write-host "Use ACA: $useACA"
write-host "Use AKS: $useAKS"
write-host "Use MCP: $useMCP"

if ($useAKS) {

    #you need to install openssl
    #choco install openssl -y

    if ($env:GENERATE_SSL_CERT)
    {
        $hostname = "$($resourcePrefix).com"

        write-host "Creating TLS certs for $hostname" -ForegroundColor $YELLOW

        # Need to generate the TLS certs for the AKS cluster
        openssl req -new -x509 -nodes -out tls.crt -keyout tls.key -subj "/CN=$hostName" -addext "subjectAltName=DNS:$hostName"
        openssl pkcs12 -export -in tls.crt -inkey tls.key -out tls.pfx

        write-host "Uploading TLS certs to Azure Key Vault" -ForegroundColor $YELLOW
        #upload to azure key vault
        $keyVaultName = "kv$($resourcePrefix)"
        az keyvault certificate import --vault-name $keyVaultName --name 'tls.crt' --file tls.pfx

        KEYVAULTID=$(az keyvault show --name <KeyVaultName> --query "id" --output tsv)
        az aks approuting update --resource-group $env:AZURE_RESOURCE_GROUP_NAME --name "aks-$resourcePrefix-backend" --enable-kv --attach-kv ${KEYVAULTID}
    }
}

exit 0
