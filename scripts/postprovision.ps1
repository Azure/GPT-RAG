$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Blue
$NC = [ConsoleColor]::White

$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$tenantId = $env:AZURE_TENANT_ID

# Creating a new RAI policy and attaching to deployed OpenAI model.
$aoaiResourceName = $env:AZURE_OPENAI_SERVICE_NAME
$aoaiModelName = $env:AZURE_CHAT_GPT_DEPLOYMENT_NAME

# Check conditions
# RAI script: AOAI content filters
$RAIscript = Join-Path -Path $PSScriptRoot -ChildPath 'rai\raipolicies.ps1'
& $RAIscript -Tenant $tenantId -Subscription $subscriptionId -ResourceGroup $resourceGroupName -AoaiResourceName $aoaiResourceName -AoaiModelName $aoaiModelName -RaiPolicyName 'MainRAIpolicy' -RaiBlocklistName 'MainBlockListPolicy'

$useACA = $env:AZURE_USE_ACA
$useAKS = $env:AZURE_USE_AKS

write-host $useACA
write-host $useAKS

# Build the container images
if ($useACA -eq "true" -or $useAKS -eq "true") {
    Write-Host "Building container images..." -ForegroundColor $YELLOW

    $ContainerRegistryName = "cr$env:AZURE_RESOURCE_TOKEN.azurecr.io"

    az acr login --name $ContainerRegistryName --resource-group $resourceGroupName
    
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-frontend\Dockerfile'
    $dockerContextPath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-frontend'
    $imageName = "$($containerRegistryName)/gpt-rag-frontend"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-ingestion\Dockerfile'
    $dockerContextPath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-ingestion'
    $imageName = "$($containerRegistryName)/gpt-rag-ingestion"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName

    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-orchestrator\Dockerfile'
    $dockerContextPath = Join-Path -Path $PSScriptRoot -ChildPath '.\.azure\gpt-rag-orchestrator'
    $imageName = "$($containerRegistryName)/gpt-rag-orchestrator"
    Write-Host "Building image: $imageName" -ForegroundColor $YELLOW
    docker build -t $imageName -f $dockerfilePath $dockerContextPath
    docker push $imageName
}

# Set the ACA container images
if ($useACA -eq "true") {
    
    $acrLogin = $(az acr show --name $ContainerRegistryName --resource-group $resourceGroupName -o json | ConvertFrom-Json).loginServer

    $acaImage = $env:AZURE_ACA_IMAGE_NAME
    $acaTag = $env:AZURE_ACA_IMAGE_TAG
    $AzureContainerImageName = "gpt-rag-orchestrator:latest"
    $acaImageName = "$($acrLogin)/$AzureContainerImageName"
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-orch-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName

    $acaImage = $env:AZURE_ACA_IMAGE_NAME
    $acaTag = $env:AZURE_ACA_IMAGE_TAG
    $AzureContainerImageName = "gpt-rag-frontend:latest"
    $acaImageName = "$($acrLogin)/$AzureContainerImageName"
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-web-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName

    $acaImage = $env:AZURE_ACA_IMAGE_NAME
    $acaTag = $env:AZURE_ACA_IMAGE_TAG
    $AzureContainerImageName = "gpt-rag-ingestion:latest"
    $acaImageName = "https://$($acrLogin)/$AzureContainerImageName"
    Write-Host "Setting ACA image to $acaImageName" -ForegroundColor $YELLOW
    $AZURE_ACA_NAME = "ca-ing-$env:AZURE_RESOURCE_TOKEN"
    az containerapp update --name $AZURE_ACA_NAME --resource-group $resourceGroupName --image $acaImageName
}

# Set the AKS deployment images
if ($useAKS -eq "true") {
    $azureAksClusterName = "aks-$($env:AZURE_RESOURCE_TOKEN)-backend"
    az aks install-cli
    az aks get-credentials --resource-group $resourceGroupName --name $azureAksClusterName

    kubectl create namespace gptrag
    
    kubectl apply -f web.yaml
    kubectl apply -f ingestion.yaml
    kubectl apply -f orchestration.yaml
}

if ($env:AZURE_ZERO_TRUST -eq "FALSE") {
    exit 0
}

Write-Host "For accessing the Zero Trust infrastructure, from the Azure Portal:"
Write-Host "Virtual Machine: $($env:AZURE_VM_NAME)"
Write-Host "Select connect using Bastion with:"
Write-Host "  username: $($env:AZURE_VM_USER_NAME)"
Write-Host "  Key Vault/Secret: $($env:AZURE_BASTION_KV_NAME)/$($env:AZURE_VM_KV_SEC_NAME)"