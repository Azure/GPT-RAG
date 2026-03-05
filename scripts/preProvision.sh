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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
INFRA_DIR="$PROJECT_ROOT/infra"
MAIN_BICEP="$INFRA_DIR/main.bicep"

echo "${CYAN}Initializing infrastructure submodule...${NC}"
git submodule update --init --recursive 2>/dev/null

# Fallback: when the repo was scaffolded via 'azd init' (ZIP download), the git
# index has no submodule gitlink entries, so 'git submodule update' silently does
# nothing and infra/ remains empty.  Detect that case and clone the landing-zone
# repo directly.
if [ ! -f "$MAIN_BICEP" ]; then
    echo "${CYAN}Submodule content not found. Cloning infra repo directly (azd init scenario)...${NC}"

    # Extract infra repo URL and branch from .gitmodules
    GITMODULES="$PROJECT_ROOT/.gitmodules"
    INFRA_URL=""
    INFRA_REF="main"  # safe default
    if [ -f "$GITMODULES" ]; then
        INFRA_URL=$(grep -m1 'url\s*=' "$GITMODULES" | sed 's/.*=\s*//' | xargs)
        BRANCH=$(grep -m1 'branch\s*=' "$GITMODULES" | sed 's/.*=\s*//' | xargs)
        if [ -n "$BRANCH" ]; then
            INFRA_REF="$BRANCH"
        fi
    fi
    if [ -z "$INFRA_URL" ]; then
        echo "${YELLOW}Error: Could not determine infra repository URL from .gitmodules.${NC}"
        exit 1
    fi
    echo "${CYAN}  Infra repo: $INFRA_URL @ $INFRA_REF (from .gitmodules)${NC}"

    # Remove the empty infra directory and clone at the correct tag
    rm -rf "$INFRA_DIR"
    git clone --depth 1 --branch "$INFRA_REF" "$INFRA_URL" "$INFRA_DIR"
    if [ $? -ne 0 ]; then
        echo "${YELLOW}Error: Failed to clone infra repository ($INFRA_URL @ $INFRA_REF).${NC}"
        exit 1
    fi
    echo "${GREEN}Infrastructure submodule cloned successfully.${NC}"
fi

###############################################################################
# Override submodule files with project-level overrides
###############################################################################

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
