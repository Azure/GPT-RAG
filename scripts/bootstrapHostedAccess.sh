#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_CMD=python3
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
    PYTHON_CMD=python
fi
export GPT_RAG_REPO_ROOT="$PROJECT_ROOT"
cd "$PROJECT_ROOT/hosted-agent"
# Python loads JSON from the selected child environment; no shell evaluation.
exec "$PYTHON_CMD" -c "import os, runpy, sys; sys.path.insert(0, os.environ['GPT_RAG_REPO_ROOT']); sys.argv = ['config.deployment.hosted_access'] + sys.argv[1:]; runpy.run_module('config.deployment.hosted_access', run_name='__main__')" --azd-env --apply
