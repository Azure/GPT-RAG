#!/bin/sh

## Provides a head's up to user for AZURE_NETWORK_ISOLATION

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ "$AZURE_ZERO_TRUST" = "FALSE" ]; then
    exit 0
fi

echo "For accesing the ${YELLOW}Zero Trust infrastructure${NC}, from the Azure Portal:"
echo "Virtual Machine: ${BLUE}$AZURE_VM_NAME${NC}"
echo "Select connect using Bastion with:"
echo "  username: $AZURE_VM_USERNAME"
echo "  Key Vault/Secret: ${BLUE}$AZURE_VM_KV_NAME${NC}/${BLUE}$AZURE_VM_KV_SEC_NAME${NC}"
