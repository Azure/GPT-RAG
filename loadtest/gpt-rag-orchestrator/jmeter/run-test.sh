#!/bin/bash

# Source the properties from the properties file
source runtest.properties

echo $subscription
echo $resourceGroup
echo $loadTestResource
echo $functionApp
echo $testId

az account set -s $subscription # ...or use 'az login'
az configure --defaults group=$resourceGroup

# Create a resource (will be created manually or by bicep script)
# az load create --name $loadTestResource --location $location

# Create a test with Load Test config YAML file
loadTestConfig="config.yaml"
az load test create --load-test-resource  $loadTestResource --test-id $testId --load-test-config-file $loadTestConfig --display-name "Enterprise RAG Load Test" --description "Enterprise RAG Load Test" 

# Add an app component
az load test app-component add --load-test-resource  $loadTestResource --test-id $testId --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --app-component-name "demo-podcastwebapp"

# Create a server metric for the app component
az load test server-metric add --load-test-resource $loadTestResource --test-id $testId --metric-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp/providers/microsoft.insights/metricdefinitions/Http4xx" --metric-name "Http4xx" --metric-namespace "Microsoft.Web/sites" --app-component-id "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionApp" --app-component-type "Microsoft.Web/sites" --aggregation "Average"

# Run the test
testRunId="run_"`date +"%Y%m%d%_H%M%S"`
displayName="Run"`date +"%Y/%m/%d_%H:%M:%S"`

az load test-run create --load-test-resource $loadTestResource --test-id $testId --test-run-id $testRunId --display-name $displayName --description "Test run from CLI"

# Download results
# az load test-run download-files --load-test-resource $loadTestResource --test-run-id $testRunId --path "Results" --result --force