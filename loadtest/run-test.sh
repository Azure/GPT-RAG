#!/bin/bash

# Source the properties from the properties file
source runtest.properties

echo $testId
echo $subscription
echo $resourceGroup
echo $loadTestResource
echo $appServicePlanName
echo $functionApp
echo $aoaiResourceName
echo $cosmosDbResourceName



az account set -s $subscription # ...or use 'az login'
az configure --defaults group=$resourceGroup

# Create a resource (will be created manually or by bicep script)
# az load create --name $loadTestResource --location $location

# Create a test with Load Test config YAML file
echo "Creating a test with Load Test config YAML file"
loadTestConfig="config.yaml"
az load test create --load-test-resource  $loadTestResource --test-id $testId --load-test-config-file $loadTestConfig --display-name "Enterprise RAG Load Test" --description "Enterprise RAG Load Test"

# Add App Service Plan
# echo "Adding an App Service Plan app component"
# az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/serverFarms/appplan0-rzv57w6bdxevi" --app-component-type "Microsoft.Web/serverFarms" --app-component-name "$appServicePlanName"

# Add Function App component
echo "Adding an app component"
az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --app-component-name "$functionApp"

# Add an OpenAI Service app component
echo "Adding an OpenAI Service app component"
az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/oai0-rzv57w6bdxevi" --app-component-type "Microsoft.CognitiveServices/accounts" --app-component-name "$aoaiResourceName"

Add a Cosmos DB account app component
echo "Adding a Cosmos DB account app component"
az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.DocumentDB/databaseAccounts/dbgpt0-rzv57w6bdxevi" --app-component-type "Microsoft.DocumentDB/databaseAccounts" --app-component-name "$cosmosDbResourceName"

# Create a server metric for the functionApp component
# echo "Creating a server metric for the function app component"
# az load test server-metric add --load-test-resource $loadTestResource --test-id $testId --metric-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp/providers/microsoft.insights/metricdefinitions/Http4xx" --metric-name "Http4xx" --metric-namespace "Microsoft.Web/sites" --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --aggregation "Sum"

# # Create a server metric for the TotalRequests of the Azure OpenAI service
# echo "Creating a server metric for the TotalRequests of the Azure OpenAI service"
# az load test server-metric add --load-test-resource $loadTestResource --test-id $testId --metric-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/oai0-rzv57w6bdxevi/providers/microsoft.insights/metricdefinitions/TotalRequests" --metric-name "TotalRequests" --metric-namespace "Microsoft.CognitiveServices/accounts" --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/oai0-rzv57w6bdxevi" --app-component-type "Microsoft.CognitiveServices/accounts" --aggregation "Sum"

# Run the test
echo "Running the test"
testRunId=`date +"%Y%m%d%H%M%S"`
echo $testRunId
displayName=`date +"%Y/%m/%d_%H:%M:%S"`
command="az load test-run create --load-test-resource $loadTestResource --test-id $testId --test-run-id $testRunId --display-name $displayName --description 'Automated test run from CLI'"
echo $command
eval $command
# az load test-run create --load-test-resource $loadTestResource --test-id $testId --test-run-id $testRunId --display-name $displayName --description "Automated test run from CLI"

# # Check test run status
# sleep 60  # wait for 60 seconds before checking again
# status=$(az load test-run show --load-test-resource $loadTestResource --test-run-id $testRunId --query status -o tsv)
# echo "Current status: $status"
# while [ "$status" == "InProgress" ]
# do
#     echo "Waiting for test run to complete..."
#     sleep 60  # wait for 60 seconds before checking again
#     status=$(az load test-run show --load-test-resource $loadTestResource --test-run-id $testRunId --query status -o tsv)
#     echo "Current status: $status"
# done

# Download results
sleep 60  # wait for 60 seconds before checking again
echo "Downloading results"
az load test-run download-files --load-test-resource $loadTestResource --test-run-id $testRunId --path "results" --result --force