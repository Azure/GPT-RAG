<#
.SYNOPSIS
    Proves a ledger checkout contains only appended parity assessment records.

.DESCRIPTION
    Guards the dedicated assessment ledger branch before anything is committed.
    The working tree may only add new JSON records under the configured assessment
    path of the configured ledger branch. Modifications, deletions, renames, files
    outside that path, and any checkout that is not on the ledger branch fail
    explicitly, so history stays append-only and the integration branch is never
    written by the assessment workflow.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ConfigPath = 'parity/config.json',
    [string]$GitRepositoryPath = '.',
    [string]$LedgerPathPrefix,
    [string]$Branch
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

function Invoke-ParityGit {
    param(
        [Parameter(Mandatory)] [string]$RepositoryPath,
        [Parameter(Mandatory)] [string[]]$Arguments
    )

    $output = & git -C $RepositoryPath --no-pager @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Throw-ParityError "git $($Arguments -join ' ') failed: $($output.Trim())" 'ParityGitFailed'
    }
    return $output
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $config = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist)
    $ledgerBranch = if ($Branch) { $Branch } else { $config.branches.assessmentLedger }
    $prefixSetting = if ($LedgerPathPrefix) { $LedgerPathPrefix } else { $config.records.assessments }
    $prefix = $prefixSetting.Trim('/')
    if (-not (Test-Path -LiteralPath $GitRepositoryPath -PathType Container)) {
        Throw-ParityError "Ledger checkout '$GitRepositoryPath' does not exist." 'ParityPathNotFound'
    }
    $repositoryPath = (Resolve-Path -LiteralPath $GitRepositoryPath).Path

    $currentBranch = (Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Trim()
    if ($currentBranch -ne $ledgerBranch) {
        Throw-ParityError (
            "Assessments are appended only to the dedicated ledger branch '$ledgerBranch'; the checkout is on '$currentBranch'."
        ) 'ParityLedgerBranchMismatch'
    }

    $status = @(
        (Invoke-ParityGit -RepositoryPath $repositoryPath -Arguments @(
            'status', '--porcelain', '--untracked-files=all'
        )) -split "`r?`n" | Where-Object { $_ }
    )
    $appended = [System.Collections.Generic.List[string]]::new()
    $rejected = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $status) {
        $code = $entry.Substring(0, 2)
        $path = $entry.Substring(3)
        if ($code -notin @('??', 'A ', 'A?')) {
            $rejected.Add("$code $path (only new records may be appended)")
            continue
        }
        if ($path.StartsWith('"') -or $path.Contains(' -> ')) {
            $rejected.Add("$code $path (renamed or quoted paths are not appended records)")
            continue
        }
        if ($path -notmatch "^$([regex]::Escape($prefix))/[^/]+\.json$") {
            $rejected.Add("$code $path (outside $prefix/*.json)")
            continue
        }
        $appended.Add($path)
    }

    if ($rejected.Count -gt 0) {
        Throw-ParityError (
            "The ledger accepts appended assessment records only: $(($rejected | Sort-Object) -join '; ')"
        ) 'ParityLedgerNotAppendOnly'
    }

    Write-Host (
        "Ledger append-only check passed on '{0}': {1} new record(s){2}." -f
        $ledgerBranch, $appended.Count,
        $(if ($appended.Count -gt 0) { " ($(($appended | Sort-Object) -join ', '))" } else { '' })
    )
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
