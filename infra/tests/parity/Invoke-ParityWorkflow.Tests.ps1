<#
.SYNOPSIS
    Proves end-to-end traceability from a merged pull request to a proposal reference.

.DESCRIPTION
    Runs the merged-pull-request fixture through assessment creation, reviewed
    finalization and approval, handoff generation and approval, bounded dispatch,
    duplicate reconciliation, and aggregate validation, then asserts the complete
    reference chain.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$creator = Join-Path $repo 'scripts\parity\New-AlignmentAssessment.ps1'
$finalizer = Join-Path $repo 'scripts\parity\Set-AlignmentAssessment.ps1'
$handoffGenerator = Join-Path $repo 'scripts\parity\New-TerraformHandoff.ps1'
$publisher = Join-Path $repo 'scripts\parity\Publish-TerraformHandoff.ps1'
$assetValidator = Join-Path $repo 'scripts\parity\Test-ParityAssets.ps1'
$event = Get-Content (Join-Path $PSScriptRoot 'fixtures\merged-pr-event.json') -Raw | ConvertFrom-Json -Depth 20
$temp = Join-Path $PSScriptRoot ('.tmp-workflow-{0}' -f [guid]::NewGuid())
$capability = 'identity-rbac-automation'
$assessmentId = "assessment-$($event.pull_request.number)-$($event.pull_request.merge_commit_sha.Substring(0, 7))"
$assessmentRelative = ".parity-ledger/parity/assessments/$assessmentId.json"
$handoffRelative = 'parity/handoffs/security/alignment-970.json'
$proposalUrl = 'https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/999'
$failures = 0
$commitNumber = 0

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

function Invoke-Step([string]$Path, [string[]]$Arguments) {
    $output = & pwsh -NoProfile -File $Path -Root $temp @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Read-TempJson([string]$RelativePath) {
    Get-Content (Join-Path $temp ($RelativePath -replace '/', '\')) -Raw | ConvertFrom-Json -Depth 100
}

function Write-TempJson($Value, [string]$RelativePath) {
    $Value | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $temp ($RelativePath -replace '/', '\')) -Encoding utf8NoBOM
}

function Invoke-Git([string[]]$Arguments) {
    $output = & git -C $temp -c user.name='Parity Test' -c user.email='parity@example.invalid' @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
    return $output.Trim()
}

function Commit-TempFixture {
    Remove-Item (Join-Path $temp 'payload.json') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $temp 'payload.json.sent') -Force -ErrorAction SilentlyContinue
    Invoke-Git @('add', '-A') | Out-Null
    & git -C $temp diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        $script:commitNumber++
        Invoke-Git @('commit', '-m', "test: workflow fixture $script:commitNumber") | Out-Null
    }
    return Invoke-Git @('rev-parse', 'HEAD')
}

function Invoke-PublisherStep([string[]]$Arguments) {
    $commitSha = Commit-TempFixture
    $publisherArguments = @(
        '-HandoffCommitSha', $commitSha, '-HandoffRef', 'develop',
        '-AssessmentsPath', '.parity-ledger/parity/assessments'
    ) + $Arguments
    return Invoke-Step -Path $publisher -Arguments $publisherArguments
}

try {
    New-Item -ItemType Directory (Join-Path $temp '.parity-ledger\parity\assessments') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $temp 'parity\schemas') -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $temp 'parity\config.json')
    Copy-Item (Join-Path $repo 'parity\inventory.json') (Join-Path $temp 'parity\inventory.json')
    Copy-Item (Join-Path $repo 'parity\handoffs') (Join-Path $temp 'parity\handoffs') -Recurse
    Copy-Item (Join-Path $repo 'parity\assessments\adoption-marker.json') `
        (Join-Path $temp '.parity-ledger\parity\assessments\adoption-marker.json')
    Copy-Item (Join-Path $repo 'parity\schemas\terraform-handoff.schema.json') `
        (Join-Path $temp 'parity\schemas\terraform-handoff.schema.json')
    Invoke-Git @('init', '--initial-branch', 'develop') | Out-Null

    $created = Invoke-Step $creator @(
        '-Repository', $event.repository.full_name,
        '-PullRequestNumber', "$($event.pull_request.number)",
        '-MergeCommitSha', $event.pull_request.merge_commit_sha,
        '-BaseBranch', $event.pull_request.base.ref,
        '-MergedAt', '2026-08-22T12:00:00Z',
        '-Merged', "$($event.pull_request.merged)".ToLowerInvariant(),
        '-ChangedCapabilities', $capability,
        '-LedgerPath', '.parity-ledger/parity/assessments'
    )
    Assert-Result 'A merged pull request fixture creates one pending assessment' (
        $created.ExitCode -eq 0 -and (Test-Path -LiteralPath (Join-Path $temp ($assessmentRelative -replace '/', '\')))
    ) $created.Output

    $finalized = Invoke-Step $finalizer @(
        '-Path', $assessmentRelative, '-Outcome', 'proposal-required',
        '-Rationale', 'The merged change alters consumer-visible identity and role-assignment behavior that Terraform does not yet reproduce.'
    )
    $approved = Invoke-Step $finalizer @(
        '-Path', $assessmentRelative, '-ReviewStatus', 'approved', '-Reviewer', 'parity-reviewer',
        '-ApprovalUrl', 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/970#pullrequestreview-1',
        '-ReviewedAt', '2026-08-22T12:30:00Z'
    )
    Assert-Result 'The assessment reaches an approved proposal-required decision' (
        $finalized.ExitCode -eq 0 -and $approved.ExitCode -eq 0 -and
        (Read-TempJson $assessmentRelative).review.status -eq 'approved'
    ) ($finalized.Output + $approved.Output)

    $handoff = Invoke-Step $handoffGenerator @(
        '-Id', 'handoff-alignment-970', '-OutputPath', $handoffRelative,
        '-ProvenanceType', 'alignment-assessment', '-AssessmentPath', $assessmentRelative,
        '-CapabilityIds', $capability
    )
    Assert-Result 'The approved assessment generates one pending handoff' (
        $handoff.ExitCode -eq 0 -and (Read-TempJson $handoffRelative).approval.status -eq 'pending'
    ) $handoff.Output

    $pendingDispatch = Invoke-PublisherStep @(
        '-HandoffPath', $handoffRelative, '-PayloadPath', 'payload.json'
    )
    Assert-Result 'A pending handoff cannot be published' (
        $pendingDispatch.ExitCode -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $temp 'payload.json'))
    ) $pendingDispatch.Output

    $handoffRecord = Read-TempJson $handoffRelative
    $handoffRecord.approval = [pscustomobject]@{
        status = 'approved'
        approvalUrl = 'https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/970#issuecomment-1'
        approvedBy = 'parity-reviewer'
        approvedAt = '2026-08-22T12:45:00Z'
    }
    Write-TempJson $handoffRecord $handoffRelative
    $linked = Invoke-Step $finalizer @('-Path', $assessmentRelative, '-HandoffId', 'handoff-alignment-970')
    Assert-Result 'The assessment records its approved handoff' (
        $linked.ExitCode -eq 0 -and
        (Read-TempJson $assessmentRelative).handoffIds -contains 'handoff-alignment-970'
    ) $linked.Output

    $dispatcher = Join-Path $temp 'dispatch.ps1'
    Set-Content $dispatcher 'param($PayloadPath); Copy-Item $PayloadPath "$PayloadPath.sent" -Force; exit 0' -Encoding utf8NoBOM
    $dispatched = Invoke-PublisherStep @(
        '-HandoffPath', $handoffRelative, '-PayloadPath', 'payload.json',
        '-DispatchCommand', "pwsh,-NoProfile,-File,$dispatcher"
    )
    $payload = Read-TempJson 'payload.json'
    Assert-Result 'The approved handoff dispatches a bounded, traceable payload' (
        $dispatched.ExitCode -eq 0 -and
        $payload.client_payload.provenanceId -eq $assessmentId -and
        $payload.client_payload.sourcePrNumber -eq $event.pull_request.number -and
        $payload.client_payload.payloadVersion -eq '2.0.0' -and
        $payload.client_payload.handoffCommitSha -cmatch '^[0-9a-f]{40}$' -and
        @($payload.client_payload.capabilityIds) -contains $capability -and
        (Test-Path -LiteralPath (Join-Path $temp 'payload.json.sent'))
    ) $dispatched.Output

    $handoffRecord = Read-TempJson $handoffRelative
    $handoffRecord | Add-Member -NotePropertyName 'terraformPullRequestUrl' -NotePropertyValue $proposalUrl
    Write-TempJson $handoffRecord $handoffRelative
    Remove-Item (Join-Path $temp 'payload.json') -Force
    $reconciled = Invoke-PublisherStep @(
        '-HandoffPath', $handoffRelative, '-PayloadPath', 'payload.json',
        '-DispatchCommand', "pwsh,-NoProfile,-File,$dispatcher"
    )
    Assert-Result 'A recorded proposal reference prevents a second proposal' (
        $reconciled.ExitCode -eq 0 -and
        $reconciled.Output -match [regex]::Escape($proposalUrl) -and
        -not (Test-Path -LiteralPath (Join-Path $temp 'payload.json'))
    ) $reconciled.Output

    $tempRelative = [IO.Path]::GetRelativePath($repo, $temp).Replace('\', '/')
    $validated = & pwsh -NoProfile -File $assetValidator -Root $repo `
        -InventoryPath "$tempRelative/parity/inventory.json" `
        -AssessmentsPath "$tempRelative/.parity-ledger/parity/assessments" `
        -HandoffsPath "$tempRelative/parity/handoffs" 2>&1 | Out-String
    Assert-Result 'The complete chain passes aggregate parity validation' (
        $LASTEXITCODE -eq 0 -and $validated -match '1 assessments, 6 handoffs'
    ) $validated

    $assessmentRecord = Read-TempJson $assessmentRelative
    $handoffRecord = Read-TempJson $handoffRelative
    Assert-Result 'Merged pull request, assessment, handoff, and proposal remain linked' (
        $assessmentRecord.sourcePr.number -eq $event.pull_request.number -and
        $assessmentRecord.sourcePr.mergeCommitSha -eq $event.pull_request.merge_commit_sha -and
        $assessmentRecord.handoffIds -contains $handoffRecord.id -and
        $handoffRecord.provenance.assessmentId -eq $assessmentRecord.id -and
        $handoffRecord.capabilityIds -contains $capability -and
        $handoffRecord.terraformPullRequestUrl -eq $proposalUrl
    ) ($assessmentRecord | ConvertTo-Json -Depth 10 -Compress)
    Assert-Result 'The continuous path reads assessments only from the dedicated ledger location' (
        -not (Test-Path -LiteralPath (Join-Path $temp 'parity\assessments')) -and
        (Test-Path -LiteralPath (Join-Path $temp ($assessmentRelative -replace '/', '\')))
    ) $assessmentRelative
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
