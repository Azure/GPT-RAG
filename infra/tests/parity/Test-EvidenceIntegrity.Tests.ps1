<#
.SYNOPSIS
    Proves weak or cross-scenario evidence cannot declare parity.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $root 'scripts\parity\Test-ParityAssets.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$temp = Join-Path $PSScriptRoot ('.tmp-evidence-{0}' -f [guid]::NewGuid())
$failures = 0

function Assert-Rejected([string]$Name, [object[]]$Evidence, [string]$Expected) {
    $inventory = Get-Content (Join-Path $fixtures 'capability.json') -Raw | ConvertFrom-Json -Depth 100
    $inventory.capabilities[0].scenarioAssessments[0].evidenceLevel = 'reviewed'
    $inventory.capabilities[0].scenarioAssessments[0].parityDeclared = $true
    $inventory.capabilities[0].scenarioAssessments[0].evidenceIds = @($Evidence | ForEach-Object { $_.id })
    $inventoryPath = Join-Path $temp "$Name-inventory.json"
    $evidencePath = Join-Path $temp $Name
    New-Item -ItemType Directory $evidencePath -Force | Out-Null
    $inventory | ConvertTo-Json -Depth 100 | Set-Content $inventoryPath -Encoding utf8NoBOM
    $index = 0
    foreach ($item in $Evidence) {
        $item | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $evidencePath "$index.json") -Encoding utf8NoBOM
        $index++
    }

    $output = & pwsh -NoProfile -File $validator -Root $root `
        -InventoryPath ([IO.Path]::GetRelativePath($root, $inventoryPath)) `
        -AssessmentsPath 'tests/parity/fixtures/source-pr.json' `
        -HandoffsPath 'tests/parity/fixtures/handoff.json' `
        -EvidencePath ([IO.Path]::GetRelativePath($root, $evidencePath)) 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $output -notmatch $Expected) {
        Write-Host "[FAIL] $Name - $output" -ForegroundColor Red
        $script:failures++
    } else { Write-Host "[PASS] $Name" -ForegroundColor Green }
}

function Copy-JsonObject($Value) {
    return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100)
}

try {
    New-Item -ItemType Directory $temp -Force | Out-Null
    $base = Get-Content (Join-Path $fixtures 'evidence.json') -Raw | ConvertFrom-Json
    $static = Copy-JsonObject $base
    $plan = Copy-JsonObject $base
    $plan.id = 'evidence-plan-only'; $plan.type = 'terraform-plan'
    Assert-Rejected 'static-and-plan' @($static, $plan) 'lacks successful deployment'

    $deployment = Copy-JsonObject $base
    $deployment.id = 'evidence-other-scenario-deployment'
    $deployment.type = 'scenario-deployment'
    $deployment.scenario = 'standalone-network-isolated'
    $comparison = Copy-JsonObject $base
    $comparison.id = 'evidence-other-scenario-comparison'
    $comparison.type = 'reviewed-capability-comparison'
    $comparison.scenario = 'standalone-network-isolated'
    Assert-Rejected 'other-scenario' @($deployment, $comparison) 'wrong scenario'
}
finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failures) { exit 1 }
exit 0
