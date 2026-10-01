<#
.SYNOPSIS
    Finalizes or supersedes one append-only parity assessment record.

.DESCRIPTION
    Applies the supported outcome transitions for a merged-pull-request assessment
    and records auditable review metadata. Identity, source pull request, and
    baseline provenance are immutable; outcome and rationale are writable only while
    the outcome is pending, and a finalized record can only be superseded. An
    approved or rejected review is equally terminal and requires a reviewer, an
    absolute https decision URL, and a review timestamp.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory)] [string]$Path,
    [ValidateSet('no-terraform-impact', 'inventory-update', 'proposal-required', 'blocked', 'deferred', 'superseded')]
    [string]$Outcome,
    [string]$Rationale,
    [string[]]$HandoffId = @(),
    [string[]]$EvidenceLink = @(),
    [ValidateSet('approved', 'rejected', 'superseded')] [string]$ReviewStatus,
    [string]$Reviewer,
    [string]$ApprovalUrl,
    [string]$ReviewedAt,
    [string]$ConfigPath = 'parity/config.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

$finalOutcomes = @('no-terraform-impact', 'inventory-update', 'proposal-required', 'blocked', 'deferred')

function ConvertTo-ParityUtcTimestamp {
    param([Parameter(Mandatory)] [string]$Value)

    $parsed = [datetimeoffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::RoundtripKind
    if (-not [datetimeoffset]::TryParse($Value, [cultureinfo]::InvariantCulture, $styles, [ref]$parsed)) {
        Throw-ParityError "Review timestamp '$Value' is not a valid date and time." 'ParityInvalidTimestamp'
    }
    return $parsed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
}

function Expand-ParityList {
    param([string[]]$Value)

    return @(
        $Value |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist) | Out-Null
    $recordPath = Resolve-ParityPath -Root $rootPath -Path $Path -MustExist
    $record = Read-ParityJson $recordPath
    foreach ($field in @('id', 'sourcePr', 'baselineId', 'outcome', 'review')) {
        if ($record.PSObject.Properties.Name -notcontains $field) {
            Throw-ParityError "Record '$Path' is not a parity assessment: missing '$field'." 'ParityInvalidRecord'
        }
    }
    $immutableBefore = [ordered]@{
        schemaVersion = $record.schemaVersion
        id = $record.id
        sourcePr = $record.sourcePr
        baselineId = $record.baselineId
    } | ConvertTo-Json -Depth 100

    if (-not $Outcome -and -not $ReviewStatus -and $HandoffId.Count -eq 0 -and $EvidenceLink.Count -eq 0) {
        Throw-ParityError 'Specify an outcome, review status, handoff reference, or evidence link.' 'ParityNoChange'
    }

    $currentOutcome = $record.outcome
    $targetOutcome = if ($Outcome) { $Outcome } else { $currentOutcome }
    if ($Outcome) {
        if ($currentOutcome -eq 'superseded') {
            Throw-ParityError "Assessment '$($record.id)' is superseded and cannot change outcome." 'ParityTerminalAssessment'
        }
        if ($currentOutcome -ne 'pending' -and $Outcome -ne 'superseded') {
            Throw-ParityError (
                "Assessment '$($record.id)' is already '$currentOutcome'; record a superseded outcome and a replacement assessment instead."
            ) 'ParityImmutableOutcome'
        }
        if ([string]::IsNullOrWhiteSpace($Rationale)) {
            Throw-ParityError 'A non-pending outcome requires a rationale.' 'ParityMissingRationale'
        }
        $record.outcome = $Outcome
        $record.rationale = $Rationale.Trim()
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Rationale)) {
        if ($currentOutcome -ne 'pending') {
            Throw-ParityError (
                "Assessment '$($record.id)' is already '$currentOutcome'; its rationale is immutable. Record a superseded outcome and a replacement assessment instead."
            ) 'ParityImmutableOutcome'
        }
        $record.rationale = $Rationale.Trim()
    }

    $handoffIds = @(Expand-ParityList $HandoffId)
    if ($handoffIds.Count -gt 0) {
        if ($targetOutcome -ne 'proposal-required') {
            Throw-ParityError (
                "Handoff references require the 'proposal-required' outcome; assessment '$($record.id)' is '$targetOutcome'."
            ) 'ParityUnexpectedHandoff'
        }
        $invalid = @($handoffIds | Where-Object { $_ -notmatch '^handoff-[a-z0-9-]+$' })
        if ($invalid.Count -gt 0) {
            Throw-ParityError "Invalid handoff reference: $($invalid -join ', ')." 'ParityInvalidHandoff'
        }
        $record.handoffIds = @(@($record.handoffIds) + $handoffIds | Sort-Object -Unique)
    }

    $evidenceLinks = @(Expand-ParityList $EvidenceLink)
    if ($evidenceLinks.Count -gt 0) {
        $invalid = @($evidenceLinks | Where-Object { $_ -notmatch '^https://' })
        if ($invalid.Count -gt 0) {
            Throw-ParityError "Evidence links must be absolute https URLs: $($invalid -join ', ')." 'ParityInvalidEvidenceLink'
        }
        $existingLinks = if ($record.PSObject.Properties.Name -contains 'evidenceLinks') { @($record.evidenceLinks) } else { @() }
        $merged = @($existingLinks + $evidenceLinks | Sort-Object -Unique)
        if ($record.PSObject.Properties.Name -contains 'evidenceLinks') { $record.evidenceLinks = $merged }
        else { $record | Add-Member -NotePropertyName 'evidenceLinks' -NotePropertyValue $merged }
    }

    if ($ReviewStatus) {
        $currentReview = $record.review.status
        if ($currentReview -eq 'superseded') {
            Throw-ParityError (
                "Assessment '$($record.id)' review is superseded and cannot change review status."
            ) 'ParityImmutableReview'
        }
        if ($currentReview -in @('approved', 'rejected') -and $ReviewStatus -ne 'superseded') {
            Throw-ParityError (
                "Assessment '$($record.id)' is already $currentReview; supersede it instead of changing its review status."
            ) 'ParityImmutableReview'
        }
        if ($ReviewStatus -in @('approved', 'rejected')) {
            if ($targetOutcome -eq 'pending') {
                Throw-ParityError "A pending assessment cannot be $ReviewStatus; record its outcome first." 'ParityPendingOutcome'
            }
            foreach ($pair in @(@{ Name = 'reviewer'; Value = $Reviewer }, @{ Name = 'approvalUrl'; Value = $ApprovalUrl }, @{ Name = 'reviewedAt'; Value = $ReviewedAt })) {
                if ([string]::IsNullOrWhiteSpace($pair.Value)) {
                    Throw-ParityError "Recording a $ReviewStatus review requires review.$($pair.Name)." 'ParityMissingApproval'
                }
            }
            if ($ApprovalUrl -notmatch '^https://') {
                Throw-ParityError 'The review decision URL must be an absolute https URL.' 'ParityInvalidApprovalUrl'
            }
            if ($ApprovalUrl -match '/issues/136(?:$|[?#])') {
                Throw-ParityError 'Issue #136 is context, not assessment review evidence.' 'ParityInvalidApprovalUrl'
            }
        }
        $review = [ordered]@{ status = $ReviewStatus }
        foreach ($name in @('reviewer', 'approvalUrl', 'reviewedAt')) {
            if ($record.review.PSObject.Properties.Name -contains $name) { $review[$name] = $record.review.$name }
        }
        if ($Reviewer) { $review['reviewer'] = $Reviewer }
        if ($ApprovalUrl) { $review['approvalUrl'] = $ApprovalUrl }
        if ($ReviewedAt) { $review['reviewedAt'] = ConvertTo-ParityUtcTimestamp $ReviewedAt }
        $record.review = [pscustomobject]$review
    }

    $immutableAfter = [ordered]@{
        schemaVersion = $record.schemaVersion
        id = $record.id
        sourcePr = $record.sourcePr
        baselineId = $record.baselineId
    } | ConvertTo-Json -Depth 100
    if ($immutableAfter -cne $immutableBefore) {
        Throw-ParityError 'Assessment identity, source pull request, and baseline are immutable.' 'ParityImmutableTraceability'
    }

    Write-ParityFileAtomic -Path $recordPath -Content (ConvertTo-ParityStableJson $record)
    Write-Host "Updated assessment '$($record.id)': outcome '$($record.outcome)', review '$($record.review.status)'."
}
catch {
    Write-Error "$($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    exit 1
}
