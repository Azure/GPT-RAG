<#
.SYNOPSIS
    Exercises merged-pull-request assessment creation, finalization, and ledger safety.

.DESCRIPTION
    Proves idempotent creation keyed by repository, pull request, and merge SHA;
    supported outcome transitions; immutable traceability, outcome, and rationale;
    terminal approval and rejection with equal review metadata; supersession;
    duplicate delivery; and non-torn parallel append-only ledger writes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$creator = Join-Path $repo 'scripts\parity\New-AlignmentAssessment.ps1'
$finalizer = Join-Path $repo 'scripts\parity\Set-AlignmentAssessment.ps1'
$jsonValidator = Join-Path $repo 'scripts\parity\Test-ParityJson.ps1'
$temp = Join-Path $PSScriptRoot ('.tmp-assessment-{0}' -f [guid]::NewGuid())
$ledger = 'parity/assessments'
$shaA = 'a' * 40
$shaB = 'b' * 40
$failures = 0

function Invoke-Script([string]$Path, [string[]]$Arguments) {
    $output = & pwsh -NoProfile -File $Path -Root $temp @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function New-Assessment([string[]]$Arguments) {
    Invoke-Script $creator $Arguments
}

function Set-Assessment([string[]]$Arguments) {
    Invoke-Script $finalizer $Arguments
}

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

function Get-LedgerFiles {
    @(Get-ChildItem -LiteralPath (Join-Path $temp 'parity\assessments') -Filter '*.json' -File -ErrorAction SilentlyContinue)
}

function Read-Record([string]$Name) {
    Get-Content (Join-Path $temp "parity\assessments\$Name") -Raw | ConvertFrom-Json -Depth 100
}

function New-BaseArguments([int]$Number, [string]$Sha) {
    @(
        '-PullRequestNumber', "$Number",
        '-MergeCommitSha', $Sha,
        '-BaseBranch', 'develop',
        '-MergedAt', '2026-08-22T12:00:00Z',
        '-Merged', 'true',
        '-ChangedCapabilities', 'identity-rbac-automation'
    )
}

try {
    New-Item (Join-Path $temp 'parity\assessments') -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $temp 'parity\config.json')
    Copy-Item (Join-Path $repo 'parity\inventory.json') (Join-Path $temp 'parity\inventory.json')

    $created = New-Assessment (New-BaseArguments 900 $shaA)
    $recordName = "assessment-900-$($shaA.Substring(0, 7)).json"
    $recordPath = Join-Path $temp "parity\assessments\$recordName"
    Assert-Result 'Merged pull request creates one pending assessment' (
        $created.ExitCode -eq 0 -and (Test-Path -LiteralPath $recordPath)
    ) $created.Output

    if (Test-Path -LiteralPath $recordPath) {
        $record = Read-Record $recordName
        Assert-Result 'Assessment records trusted merged-PR metadata' (
            $record.id -eq "assessment-900-$($shaA.Substring(0, 7))" -and
            $record.sourcePr.repository -eq 'Azure/bicep-ptn-aiml-landing-zone' -and
            $record.sourcePr.number -eq 900 -and
            $record.sourcePr.mergeCommitSha -eq $shaA -and
            $record.sourcePr.baseBranch -eq 'develop' -and
            $record.sourcePr.url -eq 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/900' -and
            $record.baselineId -eq 'baseline-v2.6.1-v0.5.1' -and
            $record.outcome -eq 'pending' -and
            $record.review.status -eq 'pending'
        ) ($record | ConvertTo-Json -Compress -Depth 10)

        $relative = [IO.Path]::GetRelativePath($repo, $recordPath)
        $schemaOutput = & pwsh -NoProfile -File $jsonValidator -Root $repo -Path $relative -Schema assessment 2>&1 | Out-String
        Assert-Result 'Created assessment is schema-valid' ($LASTEXITCODE -eq 0) $schemaOutput
    }

    $unmerged = New-Assessment @(
        '-PullRequestNumber', '901', '-MergeCommitSha', $shaB, '-BaseBranch', 'develop',
        '-MergedAt', '2026-08-22T12:00:00Z', '-Merged', 'false'
    )
    Assert-Result 'Closed-without-merge pull request creates no assessment' (
        $unmerged.ExitCode -ne 0 -and $unmerged.Output -match 'merged' -and (Get-LedgerFiles).Count -eq 1
    ) $unmerged.Output

    $wrongBranch = New-Assessment @(
        '-PullRequestNumber', '902', '-MergeCommitSha', $shaB, '-BaseBranch', 'main',
        '-MergedAt', '2026-08-22T12:00:00Z', '-Merged', 'true'
    )
    Assert-Result 'Non-integration base branch fails explicitly' (
        $wrongBranch.ExitCode -ne 0 -and $wrongBranch.Output -match 'integration branch'
    ) $wrongBranch.Output

    $unknownCapability = New-Assessment @(
        '-PullRequestNumber', '903', '-MergeCommitSha', $shaB, '-BaseBranch', 'develop',
        '-MergedAt', '2026-08-22T12:00:00Z', '-Merged', 'true',
        '-ChangedCapabilities', 'not-a-capability'
    )
    Assert-Result 'Unknown capability fails explicitly' (
        $unknownCapability.ExitCode -ne 0 -and $unknownCapability.Output -match 'Unknown capability'
    ) $unknownCapability.Output

    $originalBytes = [IO.File]::ReadAllBytes($recordPath)
    $duplicate = New-Assessment (New-BaseArguments 900 $shaA)
    $duplicateBytes = [IO.File]::ReadAllBytes($recordPath)
    Assert-Result 'Duplicate delivery returns the existing record without rewriting it' (
        $duplicate.ExitCode -eq 0 -and
        $duplicate.Output -match 'Existing assessment' -and
        (Get-LedgerFiles).Count -eq 1 -and
        [Linq.Enumerable]::SequenceEqual($originalBytes, $duplicateBytes)
    ) $duplicate.Output

    $reMerge = New-Assessment (New-BaseArguments 900 $shaB)
    Assert-Result 'A different merge SHA for the same pull request appends a new record' (
        $reMerge.ExitCode -eq 0 -and (Get-LedgerFiles).Count -eq 2
    ) $reMerge.Output

    $conflictPath = Join-Path $temp "parity\assessments\assessment-904-$($shaA.Substring(0, 7)).json"
    $conflict = Read-Record $recordName
    $conflict.id = "assessment-904-$($shaA.Substring(0, 7))"
    $conflict.sourcePr.number = 905
    $conflict | ConvertTo-Json -Depth 100 | Set-Content $conflictPath -Encoding utf8NoBOM
    $conflicting = New-Assessment (New-BaseArguments 904 $shaA)
    Assert-Result 'Conflicting existing record for the same ID fails explicitly' (
        $conflicting.ExitCode -ne 0 -and $conflicting.Output -match 'conflict'
    ) $conflicting.Output
    Remove-Item $conflictPath -Force

    $relativeRecord = "$ledger/$recordName"
    $emptyRationale = Set-Assessment @('-Path', $relativeRecord, '-Outcome', 'no-terraform-impact', '-Rationale', ' ')
    Assert-Result 'Final outcome without rationale fails explicitly' (
        $emptyRationale.ExitCode -ne 0 -and $emptyRationale.Output -match 'rationale'
    ) $emptyRationale.Output

    $unsupported = Set-Assessment @('-Path', $relativeRecord, '-Outcome', 'invented-outcome', '-Rationale', 'x')
    Assert-Result 'Unsupported outcome fails explicitly' ($unsupported.ExitCode -ne 0) $unsupported.Output

    $handoffOnNoImpact = Set-Assessment @(
        '-Path', $relativeRecord, '-Outcome', 'no-terraform-impact',
        '-Rationale', 'Coordination assets only.', '-HandoffId', 'handoff-security-baseline'
    )
    Assert-Result 'Handoff references require a proposal-required outcome' (
        $handoffOnNoImpact.ExitCode -ne 0 -and $handoffOnNoImpact.Output -match 'proposal-required'
    ) $handoffOnNoImpact.Output

    $outcomes = @('no-terraform-impact', 'inventory-update', 'proposal-required', 'blocked', 'deferred')
    $outcomeNumber = 910
    foreach ($outcome in $outcomes) {
        $outcomeSha = ('{0}' -f $outcomeNumber).PadLeft(4, '0') + ('c' * 36)
        $creation = New-Assessment (New-BaseArguments $outcomeNumber $outcomeSha)
        $name = "assessment-$outcomeNumber-$($outcomeSha.Substring(0, 7)).json"
        $result = Set-Assessment @(
            '-Path', "$ledger/$name", '-Outcome', $outcome,
            '-Rationale', "Reviewed decision for the $outcome outcome."
        )
        $record = Read-Record $name
        Assert-Result "Outcome '$outcome' is supported" (
            $creation.ExitCode -eq 0 -and $result.ExitCode -eq 0 -and $record.outcome -eq $outcome
        ) ($result.Output + $creation.Output)
        $outcomeNumber++
    }

    $traceabilityName = "assessment-910-$((('0910') + ('c' * 36)).Substring(0, 7)).json"
    $traceability = Read-Record $traceabilityName
    Assert-Result 'Finalization preserves immutable traceability' (
        $traceability.id -eq [IO.Path]::GetFileNameWithoutExtension($traceabilityName) -and
        $traceability.sourcePr.number -eq 910 -and
        $traceability.sourcePr.baseBranch -eq 'develop' -and
        $traceability.baselineId -eq 'baseline-v2.6.1-v0.5.1'
    ) ($traceability | ConvertTo-Json -Compress -Depth 10)

    $secondFinal = Set-Assessment @(
        '-Path', "$ledger/$traceabilityName", '-Outcome', 'deferred', '-Rationale', 'Changed my mind.'
    )
    Assert-Result 'A finalized assessment cannot silently change outcome' (
        $secondFinal.ExitCode -ne 0 -and $secondFinal.Output -match 'superseded'
    ) $secondFinal.Output

    $superseded = Set-Assessment @(
        '-Path', "$ledger/$traceabilityName", '-Outcome', 'superseded',
        '-Rationale', 'Superseded by a reviewed replacement assessment.'
    )
    $supersededRecord = Read-Record $traceabilityName
    Assert-Result 'A finalized assessment can be superseded' (
        $superseded.ExitCode -eq 0 -and $supersededRecord.outcome -eq 'superseded'
    ) $superseded.Output

    $afterSuperseded = Set-Assessment @(
        '-Path', "$ledger/$traceabilityName", '-Outcome', 'blocked', '-Rationale', 'Reopen.'
    )
    Assert-Result 'A superseded assessment is terminal' ($afterSuperseded.ExitCode -ne 0) $afterSuperseded.Output

    $proposalName = "assessment-912-$((('0912') + ('c' * 36)).Substring(0, 7)).json"
    $incompleteApproval = Set-Assessment @('-Path', "$ledger/$proposalName", '-ReviewStatus', 'approved')
    Assert-Result 'Approval without reviewer, URL, and timestamp fails explicitly' (
        $incompleteApproval.ExitCode -ne 0 -and $incompleteApproval.Output -match 'reviewer|approvalUrl|reviewedAt'
    ) $incompleteApproval.Output

    $contextApproval = Set-Assessment @(
        '-Path', "$ledger/$proposalName", '-ReviewStatus', 'approved', '-Reviewer', 'parity-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/136',
        '-ReviewedAt', '2026-08-22T12:30:00Z'
    )
    Assert-Result 'Issue #136 is rejected as assessment approval evidence' (
        $contextApproval.ExitCode -ne 0 -and $contextApproval.Output -match '136'
    ) $contextApproval.Output

    $approval = Set-Assessment @(
        '-Path', "$ledger/$proposalName", '-ReviewStatus', 'approved', '-Reviewer', 'parity-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/912#pullrequestreview-1',
        '-ReviewedAt', '2026-08-22T12:30:00Z'
    )
    $approvedRecord = Read-Record $proposalName
    $approvedRaw = Get-Content (Join-Path $temp "parity\assessments\$proposalName") -Raw
    Assert-Result 'Approved review records reviewer, URL, and timestamp' (
        $approval.ExitCode -eq 0 -and
        $approvedRecord.review.status -eq 'approved' -and
        $approvedRecord.review.reviewer -eq 'parity-reviewer' -and
        $approvedRaw -match '"reviewedAt": "2026-08-22T12:30:00Z"' -and
        $approvedRaw -match '"approvalUrl": "https://github\.com/Azure/bicep-ptn-aiml-landing-zone/pull/912#pullrequestreview-1"'
    ) ("exit=$($approval.ExitCode) " + $approval.Output + $approvedRaw)

    $immutableName = "assessment-911-$((('0911') + ('c' * 36)).Substring(0, 7)).json"
    $immutablePath = Join-Path $temp "parity\assessments\$immutableName"
    $beforeRationaleBytes = [IO.File]::ReadAllBytes($immutablePath)
    $rationaleRewrite = Set-Assessment @(
        '-Path', "$ledger/$immutableName", '-Rationale', 'Quietly reinterpreted after the fact.',
        '-EvidenceLink', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/911'
    )
    $afterRationaleBytes = [IO.File]::ReadAllBytes($immutablePath)
    Assert-Result 'A finalized rationale cannot be rewritten alongside another mutation' (
        $rationaleRewrite.ExitCode -ne 0 -and
        $rationaleRewrite.Output -match 'immutable' -and
        [Linq.Enumerable]::SequenceEqual($beforeRationaleBytes, $afterRationaleBytes)
    ) $rationaleRewrite.Output

    $pendingRationale = Set-Assessment @(
        '-Path', $relativeRecord, '-Rationale', 'Draft reasoning while the outcome is still pending.',
        '-EvidenceLink', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/900'
    )
    Assert-Result 'A pending assessment still accepts a rationale' (
        $pendingRationale.ExitCode -eq 0 -and
        (Read-Record $recordName).rationale -eq 'Draft reasoning while the outcome is still pending.'
    ) $pendingRationale.Output

    $rejectionSha = '0916' + ('d' * 36)
    $rejectionName = "assessment-916-$($rejectionSha.Substring(0, 7)).json"
    $rejectionCreated = New-Assessment (New-BaseArguments 916 $rejectionSha)
    $pendingRejection = Set-Assessment @('-Path', "$ledger/$rejectionName", '-ReviewStatus', 'rejected')
    Assert-Result 'A pending assessment cannot be rejected before its outcome is recorded' (
        $rejectionCreated.ExitCode -eq 0 -and
        $pendingRejection.ExitCode -ne 0 -and
        $pendingRejection.Output -match 'record its outcome first'
    ) ($rejectionCreated.Output + $pendingRejection.Output)

    Set-Assessment @(
        '-Path', "$ledger/$rejectionName", '-Outcome', 'proposal-required',
        '-Rationale', 'The merged change needs a Terraform proposal.'
    ) | Out-Null
    $incompleteRejection = Set-Assessment @('-Path', "$ledger/$rejectionName", '-ReviewStatus', 'rejected')
    Assert-Result 'Rejection without reviewer, URL, and timestamp fails explicitly' (
        $incompleteRejection.ExitCode -ne 0 -and
        $incompleteRejection.Output -match 'reviewer|approvalUrl|reviewedAt' -and
        (Read-Record $rejectionName).review.status -eq 'pending'
    ) $incompleteRejection.Output

    $rejection = Set-Assessment @(
        '-Path', "$ledger/$rejectionName", '-ReviewStatus', 'rejected', '-Reviewer', 'parity-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/916#pullrequestreview-2',
        '-ReviewedAt', '2026-08-22T13:00:00Z'
    )
    $rejectedRecord = Read-Record $rejectionName
    $rejectedRaw = Get-Content (Join-Path $temp "parity\assessments\$rejectionName") -Raw
    Assert-Result 'Rejection records the same reviewer, URL, and timestamp as approval' (
        $rejection.ExitCode -eq 0 -and
        $rejectedRecord.review.status -eq 'rejected' -and
        $rejectedRecord.review.reviewer -eq 'parity-reviewer' -and
        $rejectedRaw -match '"approvalUrl": "https://github\.com/Azure/bicep-ptn-aiml-landing-zone/pull/916#pullrequestreview-2"' -and
        $rejectedRaw -match '"reviewedAt": "2026-08-22T13:00:00Z"'
    ) ($rejection.Output + $rejectedRaw)

    $rejectedRelative = [IO.Path]::GetRelativePath($repo, (Join-Path $temp "parity\assessments\$rejectionName"))
    $rejectedSchema = & pwsh -NoProfile -File $jsonValidator -Root $repo -Path $rejectedRelative -Schema assessment 2>&1 | Out-String
    Assert-Result 'A rejected record with full metadata is schema-valid' ($LASTEXITCODE -eq 0) $rejectedSchema

    $rejectedBytes = [IO.File]::ReadAllBytes((Join-Path $temp "parity\assessments\$rejectionName"))
    $reapproval = Set-Assessment @(
        '-Path', "$ledger/$rejectionName", '-ReviewStatus', 'approved', '-Reviewer', 'other-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/916#pullrequestreview-3',
        '-ReviewedAt', '2026-08-22T13:30:00Z'
    )
    Assert-Result 'A rejected review cannot be turned into an approval' (
        $reapproval.ExitCode -ne 0 -and
        $reapproval.Output -match 'supersede' -and
        [Linq.Enumerable]::SequenceEqual(
            $rejectedBytes, [IO.File]::ReadAllBytes((Join-Path $temp "parity\assessments\$rejectionName"))
        )
    ) $reapproval.Output

    $rejectedSupersession = Set-Assessment @('-Path', "$ledger/$rejectionName", '-ReviewStatus', 'superseded')
    $supersededReview = Read-Record $rejectionName
    $supersededRaw = Get-Content (Join-Path $temp "parity\assessments\$rejectionName") -Raw
    Assert-Result 'A rejected review can only be superseded, and its decision metadata is retained' (
        $rejectedSupersession.ExitCode -eq 0 -and
        $supersededReview.review.status -eq 'superseded' -and
        $supersededReview.review.reviewer -eq 'parity-reviewer' -and
        $supersededRaw -match '"reviewedAt": "2026-08-22T13:00:00Z"'
    ) ($rejectedSupersession.Output + $supersededRaw)

    $afterSupersededReview = Set-Assessment @(
        '-Path', "$ledger/$rejectionName", '-ReviewStatus', 'rejected', '-Reviewer', 'parity-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/916#pullrequestreview-4',
        '-ReviewedAt', '2026-08-22T14:00:00Z'
    )
    Assert-Result 'A superseded review is terminal' (
        $afterSupersededReview.ExitCode -ne 0 -and $afterSupersededReview.Output -match 'superseded'
    ) $afterSupersededReview.Output

    $atomicSha = 'e' * 40
    $atomicName = "assessment-920-$($atomicSha.Substring(0, 7)).json"
    $baselineRoot = Join-Path $temp 'single-run-baseline'
    New-Item (Join-Path $baselineRoot 'parity\assessments') -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $temp 'parity\config.json') (Join-Path $baselineRoot 'parity\config.json')
    Copy-Item (Join-Path $temp 'parity\inventory.json') (Join-Path $baselineRoot 'parity\inventory.json')
    $baselineRun = & pwsh -NoProfile -File $creator -Root $baselineRoot `
        -PullRequestNumber 920 -MergeCommitSha $atomicSha -BaseBranch develop `
        -MergedAt '2026-08-22T12:00:00Z' -Merged true 2>&1 | Out-String
    $baselineBytes = [IO.File]::ReadAllBytes((Join-Path $baselineRoot "parity\assessments\$atomicName"))

    $sameKeyJobs = 1..4 | ForEach-Object {
        Start-Job -ScriptBlock {
            param($script, $root, $sha)
            & pwsh -NoProfile -File $script -Root $root `
                -PullRequestNumber 920 -MergeCommitSha $sha -BaseBranch develop `
                -MergedAt '2026-08-22T12:00:00Z' -Merged true 2>&1 | Out-String
        } -ArgumentList $creator, $temp, $atomicSha
    }
    $sameKeyJobs | Wait-Job | Out-Null
    $sameKeyJobs | Receive-Job | Out-Null
    $sameKeyJobs | Remove-Job
    $atomicRecords = @(Get-LedgerFiles | Where-Object { $_.Name -like 'assessment-920-*' })
    $atomicBytes = [byte[]]::new(0)
    if ($atomicRecords.Count -eq 1) { $atomicBytes = [IO.File]::ReadAllBytes($atomicRecords[0].FullName) }
    Assert-Result 'Repeated parallel deliveries of one merge stay idempotent and are never torn' (
        $baselineRun -match 'Created pending assessment' -and
        $atomicRecords.Count -eq 1 -and
        [Linq.Enumerable]::SequenceEqual($baselineBytes, $atomicBytes)
    ) ("records=$($atomicRecords.Count); baselineBytes=$($baselineBytes.Length); observedBytes=$($atomicBytes.Length)")

    $distinctJobs = 930..933 | ForEach-Object {
        Start-Job -ScriptBlock {
            param($script, $root, $number)
            $sha = ('{0}' -f $number) + ('f' * 37)
            & pwsh -NoProfile -File $script -Root $root `
                -PullRequestNumber $number -MergeCommitSha $sha -BaseBranch develop `
                -MergedAt '2026-08-22T12:00:00Z' -Merged true 2>&1 | Out-String
        } -ArgumentList $creator, $temp, $_
    }
    $distinctJobs | Wait-Job | Out-Null
    $distinctJobs | Receive-Job | Out-Null
    $distinctJobs | Remove-Job
    $distinctRecords = @(Get-LedgerFiles | Where-Object { $_.Name -match 'assessment-93[0-3]-' })
    $distinctValid = $true
    foreach ($file in $distinctRecords) {
        try { Get-Content $file.FullName -Raw | ConvertFrom-Json -Depth 100 | Out-Null }
        catch { $distinctValid = $false }
    }
    Assert-Result 'Parallel distinct deliveries append one intact record each' (
        $distinctRecords.Count -eq 4 -and $distinctValid
    ) ("records=$($distinctRecords.Count)")
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
