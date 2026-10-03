<#
.SYNOPSIS
    Creates one idempotent pending parity assessment for a merged pull request.

.DESCRIPTION
    The idempotency key is source repository, pull request number, and merge commit
    SHA. Re-delivery of the same merged pull request returns the existing record and
    never rewrites it. Records are written only to the configured assessment ledger
    path, which the assessment workflow supplies from the dedicated ledger branch
    checkout.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory)] [int]$PullRequestNumber,
    [Parameter(Mandatory)] [string]$MergeCommitSha,
    [Parameter(Mandatory)] [string]$BaseBranch,
    [Parameter(Mandatory)] [string]$MergedAt,
    [Parameter(Mandatory)] [ValidateSet('true', 'false')] [string]$Merged,
    [string]$Repository,
    [string]$PullRequestUrl,
    [string[]]$ChangedCapabilities = @(),
    [string]$ConfigPath = 'parity/config.json',
    [string]$InventoryPath,
    [string]$LedgerPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

function ConvertTo-ParityUtcTimestamp {
    param([Parameter(Mandatory)] [string]$Value)

    $parsed = [datetimeoffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::RoundtripKind
    if (-not [datetimeoffset]::TryParse($Value, [cultureinfo]::InvariantCulture, $styles, [ref]$parsed)) {
        Throw-ParityError "Merged timestamp '$Value' is not a valid date and time." 'ParityInvalidTimestamp'
    }
    return $parsed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $config = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist)

    if ($Merged -ne 'true') {
        Throw-ParityError 'Only a merged pull request creates a parity assessment.' 'ParityNotMerged'
    }
    $integrationBranch = $config.branches.sourceIntegration
    if ($BaseBranch -ne $integrationBranch) {
        Throw-ParityError (
            "Base branch '$BaseBranch' is not the configured integration branch '$integrationBranch'."
        ) 'ParityUnexpectedBaseBranch'
    }
    $sourceRepository = if ($Repository) { $Repository } else { $config.repositories.source.name }
    if ($sourceRepository -ne $config.repositories.source.name) {
        Throw-ParityError (
            "Repository '$sourceRepository' is not the configured source repository '$($config.repositories.source.name)'."
        ) 'ParityUnexpectedRepository'
    }
    if ($MergeCommitSha -notmatch '^[0-9a-f]{40}$') {
        Throw-ParityError 'The merge commit SHA must be a full 40-character lowercase hexadecimal commit.' 'ParityInvalidCommit'
    }
    if ($PullRequestNumber -lt 1) {
        Throw-ParityError 'The pull request number must be a positive integer.' 'ParityInvalidPullRequest'
    }
    $expectedUrl = "https://github.com/$sourceRepository/pull/$PullRequestNumber"
    $url = if ($PullRequestUrl) { $PullRequestUrl } else { $expectedUrl }
    if ($url -ne $expectedUrl) {
        Throw-ParityError "Pull request URL '$url' does not match '$expectedUrl'." 'ParityInvalidPullRequest'
    }
    $mergedTimestamp = ConvertTo-ParityUtcTimestamp $MergedAt

    $inventorySetting = if ($InventoryPath) { $InventoryPath } else { $config.records.inventory }
    $inventory = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $inventorySetting -MustExist)
    if (
        $inventory.baseline.status -ne 'active' -or
        $inventory.baseline.source.commitSha -ne $config.repositories.source.commitSha -or
        $inventory.baseline.terraform.commitSha -ne $config.repositories.terraform.commitSha
    ) {
        Throw-ParityError 'The inventory baseline is stale or inactive.' 'ParityStaleBaseline'
    }

    $requestedCapabilities = @(
        $ChangedCapabilities |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    $knownCapabilityIds = @($inventory.capabilities | ForEach-Object { $_.id })
    $unknown = @($requestedCapabilities | Where-Object { $_ -notin $knownCapabilityIds })
    if ($unknown.Count -gt 0) {
        Throw-ParityError "Unknown capability: $($unknown -join ', ')." 'ParityUnknownCapability'
    }

    $ledgerSetting = if ($LedgerPath) { $LedgerPath } else { $config.records.assessments }
    $ledgerRoot = Resolve-ParityPath -Root $rootPath -Path $ledgerSetting
    if (-not (Test-Path -LiteralPath $ledgerRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $ledgerRoot -Force | Out-Null
    }

    $id = "assessment-$PullRequestNumber-$($MergeCommitSha.Substring(0, 7))"
    $recordPath = Join-Path $ledgerRoot "$id.json"
    $markerName = 'adoption-marker.json'
    foreach ($file in @(Get-ChildItem -LiteralPath $ledgerRoot -Filter '*.json' -File -Recurse | Sort-Object FullName)) {
        if ($file.Name -eq $markerName) { continue }
        $existing = Read-ParityJson $file.FullName
        if ($existing.PSObject.Properties.Name -notcontains 'sourcePr') { continue }
        if (
            $existing.sourcePr.repository -eq $sourceRepository -and
            $existing.sourcePr.number -eq $PullRequestNumber -and
            $existing.sourcePr.mergeCommitSha -eq $MergeCommitSha
        ) {
            Write-Host "Existing assessment '$($existing.id)' already covers pull request #$PullRequestNumber at $MergeCommitSha."
            exit 0
        }
        if ($existing.id -eq $id) {
            Throw-ParityError (
                "Assessment ID '$id' conflicts with an existing record for pull request #$($existing.sourcePr.number) at $($existing.sourcePr.mergeCommitSha)."
            ) 'ParityAssessmentConflict'
        }
    }

    $assessment = [ordered]@{
        schemaVersion = '1.0.0'
        id = $id
        sourcePr = [ordered]@{
            repository = $sourceRepository
            number = $PullRequestNumber
            url = $url
            mergeCommitSha = $MergeCommitSha
            baseBranch = $BaseBranch
            mergedAt = $mergedTimestamp
        }
        baselineId = $inventory.baseline.id
        changedCapabilities = $requestedCapabilities
        outcome = 'pending'
        rationale = ''
        handoffIds = @()
        review = [ordered]@{ status = 'pending' }
    }

    $serializable = $assessment | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    Write-ParityFileAtomic -Path $recordPath -Content (ConvertTo-ParityStableJson $serializable)
    Write-Host "Created pending assessment '$id' at $([IO.Path]::GetRelativePath($rootPath, $recordPath).Replace('\', '/'))."
}
catch {
    Write-Error "$($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    exit 1
}
