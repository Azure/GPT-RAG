#!/bin/bash

# Parameters
Tenant="$1"
Subscription="$2"
ResourceGroup="$3"
AoaiResourceName="$4"
AoaiModelName="$5"
RaiPolicyName="$6"
RaiBlocklistName="$7"

echo "RAI Script: Setting up AOAI content filters & blocklist"

# Get access token
token=$(az account get-access-token --tenant "$Tenant" --query accessToken --output tsv)

# Set headers
headers=(
    "Authorization: Bearer $token"
    "Content-Type: application/json"
)

baseURI="https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# Creating a blocklist for AOAI account
filePath="$PWD/raiblocklist.json"
blocklistJson=$(cat "$filePath" | sed "s/{{BlocklistName}}/$RaiBlocklistName/g")

blocklistName=$(echo "$blocklistJson" | grep -oP '"blocklistname":"\K[^"]+')
blocklistItems=$(echo "$blocklistJson" | grep -oP '"blocklistItems":\[\K.*\]' | sed 's/},{/\n/g')

blocklistDescription="$blocklistName blocklist policy"
blocklistBody="{\"properties\": {\"description\": \"$blocklistDescription\"}}"

blocklistURI="$baseURI/raiBlocklists/$blocklistName?api-version=2023-10-01-preview"
curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -o /dev/null -d "$blocklistBody" "$blocklistURI"

blocklistItemsURI="$baseURI/raiBlocklists/$blocklistName/raiBlocklistItems/${blocklistName}Items?api-version=2023-10-01-preview"

# Remove previous items from blocklist
# - This covers scenario where blocklist items get updated in existing deployment
while true; do
    response=$(curl -s -X DELETE -H "${headers[0]}" -H "${headers[1]}" -o /dev/null -w "%{http_code}" "$blocklistItemsURI")

    if [[ "$response" != 2* ]]; then
        break
    fi
done

# Add items into blocklist
for item in $blocklistItems; do
    pattern=$(echo $item | grep -oP '"pattern":"\K[^"]+')
    isRegex=$(echo $item | grep -oP '"isRegex":\K[^"]+')

    blocklistItemsBody="{\"properties\": {\"pattern\": \"$pattern\", \"isRegex\": $isRegex}}"

    curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -o /dev/null -d "$blocklistItemsBody" "$blocklistItemsURI"
done

# Create content filter policy for AOAI account
filePath="$PWD/raipolicies.json"
policyBody=$(cat "$filePath" | sed "s/{{PolicyName}}/$RaiPolicyName/" | sed "s/{{BlocklistName}}/$RaiBlocklistName/")
policyURI="$baseURI/raiPolicies/$RaiPolicyName?api-version=2023-10-01-preview"
curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -d "$policyBody" -o /dev/null "$policyURI"

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

curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -o /dev/null -d "$updatedModel" "$modelURI"