#!/usr/bin/env sh
# azd requires hook scripts inside the service project; delegate to the shared script.
set -eu
exec sh "$(cd "$(dirname "$0")" && pwd)/../../scripts/bootstrapHostedAccess.sh"
