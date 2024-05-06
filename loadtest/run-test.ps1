# Define a function to parse a properties file
function Get-Properties {
    param (
        [string]$Path
    )

    $properties = @{}
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^#].+?)\s*=\s*(.+)\s*$') {
            $properties[$Matches[1]] = $Matches[2]
        }
    }

    return $properties
}

# Use the function to parse the properties file
$properties = Get-Properties '.\runtest.properties'

# Assign the properties to variables
$subscription = $properties['subscription']
$resourceGroup = $properties['resourceGroup']
$loadTestResource = $properties['loadTestResource']
$functionApp = $properties['functionApp']
$testId = $properties['testId']

# Output the variables
Write-Output "Subscription: $subscription"
Write-Output "Resource Group: $resourceGroup"
Write-Output "Load Test Resource: $loadTestResource"
Write-Output "Function App: $functionApp"
Write-Output "Test ID: $testId"

az login
#az account set -s $subscription

az configure --defaults group=$resourceGroup

# Assign the Managed Identity and get the principalId
#$identity = az webapp identity assign --name $functionApp --resource-group $resourceGroup | ConvertFrom-Json
#$principalId = $identity.principalId

# Set the Key Vault policy
#az keyvault set-policy --name kv0-qbjhjo73ax3bw --object-id $principalId --secret-permissions get list set delete recover backup restore


# Create a test with Load Test config YAML file
$loadTestConfig="config.yaml"
az load test create --load-test-resource  $loadTestResource --test-id $testId --load-test-config-file $loadTestConfig --display-name "GPT RAG Load Test" --description "Enterprise RAG Load Test"

# Add an app component
az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --app-component-name "demo-genaiwebapp"

# Create a server metric for the app component
az load test server-metric add --load-test-resource $loadTestResource --test-id $testId --metric-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp/providers/microsoft.insights/metricdefinitions/Http4xx" --metric-name "Http4xx" --metric-namespace "Microsoft.Web/sites" --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --aggregation "Average"

# Run the test
$testRunId="run_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$displayName="Run" + (Get-Date -Format "yyyy/MM/dd_HH:mm:ss")

az load test-run create --load-test-resource $loadTestResource --test-id $testId --test-run-id $testRunId --display-name $displayName --description "GPT-RAG load test run from CLI"

# Download results
# az load test-run download-files --load-test-resource $loadTestResource --test-run-id $testRunId --path "Results" --result --force