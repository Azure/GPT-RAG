#!/usr/bin/env sh
# azd requires hook scripts inside the service project; delegate to the shared script.
# Generalized for any azure.ai.agent component: the child project and service are
# exported so the shared script does not assume the bundled orchestrator.
set -eu
hook_dir="$(cd "$(dirname "$0")" && pwd)"
AGENTLZ_HOSTED_PROJECT="$(cd "$hook_dir/.." && pwd)"
AGENTLZ_HOSTED_SERVICE="${AGENTLZ_HOSTED_SERVICE:-${SERVICE_NAME:-orchestrator-agent}}"
export AGENTLZ_HOSTED_PROJECT AGENTLZ_HOSTED_SERVICE
exec sh "$hook_dir/../../scripts/bootstrapHostedAccess.sh"
