<#
.SYNOPSIS
    Deterministic fixture tests for parity schema and aggregate validation.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$jsonValidator = Join-Path $repoRoot 'scripts\parity\Test-ParityJson.ps1'
$assetValidator = Join-Path $repoRoot 'scripts\parity\Test-ParityAssets.ps1'
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures'
$tempRoot = Join-Path $PSScriptRoot ('.tmp-{0}' -f [guid]::NewGuid())
$failures = 0

function Assert-Result {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] $Name - $Detail" -ForegroundColor Red
        $script:failures++
    }
}

function Test-OutputMatch {
    param([string]$Output, [string]$Pattern)
    $withoutAnsi = $Output -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
    return (($withoutAnsi -replace '\s+', ' ') -match $Pattern)
}

function Invoke-JsonValidator {
    param([string]$Path, [string]$Schema)
    $arguments = @('-NoProfile', '-File', $jsonValidator, '-Root', $repoRoot, '-Path', $Path)
    if ($Schema) { $arguments += @('-Schema', $Schema) }
    $output = & pwsh @arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Invoke-AssetValidator {
    param(
        [string]$Inventory = 'tests/parity/fixtures/capability.json',
        [string]$Assessments = 'tests/parity/fixtures/source-pr.json',
        [string]$Handoffs = 'tests/parity/fixtures/handoff.json',
        [string]$Evidence = 'tests/parity/fixtures/evidence.json',
        [string]$GitRepository
    )
    $arguments = @(
        '-NoProfile', '-File', $assetValidator, '-Root', $repoRoot,
        '-InventoryPath', $Inventory, '-AssessmentsPath', $Assessments,
        '-HandoffsPath', $Handoffs, '-EvidencePath', $Evidence
    )
    if ($GitRepository) { $arguments += @('-GitRepositoryPath', $GitRepository) }
    $output = & pwsh @arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Write-TempJson {
    param([string]$Name, $Value)
    $path = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    return (Resolve-Path $path).Path.Substring($repoRoot.Length + 1).Replace('\', '/')
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $escape = [char]27
    Assert-Result 'Output matching ignores ANSI and line wrapping' (
        Test-OutputMatch "cannot`nverify ${escape}[31mcommitted${escape}[0m inventory" `
            'cannot verify committed inventory'
    ) ''

    $validFixtures = @(
        @{ Name = 'baseline.json'; Schema = 'inventory' },
        @{ Name = 'capability.json'; Schema = 'inventory' },
        @{ Name = 'source-pr.json'; Schema = 'assessment' },
        @{ Name = 'baseline-approval.json'; Schema = 'terraformHandoff' },
        @{ Name = 'handoff.json'; Schema = 'terraformHandoff' },
        @{ Name = 'evidence.json'; Schema = 'parityEvidence' }
    )
    foreach ($fixture in $validFixtures) {
        $relativePath = "tests/parity/fixtures/$($fixture.Name)"
        $result = Invoke-JsonValidator $relativePath $fixture.Schema
        Assert-Result "Valid $($fixture.Name) fixture passes" ($result.ExitCode -eq 0) $result.Output
    }
    $discovered = Invoke-JsonValidator 'tests/parity/fixtures/handoff.json' ''
    Assert-Result 'Schema discovery selects the handoff contract' ($discovered.ExitCode -eq 0) $discovered.Output

    $aggregate = Invoke-AssetValidator
    Assert-Result 'Coherent fixtures pass aggregate validation' ($aggregate.ExitCode -eq 0) $aggregate.Output

    $malformedPath = Join-Path $tempRoot 'malformed.json'
    [System.IO.File]::WriteAllText($malformedPath, '{"schemaVersion":', [System.Text.UTF8Encoding]::new($false))
    $malformedRelative = $malformedPath.Substring($repoRoot.Length + 1).Replace('\', '/')
    $malformed = Invoke-JsonValidator $malformedRelative 'inventory'
    Assert-Result 'Malformed JSON fails explicitly' (
        $malformed.ExitCode -ne 0 -and $malformed.Output -match 'not valid JSON'
    ) $malformed.Output

    $unknown = Get-Content (Join-Path $fixtureRoot 'capability.json') -Raw | ConvertFrom-Json
    $unknown | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
    $unknownResult = Invoke-JsonValidator (Write-TempJson 'unknown.json' $unknown) 'inventory'
    Assert-Result 'Unknown fields fail' (
        $unknownResult.ExitCode -ne 0 -and $unknownResult.Output -match 'additional properties'
    ) $unknownResult.Output

    $duplicate = Get-Content (Join-Path $fixtureRoot 'capability.json') -Raw | ConvertFrom-Json
    $duplicate.capabilities = @($duplicate.capabilities[0], $duplicate.capabilities[0])
    $duplicateResult = Invoke-AssetValidator -Inventory (Write-TempJson 'duplicate.json' $duplicate)
    Assert-Result 'Duplicate capability IDs fail' (
        $duplicateResult.ExitCode -ne 0 -and $duplicateResult.Output -match 'Duplicate capability ID'
    ) $duplicateResult.Output

    $badSha = Get-Content (Join-Path $fixtureRoot 'source-pr.json') -Raw | ConvertFrom-Json
    $badSha.sourcePr.mergeCommitSha = 'not-a-sha'
    $badShaResult = Invoke-JsonValidator (Write-TempJson 'bad-sha.json' $badSha) 'assessment'
    Assert-Result 'Invalid SHAs fail' (
        $badShaResult.ExitCode -ne 0 -and $badShaResult.Output -match 'pattern'
    ) $badShaResult.Output

    $badScenarios = Get-Content (Join-Path $fixtureRoot 'capability.json') -Raw | ConvertFrom-Json
    $badScenarios.scenarios[1] = 'hub-spoke'
    $badScenariosResult = Invoke-JsonValidator (Write-TempJson 'bad-scenarios.json' $badScenarios) 'inventory'
    Assert-Result 'Unsupported scenarios fail' (
        $badScenariosResult.ExitCode -ne 0 -and $badScenariosResult.Output -match 'constant'
    ) $badScenariosResult.Output

    $missingApproval = Get-Content (Join-Path $fixtureRoot 'baseline-approval.json') -Raw | ConvertFrom-Json
    $missingApproval.approval.PSObject.Properties.Remove('approvedBy')
    $missingApprovalResult = Invoke-JsonValidator (Write-TempJson 'missing-approval.json' $missingApproval) 'terraformHandoff'
    Assert-Result 'Missing approval metadata fails' (
        $missingApprovalResult.ExitCode -ne 0 -and $missingApprovalResult.Output -match 'approvedBy'
    ) $missingApprovalResult.Output

    $sourceAsInventory = Invoke-AssetValidator `
        -Handoffs 'tests/parity/fixtures/baseline-approval.json'
    Assert-Result 'Bicep source SHA is rejected when it lacks the inventory blob' (
        $sourceAsInventory.ExitCode -ne 0 -and
        (Test-OutputMatch $sourceAsInventory.Output 'cannot verify committed inventory')
    ) $sourceAsInventory.Output

    $gitFixture = Join-Path $tempRoot 'committed-inventory-repo'
    New-Item -ItemType Directory (Join-Path $gitFixture 'parity') -Force | Out-Null
    Copy-Item (Join-Path $fixtureRoot 'capability.json') (Join-Path $gitFixture 'parity\inventory.json')
    $fixtureInventoryPath = Join-Path $gitFixture 'parity\inventory.json'
    $fixtureInventoryText = [System.IO.File]::ReadAllText($fixtureInventoryPath).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        $fixtureInventoryPath,
        $fixtureInventoryText,
        [System.Text.UTF8Encoding]::new($false)
    )
    & git -C $gitFixture init --quiet
    & git -C $gitFixture config core.autocrlf false
    & git -C $gitFixture add parity/inventory.json
    $env:GIT_AUTHOR_DATE = '2026-08-21T18:39:46Z'
    $env:GIT_COMMITTER_DATE = '2026-08-21T18:39:46Z'
    & git -C $gitFixture -c user.name=parity-fixture -c user.email=parity-fixture@example.invalid `
        commit --quiet -m 'fixture inventory'
    $inventoryCommit = (& git -C $gitFixture rev-parse HEAD).Trim()
    Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE
    $committedApproval = Get-Content (Join-Path $fixtureRoot 'baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $committedApproval.provenance.inventoryCommitSha = $inventoryCommit
    $committedApprovalPath = Write-TempJson 'committed-approval.json' $committedApproval
    $emptyAssessments = Join-Path $tempRoot 'empty-assessments'
    New-Item -ItemType Directory $emptyAssessments -Force | Out-Null
    $committedResult = Invoke-AssetValidator `
        -Assessments ([IO.Path]::GetRelativePath($repoRoot, $emptyAssessments)) `
        -Handoffs $committedApprovalPath `
        -GitRepository $gitFixture
    Assert-Result 'Approved committed inventory digest and baselines are verified' (
        $committedResult.ExitCode -eq 0
    ) $committedResult.Output

    $wrongDigestApproval = Get-Content (Join-Path $fixtureRoot 'baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $wrongDigestApproval.provenance.inventoryCommitSha = $inventoryCommit
    $wrongDigestApproval.provenance.inventoryDigest.value = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $wrongDigestResult = Invoke-AssetValidator `
        -Assessments ([IO.Path]::GetRelativePath($repoRoot, $emptyAssessments)) `
        -Handoffs (Write-TempJson 'wrong-digest-approval.json' $wrongDigestApproval) `
        -GitRepository $gitFixture
    Assert-Result 'Approved inventory digest mismatch is rejected' (
        $wrongDigestResult.ExitCode -ne 0 -and
        $wrongDigestResult.Output -match 'digest'
    ) $wrongDigestResult.Output

    $wrongBaselineApproval = Get-Content (Join-Path $fixtureRoot 'baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $wrongBaselineApproval.provenance.inventoryCommitSha = $inventoryCommit
    $wrongBaselineApproval.provenance.baselineId = 'baseline-unreviewed'
    $wrongBaselineResult = Invoke-AssetValidator `
        -Assessments ([IO.Path]::GetRelativePath($repoRoot, $emptyAssessments)) `
        -Handoffs (Write-TempJson 'wrong-baseline-approval.json' $wrongBaselineApproval) `
        -GitRepository $gitFixture
    Assert-Result 'Approved inventory baseline mismatch is rejected' (
        $wrongBaselineResult.ExitCode -ne 0 -and
        $wrongBaselineResult.Output -match 'baseline'
    ) $wrongBaselineResult.Output

    $issueApproval = Get-Content (Join-Path $fixtureRoot 'baseline-approval.json') -Raw |
        ConvertFrom-Json -Depth 100
    $issueApproval.provenance.inventoryCommitSha = $inventoryCommit
    $issueApproval.provenance.inventoryReviewUrl = 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/136'
    $issueApproval.approval.approvalUrl = 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/136'
    $issueResult = Invoke-AssetValidator `
        -Assessments ([IO.Path]::GetRelativePath($repoRoot, $emptyAssessments)) `
        -Handoffs (Write-TempJson 'issue-context-approval.json' $issueApproval) `
        -GitRepository $gitFixture
    Assert-Result 'Issue 136 is rejected as review and authorization evidence' (
        $issueResult.ExitCode -ne 0 -and
        $issueResult.Output -match 'Issue #136 is context'
    ) $issueResult.Output

    $pendingProposalInventory = Get-Content (Join-Path $fixtureRoot 'capability.json') -Raw |
        ConvertFrom-Json -Depth 100
    $pendingProposalInventory.capabilities[0].scenarioAssessments[0].proposalIds = @(
        'handoff-assessment-sample'
    )
    $pendingProposal = Invoke-AssetValidator `
        -Inventory (Write-TempJson 'pending-proposal-inventory.json' $pendingProposalInventory)
    Assert-Result 'Pending handoffs cannot satisfy proposal eligibility' (
        $pendingProposal.ExitCode -ne 0 -and
        $pendingProposal.Output -match 'not approved' -and
        $pendingProposal.Output -match 'proposal-eligible'
    ) $pendingProposal.Output

    $declared = Get-Content (Join-Path $fixtureRoot 'capability.json') -Raw | ConvertFrom-Json
    $declared.capabilities[0].scenarioAssessments[0].evidenceLevel = 'reviewed'
    $declared.capabilities[0].scenarioAssessments[0].parityDeclared = $true
    $declared.capabilities[0].scenarioAssessments[0].evidenceIds = @(
        'evidence-static-sample',
        'evidence-plan-sample'
    )
    $planEvidence = Get-Content (Join-Path $fixtureRoot 'evidence.json') -Raw | ConvertFrom-Json
    $planEvidence.id = 'evidence-plan-sample'
    $planEvidence.type = 'terraform-plan'
    Write-TempJson 'insufficient-evidence/static.json' (
        Get-Content (Join-Path $fixtureRoot 'evidence.json') -Raw | ConvertFrom-Json
    ) | Out-Null
    $evidenceDirectory = Split-Path (Write-TempJson 'insufficient-evidence/plan.json' $planEvidence) -Parent
    $declaredResult = Invoke-AssetValidator `
        -Inventory (Write-TempJson 'declared-without-deployment.json' $declared) `
        -Evidence $evidenceDirectory
    Assert-Result 'Static validation and plan evidence cannot support parity' (
        $declaredResult.ExitCode -ne 0 -and
        (Test-OutputMatch $declaredResult.Output 'lacks successful deployment')
    ) $declaredResult.Output

    $sensitive = Get-Content (Join-Path $fixtureRoot 'handoff.json') -Raw | ConvertFrom-Json
    $sensitive.requiredBehavior = @('Connect to private address 10.0.0.4.')
    $sensitiveResult = Invoke-AssetValidator -Handoffs (Write-TempJson 'sensitive.json' $sensitive)
    Assert-Result 'Sensitive private addresses fail aggregate validation' (
        $sensitiveResult.ExitCode -ne 0 -and $sensitiveResult.Output -match 'Private IP address'
    ) $sensitiveResult.Output
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures -gt 0) {
    exit 1
}
exit 0
