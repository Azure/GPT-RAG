<#
.SYNOPSIS
    Proves every integration-branch merge after the adoption marker has one assessment.

.DESCRIPTION
    Reads the dedicated assessment ledger and the adoption marker, enumerates
    first-parent integration-branch history after the adoption commit, and requires
    exactly one assessment for every merged pull request. A first-parent commit
    without a pull request reference cannot produce a merged pull-request event, so
    it fails the check unless -AllowUnattributedCommits is passed deliberately; that
    opt-out exists for a repository whose integration branch is not yet protected
    against direct pushes and it weakens the coverage guarantee.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ConfigPath = 'parity/config.json',
    [string]$LedgerPath,
    [string]$MarkerPath,
    [string]$GitRepositoryPath,
    [string]$Branch,
    [switch]$AllowUnattributedCommits
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-ParityGit {
    param(
        [Parameter(Mandatory)] [string]$RepositoryPath,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & git -C $RepositoryPath --no-pager @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        Throw-ParityError "git $($Arguments -join ' ') failed: $($output.Trim())" 'ParityGitFailed'
    }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output.Trim() }
}

function Resolve-ParityBranchRef {
    param([Parameter(Mandatory)] [string]$RepositoryPath, [Parameter(Mandatory)] [string]$Name)

    foreach ($candidate in @($Name, "refs/heads/$Name", "refs/remotes/origin/$Name")) {
        $result = Invoke-ParityGit -RepositoryPath $RepositoryPath -Arguments @('rev-parse', '--verify', '--quiet', "$candidate^{commit}") -AllowFailure
        if ($result.ExitCode -eq 0 -and $result.Output) { return $candidate }
    }
    Throw-ParityError "Branch '$Name' was not found in '$RepositoryPath'." 'ParityBranchNotFound'
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $config = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist)
    $ledgerSetting = if ($LedgerPath) { $LedgerPath } else { $config.records.assessments }
    $markerSetting = if ($MarkerPath) { $MarkerPath } else { $config.records.adoptionMarker }
    $branchName = if ($Branch) { $Branch } else { $config.branches.sourceIntegration }
    $repositoryPath = if ($GitRepositoryPath) { (Resolve-Path -LiteralPath $GitRepositoryPath).Path } else { $rootPath }

    $ledgerRoot = Resolve-ParityPath -Root $rootPath -Path $ledgerSetting -MustExist
    $markerFile = Resolve-ParityPath -Root $rootPath -Path $markerSetting -MustExist
    $marker = Read-ParityJson $markerFile
    if ($marker.ledgerBranch -ne $config.branches.assessmentLedger) {
        Throw-ParityError (
            "Adoption marker ledger branch '$($marker.ledgerBranch)' does not match the configured '$($config.branches.assessmentLedger)'."
        ) 'ParityInvalidMarker'
    }
    if ($marker.adoptionCommitSha -notmatch '^[0-9a-f]{40}$') {
        Throw-ParityError 'The adoption marker must pin a full 40-character commit.' 'ParityInvalidMarker'
    }

    $branchRef = Resolve-ParityBranchRef -RepositoryPath $repositoryPath -Name $branchName
    $ancestry = Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @(
        'merge-base', '--is-ancestor', $marker.adoptionCommitSha, $branchRef
    ) -AllowFailure
    if ($ancestry.ExitCode -ne 0) {
        Throw-ParityError (
            "Adoption commit $($marker.adoptionCommitSha) is not part of '$branchName'."
        ) 'ParityInvalidMarker'
    }

    $records = @(
        Get-ChildItem -LiteralPath $ledgerRoot -Filter '*.json' -File -Recurse |
            Sort-Object FullName |
            ForEach-Object { Read-ParityJson $_.FullName } |
            Where-Object { $_.PSObject.Properties.Name -contains 'sourcePr' }
    )
    foreach ($record in $records) {
        if ($record.sourcePr.baseBranch -ne $config.branches.sourceIntegration) {
            $failures.Add("Assessment '$($record.id)' does not target the configured integration branch.")
        }
    }

    $commits = @(
        (Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @(
            'rev-list', '--first-parent', '--reverse', "$($marker.adoptionCommitSha)..$branchRef"
        )).Output -split "`r?`n" | Where-Object { $_ }
    )

    $assessedCount = 0
    $unattributed = [System.Collections.Generic.List[string]]::new()
    foreach ($commit in $commits) {
        $subject = (Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @('log', '-1', '--format=%s', $commit)).Output
        $match = [regex]::Match($subject, '^Merge pull request #(?<number>[0-9]+)(?: |: )')
        if (-not $match.Success) { $match = [regex]::Match($subject, '\(#(?<number>[0-9]+)\)\s*$') }
        if (-not $match.Success) {
            $unattributed.Add("$($commit.Substring(0, 7)) $subject")
            continue
        }
        $number = [int]$match.Groups['number'].Value
        $matching = @($records | Where-Object {
            $_.sourcePr.number -eq $number -and $_.sourcePr.mergeCommitSha -eq $commit
        })
        if ($matching.Count -ne 1) {
            $failures.Add(
                "Merged pull request #$number at $($commit.Substring(0, 7)) has $($matching.Count) assessments; exactly one is required."
            )
            continue
        }
        $assessedCount++
    }

    foreach ($record in $records) {
        $reachable = Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @(
            'merge-base', '--is-ancestor', $record.sourcePr.mergeCommitSha, $branchRef
        ) -AllowFailure
        if ($reachable.ExitCode -ne 0) {
            $failures.Add(
                "Assessment '$($record.id)' references merge commit $($record.sourcePr.mergeCommitSha), which is not on '$branchName'."
            )
        }
    }

    if ($unattributed.Count -gt 0 -and -not $AllowUnattributedCommits) {
        foreach ($commit in $unattributed) {
            $failures.Add(
                "Commit $commit on '$branchName' has no pull request reference, so it cannot be assessed; protect the branch against direct pushes or rerun with -AllowUnattributedCommits."
            )
        }
    }

    if ($failures.Count -gt 0) {
        foreach ($failure in ($failures | Sort-Object -Unique)) { [Console]::Error.WriteLine($failure) }
        exit 1
    }

    foreach ($commit in $unattributed) {
        Write-Host "Note: unattributed commit accepted by -AllowUnattributedCommits: $commit"
    }
    Write-Host (
        'Assessment coverage passed: {0} merged pull requests after adoption commit {1} on {2}, {3} ledger records, {4} unattributed commits.' -f
        $assessedCount, $marker.adoptionCommitSha.Substring(0, 7), $branchName, $records.Count, $unattributed.Count
    )
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
