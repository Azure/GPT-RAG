<#
.SYNOPSIS
    Proves the assessment ledger guard accepts only appended records.

.DESCRIPTION
    Runs scripts/parity/Test-LedgerAppendOnly.ps1 against temporary Git repositories
    and asserts that a new assessment record is accepted while modification,
    deletion, rename, foreign path, and a checkout on the integration branch are all
    rejected explicitly.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$guard = Join-Path $repo 'scripts\parity\Test-LedgerAppendOnly.ps1'
$config = Get-Content (Join-Path $repo 'parity\config.json') -Raw | ConvertFrom-Json -Depth 20
$ledgerBranch = $config.branches.assessmentLedger
$integrationBranch = $config.branches.sourceIntegration
$temp = Join-Path $PSScriptRoot ('.tmp-ledger-{0}' -f [guid]::NewGuid())
$failures = 0

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

function Invoke-Git([string]$RepositoryPath, [string[]]$Arguments) {
    $output = & git -C $RepositoryPath -c user.name='Parity Test' -c user.email='parity@example.invalid' @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
    return $output.Trim()
}

function New-LedgerRepository([string]$Name, [string]$Branch) {
    $path = Join-Path $temp $Name
    New-Item -ItemType Directory (Join-Path $path 'parity\assessments') -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $path 'parity\config.json')
    Set-Content (Join-Path $path 'parity\assessments\assessment-100-aaaaaaa.json') '{ "id": "assessment-100-aaaaaaa" }' -Encoding utf8NoBOM
    Set-Content (Join-Path $path 'README.md') 'ledger branch readme' -Encoding utf8NoBOM
    Invoke-Git $path @('init', '--initial-branch', $Branch) | Out-Null
    Invoke-Git $path @('add', '.') | Out-Null
    Invoke-Git $path @('commit', '-m', 'chore(parity): seed ledger') | Out-Null
    return $path
}

function Invoke-Guard([string]$RepositoryPath) {
    $output = & pwsh -NoProfile -File $guard -Root $RepositoryPath -GitRepositoryPath $RepositoryPath 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
    New-Item -ItemType Directory $temp -Force | Out-Null

    $clean = New-LedgerRepository 'clean' $ledgerBranch
    $cleanResult = Invoke-Guard $clean
    Assert-Result 'A clean ledger checkout passes with zero appended records' (
        $cleanResult.ExitCode -eq 0 -and $cleanResult.Output -match '0 new record'
    ) $cleanResult.Output

    $appended = New-LedgerRepository 'appended' $ledgerBranch
    Set-Content (Join-Path $appended 'parity\assessments\assessment-200-bbbbbbb.json') '{ "id": "assessment-200-bbbbbbb" }' -Encoding utf8NoBOM
    $appendedResult = Invoke-Guard $appended
    Assert-Result 'A new untracked assessment record is accepted' (
        $appendedResult.ExitCode -eq 0 -and
        $appendedResult.Output -match '1 new record' -and
        $appendedResult.Output -match 'assessment-200-bbbbbbb\.json'
    ) $appendedResult.Output

    $staged = New-LedgerRepository 'staged' $ledgerBranch
    Set-Content (Join-Path $staged 'parity\assessments\assessment-201-ccccccc.json') '{ "id": "assessment-201-ccccccc" }' -Encoding utf8NoBOM
    Invoke-Git $staged @('add', 'parity/assessments') | Out-Null
    $stagedResult = Invoke-Guard $staged
    Assert-Result 'A staged new assessment record is accepted' (
        $stagedResult.ExitCode -eq 0 -and $stagedResult.Output -match '1 new record'
    ) $stagedResult.Output

    $modified = New-LedgerRepository 'modified' $ledgerBranch
    Set-Content (Join-Path $modified 'parity\assessments\assessment-100-aaaaaaa.json') '{ "id": "assessment-100-aaaaaaa", "outcome": "rewritten" }' -Encoding utf8NoBOM
    $modifiedResult = Invoke-Guard $modified
    Assert-Result 'Modifying an existing record is rejected' (
        $modifiedResult.ExitCode -ne 0 -and
        $modifiedResult.Output -match 'appended assessment records only' -and
        $modifiedResult.Output -match 'assessment-100-aaaaaaa\.json'
    ) $modifiedResult.Output

    $deleted = New-LedgerRepository 'deleted' $ledgerBranch
    Remove-Item (Join-Path $deleted 'parity\assessments\assessment-100-aaaaaaa.json') -Force
    $deletedResult = Invoke-Guard $deleted
    Assert-Result 'Deleting an existing record is rejected' (
        $deletedResult.ExitCode -ne 0 -and $deletedResult.Output -match 'appended assessment records only'
    ) $deletedResult.Output

    $renamed = New-LedgerRepository 'renamed' $ledgerBranch
    Invoke-Git $renamed @('mv', 'parity/assessments/assessment-100-aaaaaaa.json', 'parity/assessments/assessment-100-renamed.json') | Out-Null
    $renamedResult = Invoke-Guard $renamed
    Assert-Result 'Renaming an existing record is rejected' (
        $renamedResult.ExitCode -ne 0 -and $renamedResult.Output -match 'appended assessment records only'
    ) $renamedResult.Output

    $foreign = New-LedgerRepository 'foreign' $ledgerBranch
    Set-Content (Join-Path $foreign 'README.md') 'tampered ledger readme' -Encoding utf8NoBOM
    Set-Content (Join-Path $foreign 'main.bicep') 'param tampered bool = true' -Encoding utf8NoBOM
    $foreignResult = Invoke-Guard $foreign
    Assert-Result 'Changes outside the assessment path are rejected' (
        $foreignResult.ExitCode -ne 0 -and
        $foreignResult.Output -match 'main\.bicep' -and
        $foreignResult.Output -match 'README\.md' -and
        $foreignResult.Output -match 'outside parity/assessments'
    ) $foreignResult.Output

    $nonJson = New-LedgerRepository 'non-json' $ledgerBranch
    Set-Content (Join-Path $nonJson 'parity\assessments\notes.md') 'notes' -Encoding utf8NoBOM
    $nonJsonResult = Invoke-Guard $nonJson
    Assert-Result 'A non-record file inside the assessment path is rejected' (
        $nonJsonResult.ExitCode -ne 0 -and $nonJsonResult.Output -match 'notes\.md'
    ) $nonJsonResult.Output

    $wrongBranch = New-LedgerRepository 'integration' $integrationBranch
    Set-Content (Join-Path $wrongBranch 'parity\assessments\assessment-300-ddddddd.json') '{ "id": "assessment-300-ddddddd" }' -Encoding utf8NoBOM
    $wrongBranchResult = Invoke-Guard $wrongBranch
    Assert-Result 'A checkout on the integration branch is rejected' (
        $wrongBranchResult.ExitCode -ne 0 -and
        $wrongBranchResult.Output -match "dedicated ledger branch '$ledgerBranch'" -and
        $wrongBranchResult.Output -match "is on '$integrationBranch'"
    ) $wrongBranchResult.Output

    $detached = New-LedgerRepository 'detached' $ledgerBranch
    Invoke-Git $detached @('checkout', '--detach', 'HEAD') | Out-Null
    $detachedResult = Invoke-Guard $detached
    Assert-Result 'A detached ledger checkout is rejected' (
        $detachedResult.ExitCode -ne 0 -and $detachedResult.Output -match 'dedicated ledger branch'
    ) $detachedResult.Output
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
