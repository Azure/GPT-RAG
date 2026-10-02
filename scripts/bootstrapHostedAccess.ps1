Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# The child azd project and service of the azure.ai.agent component being
# deployed (exported by hosted-agent/hooks/postdeploy.*). Defaults keep the
# bundled orchestrator working when the script is run directly.
$hostedProject = if ($env:AGENTLZ_HOSTED_PROJECT) { $env:AGENTLZ_HOSTED_PROJECT } else { Join-Path $projectRoot 'hosted-agent' }
if (-not $env:AGENTLZ_HOSTED_SERVICE) { $env:AGENTLZ_HOSTED_SERVICE = 'orchestrator-agent' }
if (-not (Test-Path -LiteralPath $hostedProject -PathType Container)) {
    Write-Error "Hosted agent project $hostedProject (AGENTLZ_HOSTED_PROJECT) does not exist."
    exit 1
}
Push-Location -LiteralPath $hostedProject
try {
    $env:AGENTLZ_REPO_ROOT = $projectRoot
    # Python loads JSON from the selected child environment; no shell evaluation.
    & python -c "import os, runpy, sys; sys.path.insert(0, os.environ['AGENTLZ_REPO_ROOT']); sys.argv = ['config.deployment.hosted_access'] + sys.argv[1:]; runpy.run_module('config.deployment.hosted_access', run_name='__main__')" --azd-env --apply
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $code
