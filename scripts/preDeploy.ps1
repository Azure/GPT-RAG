if ($env:AZURE_ZERO_TRUST -eq "TRUE") {
    # Prompt for user confirmation
    $confirmation = Read-Host -Prompt "Zero Trust Infrastructure enabled. Confirm you are using a connection where resources are reachable (like VM+Bastion)? [Y/n]"

    # Check if the confirmation is positive
    if ($confirmation -ne "Y" -and $confirmation -ne "y" -and $confirmation) {
        exit 1
    }
    exit 0
}

if ($env:AZURE_USE_AKS -eq "TRUE") {
    #run the script
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'deploy\aks\scripts\deploy-aks.ps1'
    $scriptPath = Resolve-Path $scriptPath
    Write-Host "Running deploy-aks script: $scriptPath" -ForegroundColor $YELLOW

    $secretProviderClassManifest = Resolve-Path "../config/kubernetes/spc.foundationallm-certificates.backend.yml"
    $ingressNginxValues = Resolve-Path "../config/helm/ingress-nginx.values.backend.yml"
    $env:AZURE_VERSION = "1.0.0"

    & $scriptPath -aksName $env:AZURE_AKS_NAME -resourceGroup $env:AZURE_RESOURCE_GROUP -ingressNginxValues $ingressNginxValues -secretProviderClassManifest $secretProviderClassManifest -serviceNamespace $env:AZURE_SERVICE_NAMESPACE -registry $env:AZURE_CONTAINER_REGISTRY -version $env:AZURE_VERSION
}