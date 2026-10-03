#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_CMD=python3
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
    PYTHON_CMD=python
fi
# The child azd project and service of the azure.ai.agent component being
# deployed (exported by hosted-agent/hooks/postdeploy.*). Defaults keep the
# bundled orchestrator working when the script is run directly.
AGENTLZ_HOSTED_PROJECT="${AGENTLZ_HOSTED_PROJECT:-$PROJECT_ROOT/hosted-agent}"
AGENTLZ_HOSTED_SERVICE="${AGENTLZ_HOSTED_SERVICE:-orchestrator-agent}"
export AGENTLZ_REPO_ROOT="$PROJECT_ROOT" AGENTLZ_HOSTED_PROJECT AGENTLZ_HOSTED_SERVICE
if [ ! -d "$AGENTLZ_HOSTED_PROJECT" ]; then
    echo "Hosted agent project $AGENTLZ_HOSTED_PROJECT (AGENTLZ_HOSTED_PROJECT) does not exist." >&2
    exit 1
fi
cd "$AGENTLZ_HOSTED_PROJECT"
# Python loads JSON from the selected child environment; no shell evaluation.
exec "$PYTHON_CMD" -c "import os, runpy, sys; sys.path.insert(0, os.environ['AGENTLZ_REPO_ROOT']); sys.argv = ['config.deployment.hosted_access'] + sys.argv[1:]; runpy.run_module('config.deployment.hosted_access', run_name='__main__')" --azd-env --apply
