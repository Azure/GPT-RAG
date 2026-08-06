#!/bin/sh

## Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

###############################################################################
# Mirror azd environment variables into process environment
# This avoids persisting secrets in the User environment, and makes any
# previously-persisted GPT-RAG topology markers (AZURE_RESOURCE_GROUP,
# APP_CONFIG_ENDPOINT, DEPLOYMENT_TOPOLOGY, ...) visible to the topology
# resolution step below on a second/subsequent 'azd provision' run.
# 'azd env get-values' already emits POSIX-shell-safe KEY="value" lines, so
# eval'ing them directly (rather than piping into a subshell 'while read'
# loop, whose exports would not survive the pipe under POSIX sh) is safe.
###############################################################################
eval "$(azd env get-values 2>/dev/null | sed 's/^/export /')" || true

###############################################################################
# Initialize infrastructure submodule
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
INFRA_DIR="$PROJECT_ROOT/infra"
MAIN_BICEP="$INFRA_DIR/main.bicep"

PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "${YELLOW}Error: Python is required to resolve the infrastructure release pin.${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/manifest.json" ]; then
    echo "${YELLOW}Error: manifest.json is required to resolve the infrastructure release pin.${NC}"
    exit 1
fi
EXPECTED_INFRA_COMMIT="$("$PYTHON_CMD" -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["ailz_commit"])' "$PROJECT_ROOT/manifest.json")"
if ! printf '%s\n' "$EXPECTED_INFRA_COMMIT" | grep -Eq '^[0-9a-f]{40}$'; then
    echo "${YELLOW}Error: manifest.json must define ailz_commit as a lowercase 40-character Git SHA.${NC}"
    exit 1
fi

# Provisioning owns these generated infra overrides. Restore only those files,
# then fail closed if any unrelated submodule changes remain.
(cd "$PROJECT_ROOT" && "$PYTHON_CMD" -m config.deployment.infra_checkout --infra-dir "$INFRA_DIR")
INFRA_CHECKOUT_EXIT=$?
if [ $INFRA_CHECKOUT_EXIT -ne 0 ]; then
    exit $INFRA_CHECKOUT_EXIT
fi

echo "${CYAN}Initializing infrastructure submodule...${NC}"
git submodule update --init --recursive 2>/dev/null

# Fallback: when the repo was scaffolded via 'azd init' (ZIP download), the git
# index has no submodule gitlink entries, so 'git submodule update' silently does
# nothing and infra/ remains empty.  Detect that case and clone the landing-zone
# repo directly.
if [ ! -f "$MAIN_BICEP" ]; then
    echo "${CYAN}Submodule content not found. Cloning infra repo directly (azd init scenario)...${NC}"

    # Extract the infra repo URL from .gitmodules.
    GITMODULES="$PROJECT_ROOT/.gitmodules"
    INFRA_URL=""
    if [ -f "$GITMODULES" ]; then
        INFRA_URL=$(grep -m1 'url\s*=' "$GITMODULES" | sed 's/.*=\s*//' | xargs)
    fi
    if [ -z "$INFRA_URL" ]; then
        echo "${YELLOW}Error: Could not determine infra repository URL from .gitmodules.${NC}"
        exit 1
    fi
    echo "${CYAN}  Infra repo: $INFRA_URL @ $EXPECTED_INFRA_COMMIT (from manifest.json)${NC}"

    # Initialize only the repository metadata. The exact manifest commit is
    # fetched and checked out by the common path below.
    rm -rf "$INFRA_DIR"
    mkdir -p "$INFRA_DIR"
    if ! git -C "$INFRA_DIR" init --quiet; then
        echo "${YELLOW}Error: Failed to initialize infra repository ($INFRA_URL).${NC}"
        exit 1
    fi
    if ! git -C "$INFRA_DIR" remote add origin "$INFRA_URL"; then
        echo "${YELLOW}Error: Failed to configure infra repository origin ($INFRA_URL).${NC}"
        exit 1
    fi
fi

echo "${CYAN}Fetching exact infrastructure commit $EXPECTED_INFRA_COMMIT...${NC}"
if ! git -C "$INFRA_DIR" fetch --depth 1 origin "$EXPECTED_INFRA_COMMIT"; then
    echo "${YELLOW}Error: Failed to fetch infra commit $EXPECTED_INFRA_COMMIT.${NC}"
    exit 1
fi
if ! git -C "$INFRA_DIR" -c advice.detachedHead=false checkout --detach "$EXPECTED_INFRA_COMMIT"; then
    echo "${YELLOW}Error: Failed to check out infra commit $EXPECTED_INFRA_COMMIT.${NC}"
    exit 1
fi

###############################################################################
# Override submodule files with project-level overrides
###############################################################################

ACTUAL_INFRA_COMMIT="$(git -C "$INFRA_DIR" rev-parse HEAD 2>/dev/null || true)"
if [ -z "$EXPECTED_INFRA_COMMIT" ] || [ "$ACTUAL_INFRA_COMMIT" != "$EXPECTED_INFRA_COMMIT" ]; then
    echo "${YELLOW}Error: infra must resolve to $EXPECTED_INFRA_COMMIT but is at $ACTUAL_INFRA_COMMIT.${NC}"
    exit 1
fi

if [ -f "$PROJECT_ROOT/manifest.json" ]; then
    echo "${CYAN}Applying project manifest.json to infra...${NC}"
    cp -f "$PROJECT_ROOT/manifest.json" "$INFRA_DIR/manifest.json"
fi

###############################################################################
# ADR-0001 rev. 5: resolve and materialize the GPT-RAG deployment topology
###############################################################################
# Resolve the topology (fresh default, sticky existing/persisted-classic,
# explicit override, or a fail-closed error with migration guidance on
# conflicting persisted signals) before composing main.parameters.json.
# Materializing DEPLOYMENT_TOPOLOGY (and the paired legacy flags) into both
# the process environment and the azd environment here is what lets
# preDeploy/postProvision read back the exact same decision later via
# 'config.deployment.topology --describe', with no further Azure CLI lookups
# and no duplicated detection logic.
echo "${CYAN}Resolving GPT-RAG deployment topology...${NC}"
TOPOLOGY_OUTPUT="$(cd "$PROJECT_ROOT" && "$PYTHON_CMD" -m config.deployment.topology)"
TOPOLOGY_EXIT=$?
if [ $TOPOLOGY_EXIT -ne 0 ]; then
    echo "${YELLOW}Error: GPT-RAG deployment topology resolution failed.${NC}"
    exit $TOPOLOGY_EXIT
fi

eval "$(printf '%s\n' "$TOPOLOGY_OUTPUT" | sed 's/^\([^=]*\)=\(.*\)$/export \1="\2"/')"

TOPOLOGY_PERSIST_FAILED=false
while IFS='=' read -r TOPO_KEY TOPO_VALUE; do
    [ -z "$TOPO_KEY" ] && continue
    if [ -n "${AZURE_ENV_NAME:-}" ]; then
        if ! azd env set "$TOPO_KEY" "$TOPO_VALUE" --environment "$AZURE_ENV_NAME" --no-prompt >/dev/null; then
            TOPOLOGY_PERSIST_FAILED=true
            break
        fi
    else
        if ! azd env set "$TOPO_KEY" "$TOPO_VALUE" --no-prompt >/dev/null; then
            TOPOLOGY_PERSIST_FAILED=true
            break
        fi
    fi
done <<EOF
$TOPOLOGY_OUTPUT
EOF
if [ "$TOPOLOGY_PERSIST_FAILED" = "true" ]; then
    echo "${YELLOW}Error: Failed to persist the resolved deployment topology.${NC}"
    exit 1
fi

echo "${CYAN}Composing GPT-RAG deployment mode...${NC}"
HOSTED_SOURCE_COMMIT="$("$PYTHON_CMD" -c 'import json,sys; print(next(c[\"commit\"] for c in json.load(open(sys.argv[1], encoding=\"utf-8\"))[\"components\"] if c[\"name\"] == \"gpt-rag-orchestrator\"))' "$PROJECT_ROOT/manifest.json")"
(
    cd "$PROJECT_ROOT" &&
    "$PYTHON_CMD" -m config.deployment.composition \
        --input "$PROJECT_ROOT/main.parameters.json" \
        --output "$INFRA_DIR/main.parameters.json" \
        --hosted-source-commit "$HOSTED_SOURCE_COMMIT"
)
COMPOSE_EXIT=$?
if [ $COMPOSE_EXIT -ne 0 ]; then
    echo "${YELLOW}Error: GPT-RAG deployment mode composition failed.${NC}"
    exit $COMPOSE_EXIT
fi

###############################################################################
# GPT-RAG regional readiness preflight
###############################################################################

REGIONAL_PREFLIGHT_SCRIPT="$SCRIPT_DIR/Invoke-RegionalPreflight.ps1"
if [ -f "$REGIONAL_PREFLIGHT_SCRIPT" ] && [ "$PREFLIGHT_SKIP" != "true" ] && [ "$PREFLIGHT_SKIP" != "1" ] && [ "$GPT_RAG_REGIONAL_PREFLIGHT_SKIP" != "true" ] && [ "$GPT_RAG_REGIONAL_PREFLIGHT_SKIP" != "1" ]; then
    if command -v pwsh >/dev/null 2>&1; then
        echo "${CYAN}Running GPT-RAG regional preflight...${NC}"
        pwsh -NoProfile -File "$REGIONAL_PREFLIGHT_SCRIPT" -ProjectRoot "$PROJECT_ROOT" -ParameterFile "$INFRA_DIR/main.parameters.json"
        REGIONAL_PREFLIGHT_EXIT=$?
        if [ $REGIONAL_PREFLIGHT_EXIT -ne 0 ]; then
            echo "${YELLOW}GPT-RAG regional preflight failed. Fix the reported blockers, or set GPT_RAG_REGIONAL_PREFLIGHT_SKIP=true to bypass only this check.${NC}"
            exit $REGIONAL_PREFLIGHT_EXIT
        fi
    else
        echo "${CYAN}Skipping GPT-RAG regional preflight (pwsh not installed; install PowerShell 7 to enable).${NC}"
    fi
fi

###############################################################################
# AI Landing Zone v2.0.4+ preflight validation
# https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.4/scripts/Invoke-PreflightChecks.ps1
# Covers parameter/topology/BYO/IP checks plus regional readiness (subscription
# drift, provider/location, AI Search & Cosmos capacity warnings, jumpbox VM SKU,
# model quota).
###############################################################################

PREFLIGHT_SCRIPT="$INFRA_DIR/scripts/Invoke-PreflightChecks.ps1"
if [ -f "$PREFLIGHT_SCRIPT" ] && [ "$PREFLIGHT_SKIP" != "true" ] && [ "$PREFLIGHT_SKIP" != "1" ]; then
    if command -v pwsh >/dev/null 2>&1; then
        echo "${CYAN}Running landing-zone preflight checks...${NC}"
        pwsh -NoProfile -File "$PREFLIGHT_SCRIPT"
        PREFLIGHT_EXIT=$?
        if [ $PREFLIGHT_EXIT -ne 0 ]; then
            echo "${YELLOW}Preflight checks failed. Fix the reported parameter issues, or set PREFLIGHT_SKIP=true to bypass.${NC}"
            exit $PREFLIGHT_EXIT
        fi
    else
        echo "${CYAN}Skipping preflight checks (pwsh not installed; install PowerShell 7 to enable).${NC}"
    fi
fi

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
