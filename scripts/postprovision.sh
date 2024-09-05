#!/bin/sh

## Provides a head's up to user for AZURE_NETWORK_ISOLATION

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

resourceGroupName="$AZURE_RESOURCE_GROUP_NAME"
subscriptionId="$AZURE_SUBSCRIPTION_ID"
tenantId="$AZURE_TENANT_ID"

# Creating a new RAI policy and attaching to deployed OpenAI model.
aoaiResourceName="$AZURE_OPENAI_SERVICE_NAME"
aoaiModelName="$AZURE_CHAT_GPT_DEPLOYMENT_NAME"

# Extract values without jq
deployDataIngestion=$(echo $AZURE_COMPONENT_CONFIG | grep -o '"deployDataIngestion":"[^"]*' | grep -o '[^"]*$')
deployOrchestrator=$(echo $AZURE_COMPONENT_CONFIG | grep -o '"deployOrchestrator":"[^"]*' | grep -o '[^"]*$')

# RAI script: AOAI content filters
cd $PWD/scripts/rai
./raipolicies.sh $tenantId $subscriptionId $resourceGroupName $aoaiResourceName $aoaiModelName "MainRAIpolicy" "MainBlockListPolicy"

if [ "$AZURE_ZERO_TRUST" = "FALSE" ]; then
    exit 0
fi

echo "For accessing the ${YELLOW}Zero Trust infrastructure${NC}, from the Azure Portal:"
echo "Virtual Machine: ${BLUE}$AZURE_VM_NAME${NC}"
echo "Select connect using Bastion with:"
echo "  username: $AZURE_VM_USERNAME"
echo "  Key Vault/Secret: ${BLUE}$AZURE_BASTION_KV_NAME${NC}/${BLUE}$AZURE_VM_KV_SEC_NAME${NC}"
