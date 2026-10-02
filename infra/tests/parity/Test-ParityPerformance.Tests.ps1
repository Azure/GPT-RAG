<#
.SYNOPSIS
    Proves complete inventory validation and Markdown generation stay within budget.

.DESCRIPTION
    The plan requires validating the complete inventory and generating its Markdown
    view in under 60 seconds in CI. This suite measures both commands and asserts the
    combined wall-clock budget.
#>
[CmdletBinding()]
param(
    [int]$BudgetSeconds = 60
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$assetValidator = Join-Path $repo 'scripts\parity\Test-ParityAssets.ps1'
$generator = Join-Path $repo 'scripts\parity\Export-ParityMarkdown.ps1'
$failures = 0

function Assert-Result([string]$Name, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:failures++ }
}

function Measure-ParityCommand([string]$Path, [string[]]$Arguments) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = & pwsh -NoProfile -File $Path -Root $repo @Arguments 2>&1 | Out-String
    $stopwatch.Stop()
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Output = $output
    }
}

$validation = Measure-ParityCommand $assetValidator @()
Assert-Result 'Complete parity validation succeeds' ($validation.ExitCode -eq 0) $validation.Output

$generation = Measure-ParityCommand $generator @('-Check')
Assert-Result 'Deterministic Markdown generation succeeds' ($generation.ExitCode -eq 0) $generation.Output

$total = [math]::Round($validation.Seconds + $generation.Seconds, 2)
Write-Host "Validation: $($validation.Seconds)s; generation: $($generation.Seconds)s; total: ${total}s (budget ${BudgetSeconds}s)."
Assert-Result "Validation and generation finish within $BudgetSeconds seconds" (
    $total -lt $BudgetSeconds
) "total=${total}s"

if ($failures) { exit 1 }
exit 0
