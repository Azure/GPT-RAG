#!/bin/sh

## Provides a head's up to user for AZURE_NETWORK_ISOLATION

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if AZURE_NETWORK_ISOLATION environment variable is defined
if [ -z "$AZURE_NETWORK_ISOLATION" ]; then
    exit 0
fi

# AZURE_SKIP_NETWORK_ISOLATION_WARNING explicit no-warning requested
if [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" -ge 1 ] 2>/dev/null || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "true" ] || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "t" ]; then
    exit 0
fi

# Check if AZURE_NETWORK_ISOLATION environment variable is set to a positive value
if [ "$AZURE_NETWORK_ISOLATION" -ge 1 ] 2>/dev/null || [ "$AZURE_NETWORK_ISOLATION" = "true" ] || [ "$AZURE_NETWORK_ISOLATION" = "t" ]; then
    
    # Display a heads up warning
    echo "${YELLOW}Warning!${NC} AZURE_NETWORK_ISOLATION is set."
    echo " - After provisioning, you need to switch to the ${GREEN}VirtualMachine & Bastion${NC} to continue deploying components."
    echo " - Infrastucture will be only reachable from within the Bastion host."

    # Prompt for user confirmation
    echo -n "${BLUE}?${NC} Continue with Zero Trust provisioning? [Y/n]: "
    read confirmation

    # Check if the confirmation is positive
    if [ "$confirmation" != "Y" ] && [ "$confirmation" != "y" ] && [ -n "$confirmation" ]; then
        exit 1
    fi
fi

exit 0
