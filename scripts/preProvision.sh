#!/bin/sh

## Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

###############################################################################
# Initialize infrastructure submodule
###############################################################################
echo "${CYAN}Initializing infrastructure submodule...${NC}"
git submodule update --init --recursive
if [ $? -ne 0 ]; then
    echo "${YELLOW}Warning: Failed to initialize submodule. If infra folder is empty, provisioning will fail.${NC}"
fi

###############################################################################
# Override submodule files with project-level overrides
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
INFRA_DIR="$PROJECT_ROOT/infra"

for FILE_NAME in manifest.json main.parameters.json; do
    SRC="$PROJECT_ROOT/$FILE_NAME"
    DST="$INFRA_DIR/$FILE_NAME"
    if [ -f "$SRC" ]; then
        echo "${CYAN}Applying project $FILE_NAME to infra...${NC}"
        cp -f "$SRC" "$DST"
    fi
done

###############################################################################
# 1) Network Isolation Warning
###############################################################################

# Skip warning if AZURE_SKIP_NETWORK_ISOLATION_WARNING is set
if [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" -ge 1 ] 2>/dev/null || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "true" ] || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "t" ]; then
    exit 0
fi

# Show warning if AZURE_NETWORK_ISOLATION is enabled
if [ "$AZURE_NETWORK_ISOLATION" -ge 1 ] 2>/dev/null || [ "$AZURE_NETWORK_ISOLATION" = "true" ] || [ "$AZURE_NETWORK_ISOLATION" = "t" ]; then
    
    echo "${YELLOW}Warning!${NC} AZURE_NETWORK_ISOLATION is enabled."
    echo " - After provisioning, you must switch to the ${GREEN}Virtual Machine & Bastion${NC} to continue deploying components."
    echo " - Infrastructure will only be reachable from within the Bastion host."

    echo -n "${BLUE}?${NC} Continue with Zero Trust provisioning? [Y/n]: "
    read confirmation

    if [ "$confirmation" != "Y" ] && [ "$confirmation" != "y" ] && [ -n "$confirmation" ]; then
        exit 1
    fi
fi

exit 0
