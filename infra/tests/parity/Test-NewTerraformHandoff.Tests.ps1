<#
.SYNOPSIS
    Exercises deterministic handoff generation and explicit failure paths.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$generator = Join-Path $repo 'scripts\parity\New-TerraformHandoff.ps1'
$validator = Join-Path $repo 'scripts\parity\Test-ParityJson.ps1'
$temp = Join-Path $PSScriptRoot ('.tmp-generator-{0}' -f [guid]::NewGuid())
$capability = 'identity-rbac-automation'
$failures = 0

function Invoke-Generator([string[]]$Arguments) {
    $output = & pwsh -NoProfile -File $generator -Root $temp @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

try {
    New-Item (Join-Path $temp 'parity\handoffs') -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $temp 'parity\config.json')
    Copy-Item (Join-Path $repo 'parity\inventory.json') (Join-Path $temp 'parity\inventory.json')
    $common = @(
        '-ProvenanceType', 'baseline-inventory',
        '-CapabilityIds', $capability
    )
    $valid = Invoke-Generator (@('-Id', 'handoff-generated-valid', '-OutputPath', 'parity/handoffs/valid.json') + $common)
    Assert-Result 'Pending baseline inventory generates a handoff' ($valid.ExitCode -eq 0) $valid.Output
    $generatedRelative = [IO.Path]::GetRelativePath($repo, (Join-Path $temp 'parity\handoffs\valid.json'))
    $schemaOutput = & pwsh -NoProfile -File $validator -Root $repo -Path $generatedRelative -Schema terraformHandoff 2>&1 | Out-String
    Assert-Result 'Generated handoff is schema-valid' ($LASTEXITCODE -eq 0) $schemaOutput
    $generated = Get-Content (Join-Path $temp 'parity\handoffs\valid.json') -Raw | ConvertFrom-Json -Depth 100
    Assert-Result 'Pending provenance contains baseline ID and exact-byte digest only' (
        $generated.approval.status -eq 'pending' -and
        $generated.provenance.baselineId -eq 'baseline-v2.6.1-v0.5.1' -and
        $generated.provenance.inventoryDigest.value -eq '5dd04b6ebb7faa4554954ee9fe27cd3589943f724e9d14e5c799dea0a93bdf75' -and
        $generated.provenance.PSObject.Properties.Name -notcontains 'inventoryCommitSha' -and
        $generated.provenance.PSObject.Properties.Name -notcontains 'inventoryReviewUrl'
    ) ($generated.provenance | ConvertTo-Json -Compress)

    $invalid = Invoke-Generator @(
        '-Id', 'handoff-invalid-provenance', '-OutputPath', 'parity/handoffs/invalid.json',
        '-ProvenanceType', 'baseline-inventory',
        '-InventoryCommitSha', '64195c01b70974fa7256c2f54a0035fb06804139',
        '-CapabilityIds', $capability
    )
    Assert-Result 'Invalid provenance fails explicitly' (
        $invalid.ExitCode -ne 0 -and $invalid.Output -match 'must not claim'
    ) $invalid.Output

    $staleInventory = Get-Content (Join-Path $temp 'parity\inventory.json') -Raw | ConvertFrom-Json -Depth 100
    $staleInventory.baseline.source.commitSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $staleInventory | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $temp 'parity\stale.json') -Encoding utf8NoBOM
    $stale = Invoke-Generator (@(
        '-Id', 'handoff-stale', '-OutputPath', 'parity/handoffs/stale.json',
        '-InventoryPath', 'parity/stale.json'
    ) + $common)
    Assert-Result 'Stale baseline fails explicitly' ($stale.ExitCode -ne 0 -and $stale.Output -match 'stale') $stale.Output

    $unknown = Invoke-Generator (@(
        '-Id', 'handoff-unknown', '-OutputPath', 'parity/handoffs/unknown.json'
    ) + @('-ProvenanceType', 'baseline-inventory', '-CapabilityIds', 'unknown-capability'))
    Assert-Result 'Unknown capability fails explicitly' ($unknown.ExitCode -ne 0 -and $unknown.Output -match 'Unknown capability') $unknown.Output

    $duplicate = Invoke-Generator (@('-Id', 'handoff-generated-duplicate', '-OutputPath', 'parity/handoffs/duplicate.json') + $common)
    Assert-Result 'Duplicate active handoff fails explicitly' ($duplicate.ExitCode -ne 0 -and $duplicate.Output -match 'Duplicate active') $duplicate.Output

    $sensitive = Invoke-Generator (@(
        '-Id', 'handoff-sensitive', '-OutputPath', 'parity/handoffs/sensitive.json',
        '-AdditionalRequirement', 'Connect to 10.2.3.4.'
    ) + @('-ProvenanceType', 'baseline-inventory', '-CapabilityIds', 'foundry-account-project-agent'))
    Assert-Result 'Sensitive content fails explicitly' ($sensitive.ExitCode -ne 0 -and $sensitive.Output -match 'prohibited') $sensitive.Output

    $assessment = Get-Content (Join-Path $repo 'tests\parity\fixtures\source-pr.json') -Raw | ConvertFrom-Json -Depth 100
    $assessment.changedCapabilities = @($capability)
    $assessment.outcome = 'proposal-required'
    $assessment.rationale = 'Reviewed fixture requires a proposal.'
    $assessment | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $temp 'parity\assessment-pending.json') -Encoding utf8NoBOM
    $pendingAlignment = Invoke-Generator @(
        '-Id', 'handoff-alignment-pending', '-OutputPath', 'parity/handoffs/alignment-pending.json',
        '-ProvenanceType', 'alignment-assessment', '-AssessmentPath', 'parity/assessment-pending.json',
        '-CapabilityIds', $capability
    )
    Assert-Result 'Pending alignment assessment is rejected' (
        $pendingAlignment.ExitCode -ne 0 -and $pendingAlignment.Output -match 'approved proposal-required'
    ) $pendingAlignment.Output

    $assessment.review.status = 'approved'
    $assessment.review | Add-Member reviewer 'parity-reviewer'
    $assessment.review | Add-Member approvalUrl 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/999'
    $assessment.review | Add-Member reviewedAt '2026-08-21T18:39:46Z'
    $assessment | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $temp 'parity\assessment.json') -Encoding utf8NoBOM
    $alignment = Invoke-Generator @(
        '-Id', 'handoff-alignment-valid', '-OutputPath', 'parity/handoffs/alignment.json',
        '-ProvenanceType', 'alignment-assessment', '-AssessmentPath', 'parity/assessment.json',
        '-CapabilityIds', $capability
    )
    Assert-Result 'Approved alignment assessment generates a handoff' ($alignment.ExitCode -eq 0) $alignment.Output
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
