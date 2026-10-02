<#
.SYNOPSIS
    Proves least-privilege, pinned, and injection-resistant parity workflows.

.DESCRIPTION
    Checks minimum permissions, immutable action pins, an explicit allow-list of
    checkout references, lockfile-only tooling installation, bounded dispatch
    payloads, and the absence of embedded secrets in every
    .github/workflows/terraform-parity-*.yml workflow. Workflow YAML is parsed with
    the in-repository reader in scripts/parity/Parity.WorkflowYaml.ps1, so the
    assertions read steps and inputs rather than only greping text.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $repo 'scripts\parity\Parity.WorkflowYaml.ps1')
$workflowRoot = Join-Path $repo '.github\workflows'
$expected = @('terraform-parity-validate.yml', 'terraform-parity-assess.yml', 'terraform-parity-publish.yml')
$writeJobs = @{ 'terraform-parity-assess.yml' = 'contents=write' }
# Every checkout reference a parity workflow may use. '<default>' is the checkout
# default for the triggering event, which is trusted repository content.
$checkoutRefAllowList = @{
    'terraform-parity-validate.yml' = @('<default>', 'terraform-parity-assessments')
    'terraform-parity-assess.yml' = @('${{ github.event.pull_request.merge_commit_sha }}', 'terraform-parity-assessments')
    'terraform-parity-publish.yml' = @('<default>', 'terraform-parity-assessments')
}
$failures = 0

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

foreach ($name in $expected) {
    $path = Join-Path $workflowRoot $name
    if (-not (Test-Path -LiteralPath $path)) {
        Assert-Result "Workflow '$name' exists" $false $path
        continue
    }

    $text = Get-Content $path -Raw
    $workflow = ConvertFrom-ParityWorkflowYaml -Yaml $text
    $jobs = @($workflow['jobs'].Values)
    $steps = @(Get-ParityWorkflowStep -Workflow $workflow)

    Assert-Result "$name defaults to read-only repository permissions" (
        $workflow.Contains('permissions') -and
        (@($workflow['permissions'].Keys) -join ',') -eq 'contents' -and
        "$($workflow['permissions']['contents'])" -eq 'read'
    ) ($workflow['permissions'] | ConvertTo-Json -Compress)

    $jobPermissions = @($jobs | ForEach-Object {
        if ($_.Contains('permissions')) {
            @($_['permissions'].GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
        }
        else { 'inherited' }
    })
    $expectedJobPermissions = if ($writeJobs.ContainsKey($name)) { $writeJobs[$name] } else { 'contents=read' }
    Assert-Result "$name grants only the permissions its jobs need" (
        @($jobPermissions | Where-Object { $_ -ne $expectedJobPermissions }).Count -eq 0
    ) ($jobPermissions -join ' | ')

    Assert-Result "$name bounds job runtime" (
        @($jobs | Where-Object { -not $_.Contains('timeout-minutes') }).Count -eq 0
    ) 'timeout-minutes'

    $uses = @([regex]::Matches($text, '(?m)^\s*-?\s*uses:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
    Assert-Result "$name pins every action to an immutable commit" (
        $uses.Count -gt 0 -and
        @($uses | Where-Object { $_ -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+@[0-9a-f]{40}$' }).Count -eq 0
    ) ($uses -join ' | ')

    Assert-Result "$name documents the released version beside each pin" (
        @([regex]::Matches($text, '(?m)uses:\s*\S+@[0-9a-f]{40}\s*#\s*v\S+')).Count -eq $uses.Count
    ) 'version comment'

    $checkoutSteps = @($steps | Where-Object { $_.Contains('uses') -and "$($_['uses'])" -like 'actions/checkout@*' })
    $checkoutRefs = @($checkoutSteps | ForEach-Object {
        if ($_.Contains('with') -and $null -ne $_['with'] -and $_['with'].Contains('ref')) { "$($_['with']['ref'])" }
        else { '<default>' }
    })
    Assert-Result "$name checks out only allow-listed trusted references" (
        $checkoutSteps.Count -eq @($uses | Where-Object { $_ -like 'actions/checkout@*' }).Count -and
        $checkoutRefs.Count -gt 0 -and
        @($checkoutRefs | Where-Object { $_ -notin $checkoutRefAllowList[$name] }).Count -eq 0
    ) ($checkoutRefs -join ' | ')

    Assert-Result "$name never checks out or executes pull-request head content" (
        @($checkoutRefs | Where-Object { $_ -match '(?i)head' }).Count -eq 0 -and
        $text -notmatch 'pull_request\.head' -and $text -notmatch 'github\.head_ref'
    ) ($checkoutRefs -join ' | ')

    $runBlocks = @($steps | Where-Object { $_.Contains('run') } | ForEach-Object { "$($_['run'])" })
    Assert-Result "$name keeps event and secret values out of inline shell expressions" (
        @($runBlocks | Where-Object { $_ -match '\$\{\{\s*(github\.event|secrets\.|inputs\.)' }).Count -eq 0
    ) ($runBlocks -join "`n")

    Assert-Result "$name installs tooling only from the pinned lockfile" (
        @($runBlocks | Where-Object {
            $_ -match '(?i)\b(Install-Module|Install-PSResource|Save-Module|Install-Package|pip\s+install)\b'
        }).Count -eq 0 -and
        @($runBlocks | Where-Object { $_ -match '(?i)\bnpm\s+(?!ci\b)(install|i)\b' }).Count -eq 0
    ) ($runBlocks -join "`n")

    Assert-Result "$name never prints token, key, or payload contents" (
        @($runBlocks | Where-Object {
            $_ -match '(?i)(echo|write-host|write-output|cat)\s+.*(token|secret|private[_-]?key)'
        }).Count -eq 0
    ) ($runBlocks -join "`n")


    Assert-Result "$name embeds no literal credential material" (
        $text -notmatch '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' -and
        $text -notmatch '(?i)\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b' -and
        $text -notmatch '(?i)\b(password|client[_-]?secret|access[_-]?token)\s*[:=]\s*[''"]?[A-Za-z0-9+/=_-]{12,}'
    ) 'credential material'

    $secretReferences = @([regex]::Matches($text, '\$\{\{\s*secrets\.([A-Za-z0-9_]+)\s*\}\}') | ForEach-Object { $_.Groups[1].Value })
    Assert-Result "$name uses only repository or environment secret references" (
        @($secretReferences | Where-Object { $_ -notmatch '^[A-Z][A-Z0-9_]*$' }).Count -eq 0
    ) ($secretReferences -join ',')
}

$publishPath = Join-Path $workflowRoot 'terraform-parity-publish.yml'
if (Test-Path -LiteralPath $publishPath) {
    $publishText = Get-Content $publishPath -Raw
    Assert-Result 'Cross-repository dispatch sends only the generated bounded payload' (
        $publishText -match 'Publish-TerraformHandoff\.ps1' -and
        $publishText -match '-PayloadPath' -and
        $publishText -match '-AssessmentsPath\s+''\.parity-ledger/parity/assessments''' -and
        $publishText -notmatch 'client_payload' -and
        $publishText -notmatch 'github\.event\.pull_request\.(title|body)'
    ) $publishText

    Assert-Result 'Cross-repository dispatch requires an ephemeral scoped App token' (
        $publishText -match 'create-github-app-token@[0-9a-f]{40}' -and
        $publishText -notmatch '(?i)personal access token' -and
        $publishText -match 'owner:\s*Azure'
    ) $publishText

    $publishWorkflow = ConvertFrom-ParityWorkflowYaml -Yaml $publishText
    $publishCheckouts = @(
        Get-ParityWorkflowStep -Workflow $publishWorkflow |
            Where-Object { $_.Contains('uses') -and "$($_['uses'])" -like 'actions/checkout@*' }
    )
    Assert-Result 'Publication reads approved assessments from the dedicated ledger checkout' (
        $publishCheckouts.Count -eq 2 -and
        @($publishCheckouts | Where-Object {
            $_.Contains('with') -and "$($_['with']['ref'])" -eq 'terraform-parity-assessments' -and
            "$($_['with']['path'])" -eq '.parity-ledger'
        }).Count -eq 1
    ) ($publishCheckouts | ConvertTo-Json -Depth 10 -Compress)
}

$validatePath = Join-Path $workflowRoot 'terraform-parity-validate.yml'
if (Test-Path -LiteralPath $validatePath) {
    $validateText = Get-Content $validatePath -Raw
    Assert-Result 'Ledger discovery distinguishes absence from operational failure' (
        $validateText -match 'Get-AssessmentLedgerAvailability\.ps1' -and
        $validateText -match 'Assessment ledger discovery failed' -and
        $validateText -notmatch 'gh api'
    ) $validateText

    Assert-Result 'Aggregate validation uses the live ledger when it is available' (
        $validateText -match 'Test-ParityAssets\.ps1' -and
        $validateText -match [regex]::Escape('-AssessmentsPath $assessments') -and
        $validateText -match "'\.parity-ledger/parity/assessments'" -and
        $validateText -match '\$env:PARITY_LEDGER_EXISTS\s+-eq\s+''true''' -and
        $validateText -match "ledger branch exists but '\`$ledgerPath' is missing"
    ) $validateText
}

$assessPath = Join-Path $workflowRoot 'terraform-parity-assess.yml'
if (Test-Path -LiteralPath $assessPath) {
    $assessWorkflow = ConvertFrom-ParityWorkflowYaml -Yaml (Get-Content $assessPath -Raw)
    $assessCheckouts = @(
        Get-ParityWorkflowStep -Workflow $assessWorkflow |
            Where-Object { $_.Contains('uses') -and "$($_['uses'])" -like 'actions/checkout@*' }
    )
    $credentialBearing = @($assessCheckouts | Where-Object {
        -not ($_.Contains('with') -and $null -ne $_['with'] -and $_['with'].Contains('persist-credentials') -and
            $_['with']['persist-credentials'] -eq $false)
    })
    Assert-Result 'The assessment workflow persists credentials only for the ledger checkout' (
        $assessCheckouts.Count -eq 2 -and
        $credentialBearing.Count -eq 1 -and
        "$($credentialBearing[0]['with']['ref'])" -eq 'terraform-parity-assessments'
    ) (@($assessCheckouts | ForEach-Object { "$($_['name'])" }) -join ' | ')

    $assessRunBlocks = @(
        Get-ParityWorkflowStep -Workflow $assessWorkflow |
            Where-Object { $_.Contains('run') } |
            ForEach-Object { "$($_['run'])" }
    )
    Assert-Result 'The assessment workflow enforces the append-only ledger guard from a tested script' (
        ($assessRunBlocks -join "`n") -match 'Test-LedgerAppendOnly\.ps1' -and
        ($assessRunBlocks -join "`n") -notmatch 'git status --porcelain[^\r\n]*\|\s*Where-Object'
    ) ($assessRunBlocks -join "`n")
}

if ($failures) { exit 1 }
exit 0
