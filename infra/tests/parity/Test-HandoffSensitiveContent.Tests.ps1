<#
.SYNOPSIS
    Rejects source code and private content in Terraform handoffs.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $root 'scripts\parity\Test-ParityAssets.ps1'
$fixturePath = Join-Path $PSScriptRoot 'fixtures\handoff.json'
$temp = Join-Path $PSScriptRoot ('.tmp-sensitive-{0}' -f [guid]::NewGuid())
$cases = [ordered]@{
    terraform = 'resource "azurerm_resource_group" "sample" {'
    credential = 'client_secret=not-a-real-secret'
    tenant = 'tenant id: 11111111-1111-1111-1111-111111111111'
    subscription = 'subscription id: 22222222-2222-2222-2222-222222222222'
    privateAddress = 'Connect to 10.1.2.3.'
    resourceName = 'resource name: contoso-prod-sample'
}
$failures = 0
try {
    New-Item -ItemType Directory $temp -Force | Out-Null
    foreach ($case in $cases.GetEnumerator()) {
        $handoff = Get-Content $fixturePath -Raw | ConvertFrom-Json -Depth 100
        $handoff.requiredBehavior = @($case.Value)
        $path = Join-Path $temp "$($case.Key).json"
        $handoff | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding utf8NoBOM
        $output = & pwsh -NoProfile -File $validator -Root $root `
            -InventoryPath 'tests/parity/fixtures/capability.json' `
            -AssessmentsPath 'tests/parity/fixtures/source-pr.json' `
            -HandoffsPath ([IO.Path]::GetRelativePath($root, $path)) `
            -EvidencePath 'tests/parity/fixtures/evidence.json' 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $output -notmatch 'prohibited') {
            Write-Host "[FAIL] $($case.Key) was accepted - $output" -ForegroundColor Red
            $failures++
        } else { Write-Host "[PASS] $($case.Key)" -ForegroundColor Green }
    }
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
if ($failures) { exit 1 }
exit 0
