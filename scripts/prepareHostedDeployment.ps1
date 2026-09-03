Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& azd env get-values | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2] -replace '^"|"$'
        Set-Item -Path "Env:$name" -Value $value
    }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $projectRoot
try {
    $env:GPT_RAG_REPO_ROOT = $projectRoot
    & python -c "import os, runpy, sys; sys.path.insert(0, os.environ['GPT_RAG_REPO_ROOT']); sys.argv = ['config.deployment.hosted_prepare'] + sys.argv[1:]; runpy.run_module('config.deployment.hosted_prepare', run_name='__main__')" `
        --manifest (Join-Path $projectRoot 'manifest.json') @args
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
