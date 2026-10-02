<#
.SYNOPSIS
    Proves approved-only, bounded, and reconciled parity publication behavior.

.DESCRIPTION
    Covers protected-environment approval, repository and branch allow-lists,
    stale baselines, missing gaps, duplicate proposals, and target rejection.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$publisher = Join-Path $repo 'scripts\parity\Publish-TerraformHandoff.ps1'
$workflowPath = Join-Path $repo '.github\workflows\terraform-parity-publish.yml'
$config = Get-Content (Join-Path $repo 'parity\config.json') -Raw | ConvertFrom-Json -Depth 20
$temp = Join-Path $PSScriptRoot ('.tmp-publication-{0}' -f [guid]::NewGuid())
$payloadPath = 'payload.json'
$failures = 0
$commitNumber = 0

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

function Write-Json($Value, [string]$Path) {
    $Value | ConvertTo-Json -Depth 100 | Set-Content $Path -Encoding utf8NoBOM
}

function Invoke-Git([string[]]$Arguments) {
    $output = & git -C $temp -c user.name='Parity Test' -c user.email='parity@example.invalid' @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
    return $output.Trim()
}

function Commit-Fixture {
    Remove-Item (Join-Path $temp $payloadPath) -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $temp "$payloadPath.sent") -Force -ErrorAction SilentlyContinue
    Invoke-Git @('add', '-A') | Out-Null
    & git -C $temp diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        $script:commitNumber++
        Invoke-Git @('commit', '-m', "test: fixture $script:commitNumber") | Out-Null
    }
    return Invoke-Git @('rev-parse', 'HEAD')
}

function Invoke-PublisherAtCommit([string[]]$Arguments, [string]$CommitSha) {
    Remove-Item (Join-Path $temp $payloadPath) -Force -ErrorAction SilentlyContinue
    $output = & pwsh -NoProfile -File $publisher -Root $temp -PayloadPath $payloadPath `
        -HandoffCommitSha $CommitSha -HandoffRef 'develop' `
        -AssessmentsPath '.parity-ledger/parity/assessments' @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Invoke-Publisher([string[]]$Arguments) {
    $commitSha = Commit-Fixture
    return Invoke-PublisherAtCommit -Arguments $Arguments -CommitSha $commitSha
}

function Copy-JsonObject($Value) {
    return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100)
}

function Get-NormalizedFileDigest([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes).Replace("`r`n", "`n")
    $normalized = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($normalized)
    ).ToLowerInvariant()
}

try {
    New-Item -ItemType Directory (Join-Path $temp 'parity\handoffs') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $temp '.parity-ledger\parity\assessments') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $temp 'parity\schemas') -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $temp 'parity\config.json')
    Copy-Item (Join-Path $repo 'parity\inventory.json') (Join-Path $temp 'parity\inventory.json')
    Copy-Item (Join-Path $repo 'parity\assessments\adoption-marker.json') `
        (Join-Path $temp '.parity-ledger\parity\assessments\adoption-marker.json')
    Copy-Item (Join-Path $repo 'parity\schemas\terraform-handoff.schema.json') `
        (Join-Path $temp 'parity\schemas\terraform-handoff.schema.json')
    Invoke-Git @('init', '--initial-branch', 'develop') | Out-Null
    $approved = Get-Content (Join-Path $repo 'parity\handoffs\security\security-baseline.json') -Raw |
        ConvertFrom-Json -Depth 100

    $duplicateHandoff = Copy-JsonObject $approved
    Write-Json $duplicateHandoff (Join-Path $temp 'parity\handoffs\duplicate.json')
    $duplicate = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/duplicate.json')
    Assert-Result 'A recorded proposal is reconciled instead of dispatched twice' (
        $duplicate.ExitCode -eq 0 -and
        $duplicate.Output -match 'Existing proposal' -and
        $duplicate.Output -match '/pull/163' -and
        -not (Test-Path -LiteralPath (Join-Path $temp $payloadPath))
    ) $duplicate.Output

    $eligible = Copy-JsonObject $approved
    $eligible.PSObject.Properties.Remove('terraformPullRequestUrl')
    Write-Json $eligible (Join-Path $temp 'parity\handoffs\eligible.json')
    $published = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/eligible.json')
    $payloadFile = Join-Path $temp $payloadPath
    Assert-Result 'An approved handoff produces a dispatch payload' (
        $published.ExitCode -eq 0 -and (Test-Path -LiteralPath $payloadFile)
    ) $published.Output

    if (Test-Path -LiteralPath $payloadFile) {
        $payload = Get-Content $payloadFile -Raw | ConvertFrom-Json -Depth 100
        $allowedPayloadKeys = @(
            'capabilityIds', 'handoffCommitSha', 'handoffDigest', 'handoffId', 'handoffPath',
            'handoffRef', 'handoffSchemaPath', 'inventoryCommitSha', 'inventoryDigest',
            'inventoryReviewUrl', 'payloadVersion', 'provenanceId', 'provenanceType',
            'sourceCommitSha', 'sourcePrNumber', 'sourceRef', 'sourceRepository',
            'targetCommitSha', 'targetRef', 'targetRepository'
        )
        $payloadKeys = @($payload.client_payload.PSObject.Properties.Name)
        Assert-Result 'The dispatch payload contains only bounded identifiers and references' (
            @($payload.PSObject.Properties.Name | Sort-Object) -join ',' -eq 'client_payload,event_type' -and
            $payload.event_type -eq 'parity-proposal-requested' -and
            @($payloadKeys | Where-Object { $_ -notin $allowedPayloadKeys }).Count -eq 0 -and
            $payload.client_payload.payloadVersion -eq '2.0.0' -and
            $payload.client_payload.handoffId -eq $approved.id -and
            $payload.client_payload.targetRepository -eq $config.repositories.terraform.name -and
            $payload.client_payload.handoffRef -eq 'develop' -and
            $payload.client_payload.handoffSchemaPath -eq 'parity/schemas/terraform-handoff.schema.json' -and
            $payload.client_payload.handoffCommitSha -eq (Invoke-Git @('rev-parse', 'HEAD')) -and
            $payload.client_payload.handoffCommitSha -ne $payload.client_payload.sourceCommitSha -and
            $payload.client_payload.handoffCommitSha -ne $payload.client_payload.targetCommitSha -and
            $payload.client_payload.handoffDigest -eq (
                Get-NormalizedFileDigest (Join-Path $temp 'parity\handoffs\eligible.json')
            )
        ) ($payloadKeys -join ',')

        $raw = Get-Content $payloadFile -Raw
        Assert-Result 'The dispatch payload carries no diff, prose, credential, or Azure identifier' (
            $raw -notmatch '(?i)(password|client[_-]?secret|access[_-]?token|/subscriptions/)' -and
            $raw -notmatch '(?i)"(title|body|diff|patch|token)"'
        ) $raw
    }

    $eligiblePath = Join-Path $temp 'parity\handoffs\eligible.json'
    $eligibleText = Get-Content $eligiblePath -Raw
    $committedSha = Invoke-Git @('rev-parse', 'HEAD')
    Set-Content $eligiblePath ($eligibleText + [Environment]::NewLine) -Encoding utf8NoBOM
    $mismatch = Invoke-PublisherAtCommit -Arguments @(
        '-HandoffPath', 'parity/handoffs/eligible.json'
    ) -CommitSha $committedSha
    Assert-Result 'Uncommitted handoff bytes fail artifact verification' (
        $mismatch.ExitCode -ne 0 -and $mismatch.Output -match 'differs from its committed bytes'
    ) $mismatch.Output
    Set-Content $eligiblePath $eligibleText -Encoding utf8NoBOM

    $schemaPath = Join-Path $temp 'parity\schemas\terraform-handoff.schema.json'
    Remove-Item $schemaPath -Force
    $schemaMissingCommit = Commit-Fixture
    Copy-Item (Join-Path $repo 'parity\schemas\terraform-handoff.schema.json') $schemaPath
    $missingSchema = Invoke-PublisherAtCommit -Arguments @(
        '-HandoffPath', 'parity/handoffs/eligible.json'
    ) -CommitSha $schemaMissingCommit
    Assert-Result 'A commit without the handoff schema fails explicitly' (
        $missingSchema.ExitCode -ne 0 -and
        $missingSchema.Output -match 'terraform-handoff\.schema\.json' -and
        $missingSchema.Output -match 'absent'
    ) $missingSchema.Output

    Remove-Item $eligiblePath -Force
    $handoffMissingCommit = Commit-Fixture
    Set-Content $eligiblePath $eligibleText -Encoding utf8NoBOM
    $missingHandoff = Invoke-PublisherAtCommit -Arguments @(
        '-HandoffPath', 'parity/handoffs/eligible.json'
    ) -CommitSha $handoffMissingCommit
    Assert-Result 'A commit without the handoff record fails explicitly' (
        $missingHandoff.ExitCode -ne 0 -and
        $missingHandoff.Output -match 'eligible\.json' -and
        $missingHandoff.Output -match 'absent'
    ) $missingHandoff.Output

    $pending = Copy-JsonObject $eligible
    $pending.approval = [pscustomobject]@{ status = 'pending' }
    $pending.provenance.PSObject.Properties.Remove('inventoryCommitSha')
    $pending.provenance.PSObject.Properties.Remove('inventoryReviewUrl')
    Write-Json $pending (Join-Path $temp 'parity\handoffs\pending.json')
    $pendingResult = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/pending.json')
    Assert-Result 'A pending handoff is not dispatch-eligible' (
        $pendingResult.ExitCode -ne 0 -and $pendingResult.Output -match 'approved'
    ) $pendingResult.Output

    $foreignRepository = Copy-JsonObject $eligible
    $foreignRepository.target.repository = 'Azure/some-other-repository'
    Write-Json $foreignRepository (Join-Path $temp 'parity\handoffs\foreign-repository.json')
    $foreignRepositoryResult = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/foreign-repository.json')
    Assert-Result 'An unlisted target repository fails explicitly' (
        $foreignRepositoryResult.ExitCode -ne 0 -and $foreignRepositoryResult.Output -match 'allow-list'
    ) $foreignRepositoryResult.Output

    $foreignBranch = Copy-JsonObject $eligible
    $foreignBranch.target.ref = 'not-the-base-branch'
    Write-Json $foreignBranch (Join-Path $temp 'parity\handoffs\foreign-branch.json')
    $foreignBranchResult = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/foreign-branch.json')
    Assert-Result 'An unlisted target branch fails explicitly' (
        $foreignBranchResult.ExitCode -ne 0 -and $foreignBranchResult.Output -match 'allow-list'
    ) $foreignBranchResult.Output

    $stale = Copy-JsonObject $eligible
    $stale.source.commitSha = 'a' * 40
    Write-Json $stale (Join-Path $temp 'parity\handoffs\stale.json')
    $staleResult = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/stale.json')
    Assert-Result 'A stale baseline fails explicitly' (
        $staleResult.ExitCode -ne 0 -and $staleResult.Output -match 'stale'
    ) $staleResult.Output

    $outside = Invoke-Publisher @('-HandoffPath', 'parity/inventory.json')
    Assert-Result 'A handoff path outside the configured handoff records fails explicitly' (
        $outside.ExitCode -ne 0 -and $outside.Output -match 'handoff'
    ) $outside.Output

    $assessment = Get-Content (Join-Path $repo 'tests\parity\fixtures\source-pr.json') -Raw | ConvertFrom-Json -Depth 100
    $assessment.id = 'assessment-960-abcdef1'
    $assessment.sourcePr.number = 960
    $assessment.sourcePr.url = 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/960'
    $assessment.changedCapabilities = @('identity-rbac-automation')
    $assessment.outcome = 'proposal-required'
    $assessment.rationale = 'Reviewed fixture requires a Terraform proposal.'
    $assessment.review = [pscustomobject]@{
        status = 'approved'
        reviewer = 'parity-reviewer'
        approvalUrl = 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/960#pullrequestreview-1'
        reviewedAt = '2026-08-22T12:30:00Z'
    }
    Write-Json $assessment (Join-Path $temp '.parity-ledger\parity\assessments\assessment-960-abcdef1.json')

    $alignment = Copy-JsonObject $eligible
    $alignment.id = 'handoff-alignment-960'
    $alignment.capabilityIds = @('identity-rbac-automation')
    $alignment.provenance = [pscustomobject]@{
        type = 'alignment-assessment'
        assessmentId = 'assessment-960-abcdef1'
    }
    Write-Json $alignment (Join-Path $temp 'parity\handoffs\alignment.json')
    $alignmentResult = Invoke-Publisher @('-HandoffPath', 'parity/handoffs/alignment.json')
    Assert-Result 'An approved assessment-origin handoff dispatches with its source pull request' (
        $alignmentResult.ExitCode -eq 0 -and
        (Get-Content (Join-Path $temp $payloadPath) -Raw | ConvertFrom-Json -Depth 100).client_payload.sourcePrNumber -eq 960
    ) $alignmentResult.Output

    $closedInventory = Get-Content (Join-Path $temp 'parity\inventory.json') -Raw | ConvertFrom-Json -Depth 100
    foreach ($capability in $closedInventory.capabilities) {
        if ($capability.id -ne 'identity-rbac-automation') { continue }
        foreach ($scenario in $capability.scenarioAssessments) { $scenario.supportStatus = 'full' }
    }
    Write-Json $closedInventory (Join-Path $temp 'parity\closed-inventory.json')
    $noGap = Invoke-Publisher @(
        '-HandoffPath', 'parity/handoffs/alignment.json',
        '-InventoryPath', 'parity/closed-inventory.json'
    )
    Assert-Result 'A handoff without an open inventory gap fails explicitly' (
        $noGap.ExitCode -ne 0 -and $noGap.Output -match 'gap'
    ) $noGap.Output

    $rejectingDispatcher = Join-Path $temp 'reject.ps1'
    Set-Content $rejectingDispatcher 'param($PayloadPath); Write-Error "422 Unprocessable Entity"; exit 1' -Encoding utf8NoBOM
    $rejected = Invoke-Publisher @(
        '-HandoffPath', 'parity/handoffs/alignment.json',
        '-DispatchCommand', "pwsh,-NoProfile,-File,$rejectingDispatcher"
    )
    Assert-Result 'Target rejection fails explicitly and leaves the gap open' (
        $rejected.ExitCode -ne 0 -and $rejected.Output -match 'rejected'
    ) $rejected.Output

    $acceptingDispatcher = Join-Path $temp 'accept.ps1'
    Set-Content $acceptingDispatcher 'param($PayloadPath); Set-Content "$PayloadPath.sent" $PayloadPath -Encoding utf8NoBOM; exit 0' -Encoding utf8NoBOM
    $accepted = Invoke-Publisher @(
        '-HandoffPath', 'parity/handoffs/alignment.json',
        '-DispatchCommand', "pwsh,-NoProfile,-File,$acceptingDispatcher"
    )
    Assert-Result 'An accepted dispatch reports the published handoff' (
        $accepted.ExitCode -eq 0 -and
        $accepted.Output -match 'Dispatched' -and
        (Test-Path -LiteralPath (Join-Path $temp "$payloadPath.sent"))
    ) $accepted.Output

    if (-not (Test-Path -LiteralPath $workflowPath)) {
        Assert-Result 'Publication workflow exists' $false $workflowPath
    }
    else {
        $publishText = Get-Content $workflowPath -Raw
        Assert-Result 'Publication runs only behind a protected environment and an ephemeral App token' (
            $publishText -match '(?m)^\s+environment:\s*\S+' -and
            $publishText -match 'create-github-app-token@[0-9a-f]{40}' -and
            $publishText -match 'repositories:\s*terraform-azurerm-avm-ptn-aiml-landing-zone' -and
            $publishText -match 'Publish-TerraformHandoff\.ps1' -and
            $publishText -match '-HandoffCommitSha' -and
            $publishText -match '-HandoffRef' -and
            $publishText -match '-AssessmentsPath\s+''\.parity-ledger/parity/assessments'''
        ) $publishText
    }
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
