Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location (Join-Path $projectRoot 'hosted-agent')
try {
    $env:GPT_RAG_REPO_ROOT = $projectRoot
    # Python loads JSON from the selected child environment; no shell evaluation.
    & python -c "import os, runpy, sys; sys.path.insert(0, os.environ['GPT_RAG_REPO_ROOT']); sys.argv = ['config.deployment.hosted_access'] + sys.argv[1:]; runpy.run_module('config.deployment.hosted_access', run_name='__main__')" --azd-env --apply
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $code
