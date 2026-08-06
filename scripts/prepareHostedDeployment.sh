#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

eval "$(azd env get-values 2>/dev/null | sed 's/^/export /')"

PYTHON_CMD=python3
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
    PYTHON_CMD=python
fi

cd "$PROJECT_ROOT"
"$PYTHON_CMD" -m config.deployment.hosted_prepare \
    --manifest "$PROJECT_ROOT/manifest.json" \
    "$@"
