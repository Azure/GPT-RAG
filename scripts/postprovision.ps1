$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Blue
$NC = [ConsoleColor]::White

$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$tenantId = $env:AZURE_TENANT_ID

# Creating a new RAI policy and attaching to deployed OpenAI model.
$aoaiResourceName = $env:AZURE_OPENAI_SERVICE_NAME
$aoaiModelName = $env:AZURE_CHAT_GPT_DEPLOYMENT_NAME

write-host "Running from path : $PSScriptRoot" -ForegroundColor $YELLOW

$repoPath = $PSScriptRoot.replace("\scripts","")
write-host "Repo path: $repoPath" -ForegroundColor $YELLOW

# Check conditions
# RAI script: AOAI content filters
$RAIscript = Join-Path -Path $PSScriptRoot -ChildPath 'rai\raipolicies.ps1'
& $RAIscript -Tenant $tenantId -Subscription $subscriptionId -ResourceGroup $resourceGroupName -AoaiResourceName $aoaiResourceName -AoaiModelName $aoaiModelName -RaiPolicyName 'MainRAIpolicy' -RaiBlocklistName 'MainBlockListPolicy'

$useACA = $env:AZURE_USE_ACA
$useAKS = $env:AZURE_USE_AKS
$useMCP = $env:AZURE_USE_MCP

write-host "Use ACA: $useACA"
write-host "Use AKS: $useAKS"
write-host "Use MCP: $useMCP"

# Build the container images
if ($useACA -eq "true" -or $useAKS -eq "true") {

    #run the /scripts/fetchComponents.ps1 script to fetch the components
    $fetchScript = Join-Path -Path $PSScriptRoot -ChildPath 'fetchComponents.ps1'
    & $fetchScript

    Write-Host "Building container images..." -ForegroundColor $YELLOW

    $ContainerRegistryName = "cr$env:AZURE_RESOURCE_TOKEN.azurecr.io"

    az acr login --name $ContainerRegistryName --resource-group $resourceGroupName
    
    $dockerfilePath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-frontend\Dockerfile'
    $dockerContextPath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-frontend'
    $imageName = "$($containerRegistryName)/gpt-rag-frontend"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    $dockerfilePath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-ingestion\Dockerfile'
    $dockerContextPath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-ingestion'
    $imageName = "$($containerRegistryName)/gpt-rag-ingestion"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    $dockerfilePath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-orchestrator\Dockerfile'
    $dockerContextPath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-orchestrator'
    $imageName = "$($containerRegistryName)/gpt-rag-orchestrator"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    $dockerfilePath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-agentic\Dockerfile'
    $dockerContextPath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-agentic'
    $imageName = "$($containerRegistryName)/gpt-rag-agentic"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    if ($useMCP -eq "true")
    {
        $dockerfilePath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-mcp\Dockerfile'
        $dockerContextPath = Join-Path -Path $repoPath -ChildPath '.\.azure\gpt-rag-mcp'
        $imageName = "$($containerRegistryName)/gpt-rag-mcp"
        Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
        docker build -t $imageName -f $dockerfilePath $dockerContextPath
        docker push $imageName
    }
}

# Set the ACA container images
if ($useACA -eq "true") {
    
    $acrLogin = $(az acr show --name $ContainerRegistryName --resource-group $resourceGroupName -o json | ConvertFrom-Json).loginServer

    if ($env:REPOSITORY_URL)
    {
        $acrLogin = $env:REPOSITORY_URL
    }

    $AzureContainerImageName = "gpt-rag-orchestrator:latest"
    $acaImageName = "$($acrLogin)/$AzureContainerImageName".replace("https://", "")
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-orch-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName

    $AzureContainerImageName = "gpt-rag-frontend:latest"
    $acaImageName = "$($acrLogin)/$AzureContainerImageName".replace("https://", "")
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-web-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName

    $AzureContainerImageName = "gpt-rag-ingestion:latest"
    $acaImageName = "https://$($acrLogin)/$AzureContainerImageName".replace("https://", "")
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-ing-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName

    if ($useMCP -eq "true")
    {
        $AzureContainerImageName = "gpt-rag-mcp:latest"
        $acaImageName = "https://$($acrLogin)/$AzureContainerImageName".replace("https://", "")
        Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
        $AZURE_ACA_NAME = "ca-mcp-$env:AZURE_RESOURCE_TOKEN"
        az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName
    }
}

if ($useAKS -eq "true") {
    $azureAksClusterName = "aks-$($env:AZURE_RESOURCE_TOKEN)-backend"
    az aks install-cli
    az aks get-credentials --resource-group $resourceGroupName --name $azureAksClusterName

    az aks update --name $azureAksClusterName --resource-group $resourceGroupName --attach-acr "cr$($env:AZURE_RESOURCE_TOKEN)"

    #Install KEDA
    if ($env:INSTALL_KEDA -eq "true")
    {
        kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.17.0/keda-2.17.0.yaml
    }

    #https://learn.microsoft.com/en-us/azure/aks/custom-certificate-authority
    #add the custom CA certificate to the AKS cluster
    az aks update --resource-group $resourceGroupName --name $azureAksClusterName --custom-ca-trust-certificates 'tls.crt'

    #https://learn.microsoft.com/en-us/azure/aks/app-routing-dns-ssl
    $ZONEID=$(az network private-dns zone show --resource-group $resourceGroupName --name "$($env:AZURE_RESOURCE_TOKEN)$(".com")" --query "id" --output tsv)
    az aks approuting zone add --resource-group $resourceGroupName --name "aks-$env:AZURE_RESOURCE_TOKEN-backend" --ids=$ZONEID --attach-zones
}

if ($env:AZURE_ZERO_TRUST -eq "FALSE") {
    exit 0
}

Write-Host "For accessing the Zero Trust infrastructure, from the Azure Portal:"
Write-Host "Virtual Machine: $($env:AZURE_VM_NAME)"
Write-Host "Select connect using Bastion with:"
Write-Host "  username: $($env:AZURE_VM_USER_NAME)"
Write-Host "  Key Vault/Secret: $($env:AZURE_BASTION_KV_NAME)/$($env:AZURE_VM_KV_SEC_NAME)"