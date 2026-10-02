<#
.SYNOPSIS
    Proves the merged-pull-request workflow event contract and ledger coverage rules.

.DESCRIPTION
    Validates integration-branch filtering, merged-only handling, trusted commit
    checkout against an explicit reference allow-list, dedicated ledger persistence,
    prohibited direct integration-branch writes, unattributed-commit coverage, and
    explicit failures for unassessed merges.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $repo 'scripts\parity\Parity.WorkflowYaml.ps1')
$workflowPath = Join-Path $repo '.github\workflows\terraform-parity-assess.yml'
$creator = Join-Path $repo 'scripts\parity\New-AlignmentAssessment.ps1'
$coverage = Join-Path $repo 'scripts\parity\Test-AssessmentCoverage.ps1'
$ledgerAvailability = Join-Path $repo 'scripts\parity\Get-AssessmentLedgerAvailability.ps1'
$config = Get-Content (Join-Path $repo 'parity\config.json') -Raw | ConvertFrom-Json -Depth 20
$temp = Join-Path $PSScriptRoot ('.tmp-event-{0}' -f [guid]::NewGuid())
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

try {
    New-Item -ItemType Directory $temp -Force | Out-Null

    if (-not (Test-Path -LiteralPath $workflowPath)) {
        Assert-Result 'Assessment workflow exists' $false $workflowPath
    }
    else {
        $text = Get-Content $workflowPath -Raw
        $workflow = ConvertFrom-ParityWorkflowYaml -Yaml $text
        $trigger = $workflow['on']
        $assessJob = @($workflow['jobs'].Values)[0]
        $steps = @($assessJob['steps'])
        $runBlocks = @($steps | Where-Object { $_.Contains('run') } | ForEach-Object { "$($_['run'])" })
        $checkoutSteps = @($steps | Where-Object { $_.Contains('uses') -and "$($_['uses'])" -like 'actions/checkout@*' })
        $checkoutRefs = @($checkoutSteps | ForEach-Object {
            if ($_.Contains('with') -and $null -ne $_['with'] -and $_['with'].Contains('ref')) { "$($_['with']['ref'])" }
            else { '<default>' }
        })
        $allowedRefs = @('${{ github.event.pull_request.merge_commit_sha }}', $config.branches.assessmentLedger)

        Assert-Result 'Workflow reacts only to closed pull requests on the integration branch' (
            @($trigger.Keys) -contains 'pull_request_target' -and
            @($trigger['pull_request_target']['types']) -contains 'closed' -and
            @($trigger['pull_request_target']['branches']) -ceq @($config.branches.sourceIntegration)
        ) (@($trigger.Keys) -join ',')

        Assert-Result 'Only merged pull requests are assessed' (
            "$($assessJob['if'])" -match 'github\.event\.pull_request\.merged\s*==\s*true'
        ) "$($assessJob['if'])"

        Assert-Result 'Every checkout reference is on the trusted allow-list' (
            $checkoutRefs.Count -eq 2 -and
            @($checkoutRefs | Where-Object { $_ -notin $allowedRefs }).Count -eq 0 -and
            @($checkoutRefs | Where-Object { $_ -match '(?i)head' }).Count -eq 0
        ) ($checkoutRefs -join ' | ')

        Assert-Result 'The workflow checks out the trusted merge commit, never the pull-request head' (
            @($checkoutRefs | Where-Object { $_ -match 'merge_commit_sha' }).Count -eq 1 -and
            $text -notmatch 'pull_request\.head'
        ) ($checkoutRefs -join ' | ')

        Assert-Result 'Assessments persist to the dedicated ledger branch checkout' (
            @($checkoutSteps | Where-Object {
                $_.Contains('with') -and "$($_['with']['ref'])" -eq $config.branches.assessmentLedger
            }).Count -eq 1
        ) $config.branches.assessmentLedger

        Assert-Result 'Ledger writes are serialized by a workflow concurrency group' (
            $workflow.Contains('concurrency') -and
            -not [string]::IsNullOrWhiteSpace("$($workflow['concurrency']['group'])") -and
            "$($workflow['concurrency']['cancel-in-progress'])" -eq 'False'
        ) "$($workflow['concurrency']['group'])"

        Assert-Result 'The workflow never pushes to the integration branch' (
            $text -notmatch "push[^\r\n]*\b$($config.branches.sourceIntegration)\b" -and
            ($runBlocks -join "`n") -match [regex]::Escape($config.branches.assessmentLedger)
        ) 'push target'

        Assert-Result 'The workflow creates and schema-validates the assessment record' (
            ($runBlocks -join "`n") -match 'New-AlignmentAssessment\.ps1' -and
            ($runBlocks -join "`n") -match 'pwsh\s+-NoProfile\s+-File\s+\./scripts/parity/New-AlignmentAssessment\.ps1' -and
            ($runBlocks -join "`n") -match 'Test-ParityJson\.ps1'
        ) ($runBlocks -join "`n")

        $guardIndex = [array]::FindIndex($steps, [Predicate[object]] {
            param($step) $step.Contains('run') -and "$($step['run'])" -match 'Test-LedgerAppendOnly\.ps1'
        })
        $commitIndex = [array]::FindIndex($steps, [Predicate[object]] {
            param($step) $step.Contains('run') -and "$($step['run'])" -match 'git push origin'
        })
        Assert-Result 'The append-only ledger guard runs from its tested script before any commit' (
            $guardIndex -ge 0 -and $commitIndex -gt $guardIndex
        ) "guard=$guardIndex commit=$commitIndex"

        Assert-Result 'Event metadata reaches scripts as environment data, not inline expressions' (
            ($runBlocks -join "`n") -notmatch '\$\{\{\s*github\.event'
        ) ($runBlocks -join "`n")

        Assert-Result 'No assessment step suppresses its failure' (
            @($steps | Where-Object { $_.Contains('continue-on-error') -and "$($_['continue-on-error'])" -eq 'True' }).Count -eq 0
        ) 'continue-on-error'
    }

    $ledgerRoot = Join-Path $temp '.parity-ledger'
    $isolationRoot = Join-Path $temp '.parity-ledger-isolation'
    New-Item -ItemType Directory (Join-Path $ledgerRoot 'parity\assessments') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $isolationRoot 'parity\assessments') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $temp 'parity\assessments') -Force | Out-Null
    Copy-Item (Join-Path $repo 'parity\config.json') (Join-Path $temp 'parity\config.json')
    Copy-Item (Join-Path $repo 'parity\inventory.json') (Join-Path $temp 'parity\inventory.json')

    $ledgerSha = '9' + ('b' * 39)
    $ledgerResult = & pwsh -NoProfile -File $creator -Root $temp `
        -LedgerPath '.parity-ledger-isolation/parity/assessments' `
        -PullRequestNumber 940 -MergeCommitSha $ledgerSha -BaseBranch develop `
        -MergedAt '2026-08-22T12:00:00Z' -Merged true 2>&1 | Out-String
    $ledgerExit = $LASTEXITCODE
    $ledgerFiles = @(Get-ChildItem -LiteralPath (Join-Path $isolationRoot 'parity\assessments') -Filter '*.json' -File)
    $integrationFiles = @(Get-ChildItem -LiteralPath (Join-Path $temp 'parity\assessments') -Filter '*.json' -File)
    Assert-Result 'Records persist only under the dedicated ledger path' (
        $ledgerExit -eq 0 -and $ledgerFiles.Count -eq 1 -and $integrationFiles.Count -eq 0
    ) $ledgerResult

    $gitRoot = Join-Path $temp 'ledger-repo'
    New-Item -ItemType Directory $gitRoot -Force | Out-Null
    Invoke-Git $gitRoot @('init', '--initial-branch', 'develop') | Out-Null
    Set-Content (Join-Path $gitRoot 'readme.md') 'baseline' -Encoding utf8NoBOM
    Invoke-Git $gitRoot @('add', '.') | Out-Null
    Invoke-Git $gitRoot @('commit', '-m', 'chore: adoption point') | Out-Null
    $adoptionSha = Invoke-Git $gitRoot @('rev-parse', 'HEAD')

    $availableOutput = Join-Path $temp 'available-output.txt'
    $available = & pwsh -NoProfile -File $ledgerAvailability -Repository $gitRoot `
        -Branch develop -OutputPath $availableOutput 2>&1 | Out-String
    Assert-Result 'Ledger discovery reports an existing branch with exit zero' (
        $LASTEXITCODE -eq 0 -and
        $available -match 'present: true' -and
        (Get-Content $availableOutput -Raw) -match 'exists=true'
    ) $available

    $absentOutput = Join-Path $temp 'absent-output.txt'
    $absent = & pwsh -NoProfile -File $ledgerAvailability -Repository $gitRoot `
        -Branch terraform-parity-assessments -OutputPath $absentOutput 2>&1 | Out-String
    Assert-Result 'Ledger discovery treats only a missing branch as an expected absence' (
        $LASTEXITCODE -eq 0 -and
        $absent -match 'present: false' -and
        (Get-Content $absentOutput -Raw) -match 'exists=false'
    ) $absent

    $invalidRepository = & pwsh -NoProfile -File $ledgerAvailability `
        -Repository (Join-Path $temp 'does-not-exist.git') -Branch develop 2>&1 | Out-String
    Assert-Result 'Ledger discovery fails on repository or transport errors' (
        $LASTEXITCODE -ne 0 -and $invalidRepository -match 'Unable to determine'
    ) $invalidRepository

    Invoke-Git $gitRoot @('checkout', '-b', 'feature') | Out-Null
    Set-Content (Join-Path $gitRoot 'feature.md') 'change' -Encoding utf8NoBOM
    Invoke-Git $gitRoot @('add', '.') | Out-Null
    Invoke-Git $gitRoot @('commit', '-m', 'feat: consumer visible change') | Out-Null
    Invoke-Git $gitRoot @('checkout', 'develop') | Out-Null
    Invoke-Git $gitRoot @('merge', '--no-ff', 'feature', '-m', 'Merge pull request #950 from Azure/feature') | Out-Null
    $mergeSha = Invoke-Git $gitRoot @('rev-parse', 'HEAD')

    $markerPath = Join-Path $ledgerRoot 'parity\assessments\adoption-marker.json'
    [ordered]@{
        schemaVersion = '1.0.0'
        ledgerBranch = $config.branches.assessmentLedger
        integrationBranch = $config.branches.sourceIntegration
        adoptionCommitSha = $adoptionSha
        adoptedAt = '2026-08-22T12:00:00Z'
        backfilledPullRequests = @()
        note = 'Fixture adoption marker for deterministic coverage validation.'
    } | ConvertTo-Json -Depth 10 | Set-Content $markerPath -Encoding utf8NoBOM

    $missing = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'An unassessed merge after the adoption marker fails explicitly' (
        $LASTEXITCODE -ne 0 -and $missing -match '#950'
    ) $missing

    $covering = & pwsh -NoProfile -File $creator -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -PullRequestNumber 950 -MergeCommitSha $mergeSha -BaseBranch develop `
        -MergedAt '2026-08-22T12:05:00Z' -Merged true 2>&1 | Out-String
    Assert-Result 'The merge can be assessed from trusted metadata' ($LASTEXITCODE -eq 0) $covering

    $covered = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'Every merge after the adoption marker has exactly one assessment' (
        $LASTEXITCODE -eq 0 -and $covered -match '1'
    ) $covered

    $strayPath = Join-Path $ledgerRoot 'parity\assessments\assessment-950-stray.json'
    $stray = Get-Content (Join-Path $ledgerRoot "parity\assessments\assessment-950-$($mergeSha.Substring(0, 7)).json") -Raw |
        ConvertFrom-Json -Depth 100
    $stray.id = 'assessment-950-0000000'
    $stray | ConvertTo-Json -Depth 100 | Set-Content $strayPath -Encoding utf8NoBOM
    $duplicated = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'Duplicate assessments for one merge fail explicitly' (
        $LASTEXITCODE -ne 0 -and $duplicated -match '#950'
    ) $duplicated
    Remove-Item $strayPath -Force

    Invoke-Git $gitRoot @('checkout', '-b', 'feature-colon') | Out-Null
    Set-Content (Join-Path $gitRoot 'feature-colon.md') 'custom merge subject' -Encoding utf8NoBOM
    Invoke-Git $gitRoot @('add', '.') | Out-Null
    Invoke-Git $gitRoot @('commit', '-m', 'chore: synchronization fixture') | Out-Null
    Invoke-Git $gitRoot @('checkout', 'develop') | Out-Null
    Invoke-Git $gitRoot @('merge', '--no-ff', 'feature-colon', '-m', 'Merge pull request #951: synchronize main into develop') | Out-Null
    $colonMergeSha = Invoke-Git $gitRoot @('rev-parse', 'HEAD')

    $colonMissing = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'A colon-delimited merge still requires its exact assessment' (
        $LASTEXITCODE -ne 0 -and $colonMissing -match 'Merged pull request #951.*has 0 assessments'
    ) $colonMissing

    $colonCreated = & pwsh -NoProfile -File $creator -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -PullRequestNumber 951 -MergeCommitSha $colonMergeSha -BaseBranch develop `
        -MergedAt '2026-08-22T12:10:00Z' -Merged true 2>&1 | Out-String
    Assert-Result 'Trusted metadata creates the colon-delimited merge assessment' (
        $LASTEXITCODE -eq 0
    ) $colonCreated

    $colonCovered = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'Standard and colon-delimited merge subjects both have coverage' (
        $LASTEXITCODE -eq 0 -and $colonCovered -match '2 merged pull requests'
    ) $colonCovered

    $validationWorkflow = ConvertFrom-ParityWorkflowYaml -Yaml (
        Get-Content (Join-Path $repo '.github\workflows\terraform-parity-validate.yml') -Raw
    )
    $validationSteps = @($validationWorkflow['jobs']['validate']['steps'])
    $refreshSteps = @($validationSteps | Where-Object {
        "$($_['name'])" -eq 'Refresh assessment ledger before coverage'
    })
    Assert-Result 'Coverage refreshes its ledger snapshot after the long-running tests' (
        $refreshSteps.Count -eq 1
    ) 'Expected exactly one ledger refresh step.'

    if ($refreshSteps.Count -eq 1) {
        $refreshIndex = [array]::FindIndex($validationSteps, [Predicate[object]] {
            param($step) "$($step['name'])" -eq 'Refresh assessment ledger before coverage'
        })
        $testsIndex = [array]::FindIndex($validationSteps, [Predicate[object]] {
            param($step) "$($step['name'])" -eq 'Test parity validators'
        })
        $coverageIndex = [array]::FindIndex($validationSteps, [Predicate[object]] {
            param($step) "$($step['name'])" -eq 'Validate assessment ledger coverage'
        })
        Assert-Result 'Ledger refresh runs after tests and before coverage only when the branch exists' (
            $refreshIndex -gt $testsIndex -and $coverageIndex -gt $refreshIndex -and
            "$($refreshSteps[0]['if'])" -eq "steps.ledger.outputs.exists == 'true'"
        ) "tests=$testsIndex refresh=$refreshIndex coverage=$coverageIndex"
        $coverageRun = "$($validationSteps[$coverageIndex]['run'])"
        Assert-Result 'Refreshed ledger records are validated before coverage uses them' (
            $coverageRun.IndexOf('Test-ParityAssets.ps1') -ge 0 -and
            $coverageRun.IndexOf('Test-ParityAssets.ps1') -lt $coverageRun.IndexOf('Test-AssessmentCoverage.ps1')
        ) $coverageRun

        Invoke-Git $ledgerRoot @('init', '--initial-branch', $config.branches.assessmentLedger) | Out-Null
        Invoke-Git $ledgerRoot @(
            'add', '--', 'parity/assessments/adoption-marker.json',
            "parity/assessments/assessment-950-$($mergeSha.Substring(0, 7)).json"
        ) | Out-Null
        Invoke-Git $ledgerRoot @('commit', '-m', 'chore: seed ledger') | Out-Null
        $refreshRoot = Join-Path $temp 'coverage-refresh'
        New-Item -ItemType Directory $refreshRoot -Force | Out-Null
        Invoke-Git $refreshRoot @(
            'clone', '--quiet', '--branch', $config.branches.assessmentLedger, $ledgerRoot, '.parity-ledger'
        ) | Out-Null
        Invoke-Git $ledgerRoot @(
            'add', '--', "parity/assessments/assessment-951-$($colonMergeSha.Substring(0, 7)).json"
        ) | Out-Null
        Invoke-Git $ledgerRoot @('commit', '-m', 'chore: append completed assessment') | Out-Null

        $staleCoverage = & pwsh -NoProfile -File $coverage -Root $temp `
            -LedgerPath 'coverage-refresh/.parity-ledger/parity/assessments' `
            -MarkerPath 'coverage-refresh/.parity-ledger/parity/assessments/adoption-marker.json' `
            -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
        Assert-Result 'An early checkout misses an assessment appended by the concurrent writer' (
            $LASTEXITCODE -ne 0 -and $staleCoverage -match '#951.*has 0 assessments'
        ) $staleCoverage

        Push-Location $refreshRoot
        try { & ([scriptblock]::Create("$($refreshSteps[0]['run'])")) }
        finally { Pop-Location }
        $freshCoverage = & pwsh -NoProfile -File $coverage -Root $temp `
            -LedgerPath 'coverage-refresh/.parity-ledger/parity/assessments' `
            -MarkerPath 'coverage-refresh/.parity-ledger/parity/assessments/adoption-marker.json' `
            -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
        Assert-Result 'The actual workflow refresh observes the appended assessment without rewriting records' (
            $LASTEXITCODE -eq 0 -and $freshCoverage -match '2 merged pull requests'
        ) $freshCoverage

        $cachedLedger = Join-Path $refreshRoot '.parity-ledger'
        Invoke-Git $cachedLedger @('remote', 'set-url', 'origin', (Join-Path $temp 'missing-ledger.git')) | Out-Null
        $refreshFailure = ''
        Push-Location $refreshRoot
        try { & ([scriptblock]::Create("$($refreshSteps[0]['run'])")) }
        catch { $refreshFailure = $_.Exception.Message }
        finally { Pop-Location }
        Assert-Result 'A ledger refresh transport failure stops validation explicitly' (
            $refreshFailure -match 'Assessment ledger fetch failed'
        ) $refreshFailure
    }

    Set-Content (Join-Path $gitRoot 'direct.md') 'pushed straight to the integration branch' -Encoding utf8NoBOM
    Invoke-Git $gitRoot @('add', '.') | Out-Null
    Invoke-Git $gitRoot @('commit', '-m', 'chore: direct push without a pull request') | Out-Null
    $directSha = Invoke-Git $gitRoot @('rev-parse', 'HEAD')

    $unattributed = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'A direct commit without a pull request reference fails explicitly' (
        $LASTEXITCODE -ne 0 -and
        $unattributed -match $directSha.Substring(0, 7) -and
        $unattributed -match 'direct pushes'
    ) $unattributed

    $optOut = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop -AllowUnattributedCommits 2>&1 | Out-String
    Assert-Result 'The named opt-out accepts unattributed commits and names them' (
        $LASTEXITCODE -eq 0 -and
        $optOut -match 'AllowUnattributedCommits' -and
        $optOut -match '1 unattributed commits'
    ) $optOut

    Invoke-Git $gitRoot @('commit', '--allow-empty', '-m', 'Merge pull request #951suffix: misleading number') | Out-Null
    $malformedSha = Invoke-Git $gitRoot @('rev-parse', 'HEAD')
    $malformed = & pwsh -NoProfile -File $coverage -Root $temp `
        -LedgerPath '.parity-ledger/parity/assessments' `
        -MarkerPath '.parity-ledger/parity/assessments/adoption-marker.json' `
        -GitRepositoryPath $gitRoot -Branch develop 2>&1 | Out-String
    Assert-Result 'A numeric prefix without a valid merge-subject delimiter is not a pull request reference' (
        $LASTEXITCODE -ne 0 -and
        $malformed -match "$($malformedSha.Substring(0, 7)).*has no pull request reference"
    ) $malformed
}
finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures) { exit 1 }
exit 0
