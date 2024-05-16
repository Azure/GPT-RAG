#!/bin/bash

# Parameters
Tenant="$1"
Subscription="$2"
ResourceGroup="$3"
AoaiResourceName="$4"
AoaiModelName="$5"
RaiPolicyName="$6"

echo "RAI Script: Setting up AOAI content filter"

# Get access token
token=$(az account get-access-token --tenant "$Tenant" --query accessToken --output tsv)

# Set headers
headers=(
    "Authorization: Bearer $token"
    "Content-Type: application/json"
)

baseURI="https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# Create content filter policy for AOAI account
filePath="$PWD/raipolicies.json"
policyBody=$(cat "$filePath" | sed "s/{{PolicyName}}/$RaiPolicyName/")
policyURI="$baseURI/raiPolicies/$RaiPolicyName?api-version=2023-10-01-preview"

echo "Policy Body: $policyBody"
curl -X PUT -H "${headers[0]}" -H "${headers[1]}" -d "$policyBody" "$policyURI"

# Get deployed AOAI model profile
modelURI="$baseURI/deployments/$AoaiModelName?api-version=2023-10-01-preview"
modelDeployments=$(curl -s -H "${headers[0]}" "$modelURI")
echo ""; echo ""; "Model Deployments: $modelDeployments"

# Extract the model object
while read -r line; do
    if [[ "$line" == *"$AoaiModelName"* ]]; then
        model="$line"
        break
    fi
done <<< "$modelDeployments"

# echo ""; echo ""; echo "Model: $model"
modelSkuName=$(echo "$model" | grep -oP '"sku":\{"name":"\K[^"]+')
modelSkuCapacity=$(echo "$model" | grep -oP '"sku":\{"name":"[^"]+","capacity":\K\d+')
modelFormat=$(echo "$model" | grep -oP '"model":\{"format":"\K[^"]+')
modelName=$(echo "$model" | grep -oP '"model":\{"format":"[^"]+","name":"\K[^"]+')
modelVersion=$(echo "$model" | grep -oP '"model":\{"format":"[^"]+","name":"[^"]+","version":"\K[^"]+')
modelVUpgOps=$(echo "$model" | grep -oP '"versionUpgradeOption":"\K[^"]+')

updatedModel=$(printf '{
    "displayName": "%s",
    "sku": {
        "name": "%s",
        "capacity": "%s"
    },
    "properties": {
        "model": {
            "format": "%s",
            "name": "%s",
            "version": "%s"
        },
        "versionUpgradeOption": "%s",
        "raiPolicyName": "%s"
    }
}' "$AoaiModelName" "$modelSkuName" "$modelSkuCapacity" "$modelFormat" "$modelName" "$modelVersion" "$modelVUpgOps" "$RaiPolicyName")

echo ""; echo ""; "Updated Model: $updatedModel"
curl -X PUT -H "${headers[0]}" -H "${headers[1]}" -d "$updatedModel" "$modelURI"