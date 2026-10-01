<#
.SYNOPSIS
    Validates the complete Terraform handoff contract.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $root 'scripts\parity\Test-ParityJson.ps1'
$fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures\baseline-approval.json') -Raw | ConvertFrom-Json -Depth 100
$temp = Join-Path $PSScriptRoot ('.tmp-handoff-contract-{0}' -f [guid]::NewGuid())
$failures = 0
$required = @(
    'compatibilityConstraints', 'defaultBehavior', 'migrationPlan', 'semanticVersionExpectation',
    'migrationRequired', 'avmRequirements', 'scenarioAcceptance', 'identityRequirements',
    'rbacRequirements', 'networkingRequirements', 'securityInvariants', 'acceptanceCriteria',
    'evidenceRequirements', 'owner', 'excludedScenarios', 'exclusions', 'approval'
)
try {
    New-Item -ItemType Directory $temp -Force | Out-Null
    foreach ($field in $required) {
        $copy = $fixture.PSObject.Copy()
        $copy.PSObject.Properties.Remove($field)
        $path = Join-Path $temp "$field.json"
        $copy | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding utf8NoBOM
        $output = & pwsh -NoProfile -File $validator -Root $root -Path ([IO.Path]::GetRelativePath($root, $path)) -Schema terraformHandoff 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $output -notmatch $field) {
            Write-Host "[FAIL] Missing $field was accepted - $output" -ForegroundColor Red
            $failures++
        }
    }
    $both = Get-Content (Join-Path $PSScriptRoot 'fixtures\baseline-approval.json') -Raw | ConvertFrom-Json -Depth 100
    $both.provenance | Add-Member assessmentId 'assessment-136-64195c0'
    $bothPath = Join-Path $temp 'both-provenance.json'
    $both | ConvertTo-Json -Depth 100 | Set-Content $bothPath -Encoding utf8NoBOM
    & pwsh -NoProfile -File $validator -Root $root -Path ([IO.Path]::GetRelativePath($root, $bothPath)) -Schema terraformHandoff *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host '[FAIL] Both provenance forms were accepted.' -ForegroundColor Red; $failures++ }

    $pending = Get-Content (Join-Path $PSScriptRoot 'fixtures\baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $pending.provenance.PSObject.Properties.Remove('inventoryCommitSha')
    $pending.provenance.PSObject.Properties.Remove('inventoryReviewUrl')
    $pending.approval = [pscustomobject]@{ status = 'pending' }
    $pendingPath = Join-Path $temp 'pending-baseline.json'
    $pending | ConvertTo-Json -Depth 100 | Set-Content $pendingPath -Encoding utf8NoBOM
    & pwsh -NoProfile -File $validator -Root $root -Path ([IO.Path]::GetRelativePath($root, $pendingPath)) -Schema terraformHandoff *> $null
    if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] Honest pending baseline provenance was rejected.' -ForegroundColor Red; $failures++ }

    foreach ($field in @('inventoryCommitSha', 'inventoryReviewUrl')) {
        $missing = Get-Content (Join-Path $PSScriptRoot 'fixtures\baseline-approval.json') -Raw |
            ConvertFrom-Json -Depth 100
        $missing.provenance.PSObject.Properties.Remove($field)
        $missingPath = Join-Path $temp "approved-missing-$field.json"
        $missing | ConvertTo-Json -Depth 100 | Set-Content $missingPath -Encoding utf8NoBOM
        $output = & pwsh -NoProfile -File $validator -Root $root -Path ([IO.Path]::GetRelativePath($root, $missingPath)) -Schema terraformHandoff 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $output -notmatch $field) {
            Write-Host "[FAIL] Approved baseline missing $field was accepted - $output" -ForegroundColor Red
            $failures++
        }
    }

    $pendingClaim = Get-Content (Join-Path $PSScriptRoot 'fixtures\baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $pendingClaim.approval = [pscustomobject]@{ status = 'pending' }
    $pendingClaimPath = Join-Path $temp 'pending-with-commit.json'
    $pendingClaim | ConvertTo-Json -Depth 100 | Set-Content $pendingClaimPath -Encoding utf8NoBOM
    & pwsh -NoProfile -File $validator -Root $root -Path ([IO.Path]::GetRelativePath($root, $pendingClaimPath)) -Schema terraformHandoff *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host '[FAIL] Pending baseline claimed approved inventory provenance.' -ForegroundColor Red; $failures++ }
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
if ($failures) { exit 1 }
Write-Host 'Terraform handoff contract tests passed.'
exit 0
