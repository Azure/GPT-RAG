<#
.SYNOPSIS
    Determines whether the configured assessment ledger branch exists.

.DESCRIPTION
    Treats Git exit code 2 as an absent branch and every other non-zero result as
    an operational failure. When OutputPath is supplied, writes the GitHub Actions
    output used to gate the ledger checkout.
#>

[CmdletBinding()]
param(
    [string]$Repository = 'origin',
    [string]$Branch = 'terraform-parity-assessments',
    [string]$OutputPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

try {
    $PSNativeCommandUseErrorActionPreference = $false
    git ls-remote --exit-code $Repository "refs/heads/$Branch" 1>$null 2>$null
    $probeExitCode = $LASTEXITCODE
    $exists = switch ($probeExitCode) {
        0 { 'true' }
        2 { 'false' }
        default {
            throw "Unable to determine whether assessment ledger branch '$Branch' exists in '$Repository' (git exit $probeExitCode)."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        "exists=$exists" | Out-File -LiteralPath $OutputPath -Append -Encoding utf8
    }
    Write-Host "Assessment ledger branch present: $exists"
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
