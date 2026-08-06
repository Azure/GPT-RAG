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
    & python -m config.deployment.hosted_prepare `
        --manifest (Join-Path $projectRoot 'manifest.json') `
        @args
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
