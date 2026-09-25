# azd requires hook scripts inside the service project; delegate to the shared script.
& (Join-Path $PSScriptRoot '../../scripts/bootstrapHostedAccess.ps1')
exit $LASTEXITCODE
