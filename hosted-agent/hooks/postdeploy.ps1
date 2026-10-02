# azd requires hook scripts inside the service project; delegate to the shared script.
# Generalized for any azure.ai.agent component: the child project and service are
# exported so the shared script does not assume the bundled orchestrator.
$env:AGENTLZ_HOSTED_PROJECT = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $env:AGENTLZ_HOSTED_SERVICE) {
    $env:AGENTLZ_HOSTED_SERVICE = if ($env:SERVICE_NAME) { $env:SERVICE_NAME } else { 'orchestrator-agent' }
}
& (Join-Path $PSScriptRoot '../../scripts/bootstrapHostedAccess.ps1')
exit $LASTEXITCODE
