#Register Azure Providers
# Ensure the Azure PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
}

# Import the Azure PowerShell module
Import-Module Az

# Connect to Azure account
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Register Azure providers
$providers = @(
    "Microsoft.AlertsManagement",
    "Microsoft.App",
    "Microsoft.AppConfiguration",
    "Microsoft.ContainerService",
    "Microsoft.Compute",
    "Microsoft.ContainerRegistry",
    "Microsoft.DocumentDB",
    "Microsoft.KeyVault",
    "Microsoft.Insights",
    "Microsoft.Network",
    "Microsoft.Search",
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.Web"
)

foreach ($provider in $providers) {
    if (-not (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue)) {
        Write-Host "Registering provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider
    } else {
        Write-Host "Provider already registered: $provider"
    }
}


# Register Azure providers features
Register-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"