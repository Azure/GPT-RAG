###############################################################################
# DEPRECATED VERSION - DEPLOYMENT GUARD
###############################################################################
if ($env:AZURE_ALLOW_DEPRECATED_VERSION -ne "true") {
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host "  DEPLOYMENT BLOCKED - THIS VERSION IS DEPRECATED" -ForegroundColor Red
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  This release of the GPT-RAG accelerator contains a known ingestion defect"
    Write-Host "  that can reprocess the same documents repeatedly, resulting in unexpected"
    Write-Host "  Document Intelligence consumption."
    Write-Host ""
    Write-Host "    Details:  https://github.com/Azure/GPT-RAG/issues/437"
    Write-Host ""
    Write-Host "  Please deploy the latest release instead:"
    Write-Host ""
    Write-Host "    https://github.com/Azure/GPT-RAG/releases/latest"
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host "  To run this version anyway, set AZURE_ALLOW_DEPRECATED_VERSION=true" -ForegroundColor Red
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# predeployment-network-warning.ps1
# Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Helper to match truthy values (1, true, t)
function Is-Truthy($value) {
    if (-not $value) { return $false }
    return $value -match '^(1|true|t)$'
}

# 1) Network Isolation Warning
# Skip warning if AZURE_SKIP_NETWORK_ISOLATION_WARNING is truthy
if (Is-Truthy $env:AZURE_SKIP_NETWORK_ISOLATION_WARNING) {
    exit 0
}

# Show warning if AZURE_NETWORK_ISOLATION is truthy
if (Is-Truthy $env:AZURE_NETWORK_ISOLATION) {
    Write-Host "Warning!" -ForegroundColor Yellow -NoNewline
    Write-Host " AZURE_NETWORK_ISOLATION is enabled."
    Write-Host " - After provisioning, you must switch to the" -NoNewline
    Write-Host " Virtual Machine & Bastion" -ForegroundColor Green -NoNewline
    Write-Host " to continue deploying components."
    Write-Host " - Infrastructure will only be reachable from within the Bastion host.`n"

    $prompt = "? Continue with Zero Trust provisioning? [Y/n]: "
    Write-Host $prompt -ForegroundColor Blue -NoNewline
    $confirmation = Read-Host

    # If user enters something other than Y/y (blank is treated as yes)
    if ($confirmation -and $confirmation -notin 'Y','y') {
        exit 1
    }
}

exit 0
