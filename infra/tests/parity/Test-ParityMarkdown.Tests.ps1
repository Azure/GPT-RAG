<#
.SYNOPSIS
    Tests deterministic Markdown ordering, escaping, timestamps, idempotency, and drift mode.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exporter = Join-Path $root 'scripts\parity\Export-ParityMarkdown.ps1'
$fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures\capability.json') -Raw | ConvertFrom-Json -Depth 100
$temp = Join-Path $PSScriptRoot ".tmp-markdown-$([guid]::NewGuid())"
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $fixture.capabilities[0].title = 'Pipe | slash \ and <tag>'
    $fixture.capabilities += $fixture.capabilities[0].PSObject.Copy()
    $fixture.capabilities[1].id = 'aaa-first'
    $fixture.capabilities[1].title = 'First'
    $fixture.baseline.assessedAt = '2026-01-02T03:04:05Z'
    $inventoryPath = Join-Path $temp 'inventory.json'
    $outputPath = Join-Path $temp 'parity.md'
    $fixture | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $inventoryPath -Encoding utf8NoBOM

    & pwsh -NoProfile -File $exporter -Root $root -InventoryPath $inventoryPath -OutputPath $outputPath
    Assert-True ($LASTEXITCODE -eq 0) 'Initial generation failed.'
    $first = [IO.File]::ReadAllText($outputPath)
    & pwsh -NoProfile -File $exporter -Root $root -InventoryPath $inventoryPath -OutputPath $outputPath
    $second = [IO.File]::ReadAllText($outputPath)
    Assert-True ($first -ceq $second) 'Repeated generation must be byte-identical.'
    Assert-True ($first.IndexOf('aaa-first') -lt $first.IndexOf('sample-capability')) 'Capabilities must be ordered by ID.'
    Assert-True ($first.Contains('Pipe \| slash \\ and &lt;tag&gt;')) 'Markdown table content must be escaped.'
    Assert-True ($first.Contains('2026-01-02T03:04:05Z')) 'The pinned assessedAt timestamp must be rendered.'
    Assert-True ($first.Contains('## Detailed source contract')) 'Detailed source contracts must be rendered.'
    Assert-True ($first.Contains('proposed ADR-0006') -and $first.Contains('A manifest version bump neither advances these pins')) 'The generated footer must distinguish proposed release metadata separation from historical comparison advancement.'
    Assert-True ($first.Contains('| `sample` | `input` | `built-in` | `string` | `false` | `literal` | `"sample-default"` | `["sample-default","alternate"]` |')) 'Input type/default/allowed values must be inspectable.'
    Assert-True ($first.Contains('| `expressionSample` | `input` | `built-in` | `string` | `false` | `expression` | `[resourceGroup().location]` | `[]` |')) 'Expression defaults and empty allowed values must be explicit.'
    Assert-True ($first.Contains('| `SAMPLE_OUTPUT` | `output` | `built-in` | `string` |')) 'Output type metadata must be inspectable.'
    Assert-True ($first.Contains('| `&lt;APP&gt;_NAME` | `runtime-key` | `pattern` | `^[A-Z][A-Z0-9_]*_NAME$` |')) 'Runtime pattern metadata must be inspectable and escaped.'

    & pwsh -NoProfile -File $exporter -Root $root -InventoryPath $inventoryPath -OutputPath $outputPath -Check
    Assert-True ($LASTEXITCODE -eq 0) '-Check must pass for current output.'
    [IO.File]::AppendAllText($outputPath, 'drift')
    & pwsh -NoProfile -File $exporter -Root $root -InventoryPath $inventoryPath -OutputPath $outputPath -Check 2>$null
    Assert-True ($LASTEXITCODE -ne 0) '-Check must fail on drift.'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'Markdown generation tests passed.'
exit 0
