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
if [ -z "$token" ]; then
  echo "No access token found. Please follow the instructon below to log in to your Azure account."
  az login --use-device-code
fi

# Set headers
headers=(
    "Authorization: Bearer $token"
    "Content-Type: application/json"
)

baseURI="https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# Creating a blocklist for AOAI account
filePath="$PWD/raiblocklist.json"
blocklistJson=$(cat "$filePath" | sed "s/{{BlocklistName}}/$RaiBlocklistName/g")
blocklistName=$(echo "$blocklistJson" | awk -F'"' '/blocklistname/ {print $4}')

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

# Extract blocklistItems content using awk and sed
blocklistItems=$(echo "$blocklistJson" | awk '/"blocklistItems": \[/,/\]/' | sed '1d;$d')

# Extract individual patterns and isRegex values
patterns=$(echo "$blocklistItems" | grep '"pattern":' | sed 's/.*"pattern": "\(.*\)".*/\1/')
isRegexes=$(echo "$blocklistItems" | grep '"isRegex":' | sed 's/.*"isRegex": \(.*\)/\1/')

# Convert strings to arrays
IFS=$'\n' patternsArray=($patterns)
IFS=$'\n' isRegexesArray=($isRegexes)

# Loop through each item and add it to blocklist
for i in "${!patternsArray[@]}"; do
    pattern=${patternsArray[$i]}
    isRegex=${isRegexesArray[$i]}

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

# Extract the model object
while read -r line; do
    if [[ "$line" == *"$AoaiModelName"* ]]; then
        model="$line"
        break
    fi
done <<< "$modelDeployments"

modelSkuName=$(echo "$model" | sed -En 's/.*"sku":\{"name":"([^"]*).*/\1/p')
modelSkuCapacity=$(echo "$model" | sed -En 's/.*"sku":\{"name":"[^"]*","capacity":([0-9]*).*/\1/p')
modelFormat=$(echo "$model" | sed -En 's/.*"model":\{"format":"([^"]*).*/\1/p')
modelName=$(echo "$model" | sed -En 's/.*"model":\{"format":"[^"]*","name":"([^"]*).*/\1/p')
modelVersion=$(echo "$model" | sed -En 's/.*"model":\{"format":"[^"]*","name":"[^"]*","version":"([^"]*).*/\1/p')
modelVUpgOps=$(echo "$model" | sed -En 's/.*"versionUpgradeOption":"([^"]*).*/\1/p')

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