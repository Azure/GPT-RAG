#!/bin/sh

# Parameters
Tenant="$1"
Subscription="$2"
ResourceGroup="$3"
AoaiResourceName="$4"
AoaiModelName="$5"
RaiPolicyName="$6"

echo "RAI Script: Setting up AOAI content filter"

# Check if jq is installed using different package managers
if ! command -v jq &> /dev/null; then
    echo "jq is not found. Attempting installation..."
    # Check if apt-get is available (Debian/Ubuntu)
    if command -v apt-get &> /dev/null; then
        sudo apt-get install jq
    elif command -v yum &> /dev/null; then
        # Check if yum is available (CentOS/RHEL)
        sudo yum install jq
    elif command -v brew &> /dev/null; then
        # Check if brew is available (macOS)
        brew install jq
    else
        echo "Unsupported package manager. Please install jq manually."
        exit 1
    fi
fi

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
curl -X PUT -H "${headers[0]}" -H "${headers[1]}" -d "$policyBody" "$policyURI"

# Get deployed AOAI model profile
modelURI="$baseURI/deployments/$AoaiModelName?api-version=2023-10-01-preview"
modelDeployments=$(curl -s -H "${headers[0]}" "$modelURI")

# Extract the model object
while read -r line; do
    if [[ "$line" == *"$AoaiModelName"* ]]; then
        model="$line"
        break
    fi
done <<< "$modelDeployments"

modelSkuName=$(jq '.sku.name' <<< "$model" | tr -d '\"')
modelSkuCapacity=$(jq '.sku.capacity' <<< "$model" | tr -d '\"')
modelFormat=$(jq '.properties.model.format' <<< "$model" | tr -d '\"')
modelName=$(jq '.properties.model.name' <<< "$model" | tr -d '\"')
modelVersion=$(jq '.properties.model.version' <<< "$model" | tr -d '\"')
modelVUpgOps=$(jq '.properties.versionUpgradeOption' <<< "$model" | tr -d '\"')

# Assign created policy to model profile
updatedModel=$(jq -n --arg displayName "$AoaiModelName" \
                    --arg skuName "$modelSkuName" \
                    --arg skuCapacity "$modelSkuCapacity" \
                    --arg modelFormat "$modelFormat" \
                    --arg modelName "$modelName" \
                    --arg modelVersion "$modelVersion" \
                    --arg versionUpgradeOption "$modelVUpgOps" \
                    --arg raiPolicyName "$RaiPolicyName" \
                    '{displayName: $displayName, sku: {name: $skuName, capacity: $skuCapacity}, properties: {model: {format: $modelFormat, name: $modelName, version: $modelVersion}, versionUpgradeOption: $versionUpgradeOption, raiPolicyName: $raiPolicyName}}')

curl -X PUT -H "${headers[0]}" -H "${headers[1]}" -d "$updatedModel" "$modelURI"
