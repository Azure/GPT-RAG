$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Blue
$NC = [ConsoleColor]::White
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
$resourcePrefix = $env:AZURE_RESOURCE_TOKEN

write-host "Use ACA: $useACA"
write-host "Use AKS: $useAKS"
write-host "Use MCP: $useMCP"

if ($useAKS) {

    #you need to install openssl
    #choco install openssl -y

    if ($env:GENERATE_SSL_CERT -eq "true")
    {
        $hostname = "$($resourcePrefix).com"

        write-host "Creating TLS certs for $hostname" -ForegroundColor $YELLOW

        $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"

        $password = read-host "Enter password for the pfx file" -AsSecureString -default "password"

        # Need to generate the TLS certs for the AKS cluster
        openssl req -new -x509 -nodes -out tls.crt -keyout tls.key -subj "/CN=$hostName" -addext "subjectAltName=DNS:$hostName" -passout "pass:$password"
        openssl pkcs12 -export -in tls.crt -inkey tls.key -out tls.pfx -passout "pass:$password"

        $keyVaultName = "kv-$($resourcePrefix)"

        write-host "Uploading TLS certs to Azure Key Vault - $keyvaultName" -ForegroundColor $YELLOW
        
        #upload to azure key vault
        az keyvault certificate import --vault-name $keyVaultName --name "gptrag-tls" --file 'tls.pfx' --password $password

        #$KEYVAULTID=$(az keyvault show --name $keyVaultName --resource-group $env:AZURE_RESOURCE_GROUP_NAME --query "id" --output tsv)
        #az aks approuting update --resource-group $env:AZURE_RESOURCE_GROUP_NAME --name "aks-$resourcePrefix-backend" --enable-kv --attach-kv $KEYVAULTID
    }
}

exit 0
