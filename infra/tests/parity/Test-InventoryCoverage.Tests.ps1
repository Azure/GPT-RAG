<#
.SYNOPSIS
    Proves that detailed inventory metadata matches the pinned compiled Bicep contract.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$inventory = Get-Content (Join-Path $root 'parity/inventory.json') -Raw | ConvertFrom-Json -Depth 100
$failures = [System.Collections.Generic.List[string]]::new()
$pinnedMain = & git -C $root show "$($inventory.baseline.source.commitSha):main.bicep" 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Unable to read pinned main.bicep: $pinnedMain" }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

function ConvertTo-ComparableJson($Value) {
    return ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

function Get-CompiledTypeContract($Definition) {
    if ($Definition.PSObject.Properties.Name -contains 'type') {
        return [ordered]@{ representation = 'built-in'; name = $Definition.type }
    }
    if ($Definition.PSObject.Properties.Name -contains '$ref') {
        return [ordered]@{ representation = 'definition'; ref = $Definition.'$ref' }
    }
    throw 'Compiled surface has neither a built-in type nor a definition reference.'
}

function Build-PinnedTemplate {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "parity-pinned-$([guid]::NewGuid())"
    try {
        $cloneOutput = & git clone --quiet --no-checkout $root $temp 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Unable to create temporary pinned checkout: $cloneOutput" }
        $checkoutOutput = & git -C $temp checkout --quiet --detach $inventory.baseline.source.commitSha 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Unable to check out pinned Bicep commit: $checkoutOutput" }

        $mainPath = Join-Path $temp 'main.bicep'
        $outputPath = Join-Path $temp 'compiled.json'
        if (Get-Command bicep -ErrorAction SilentlyContinue) {
            $buildOutput = & bicep build $mainPath --outfile $outputPath 2>&1 | Out-String
        }
        elseif (Get-Command az -ErrorAction SilentlyContinue) {
            $buildOutput = & az bicep build --file $mainPath --outfile $outputPath 2>&1 | Out-String
        }
        else {
            throw 'Bicep CLI or Azure CLI with Bicep is required to verify the pinned compiled contract.'
        }
        if ($LASTEXITCODE -ne 0) { throw "Unable to compile pinned main.bicep: $buildOutput" }
        return Get-Content $outputPath -Raw | ConvertFrom-Json -Depth 100
    }
    finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$template = Build-PinnedTemplate
Assert-True ($inventory.baseline.status -eq 'active') 'Inventory must contain one active baseline.'
$ids = @($inventory.capabilities.id)
Assert-True (($ids | Sort-Object -Unique).Count -eq $ids.Count) 'Capability IDs must be unique.'

foreach ($capability in $inventory.capabilities) {
    $scenarios = @($capability.scenarioAssessments.scenario)
    Assert-True (
        $scenarios.Count -eq 2 -and
        ($scenarios | Sort-Object -Unique).Count -eq 2 -and
        'standalone-standard' -in $scenarios -and
        'standalone-network-isolated' -in $scenarios
    ) "Capability '$($capability.id)' must assess exactly the two configured scenarios."
}

$classified = @($inventory.capabilities.consumerSurfaces)
$details = @(
    @($inventory.surfaceContracts.inputs | ForEach-Object { "input:$($_.name)" })
    @($inventory.surfaceContracts.outputs | ForEach-Object { "output:$($_.name)" })
    @($inventory.surfaceContracts.runtimeKeys | ForEach-Object { "runtime-key:$($_.name)" })
)
foreach ($surface in $details) {
    Assert-True (@($details | Where-Object { $_ -ceq $surface }).Count -eq 1) "Detailed surface '$surface' must occur exactly once."
    Assert-True (@($classified | Where-Object { $_ -ceq $surface }).Count -eq 1) "Surface '$surface' must be grouped exactly once."
}
foreach ($surface in $classified) {
    Assert-True (@($details | Where-Object { $_ -ceq $surface }).Count -eq 1) "Grouped surface '$surface' must have exactly one detailed contract."
}

$compiledInputs = @($template.parameters.PSObject.Properties)
Assert-True ($compiledInputs.Count -eq 188) "Pinned template must expose 188 inputs; found $($compiledInputs.Count)."
Assert-True (@($inventory.surfaceContracts.inputs).Count -eq 188) 'Inventory must contain 188 detailed inputs.'
foreach ($parameter in $compiledInputs) {
    $matches = @($inventory.surfaceContracts.inputs | Where-Object { $_.name -ceq $parameter.Name })
    Assert-True ($matches.Count -eq 1) "Input '$($parameter.Name)' must have exactly one detailed contract."
    if ($matches.Count -ne 1) { continue }

    $expected = $parameter.Value
    $actual = $matches[0]
    $hasDefault = $expected.PSObject.Properties.Name -contains 'defaultValue'
    Assert-True ($actual.kind -ceq 'input') "Input '$($parameter.Name)' kind must be input."
    Assert-True (
        (ConvertTo-ComparableJson $actual.type) -ceq (ConvertTo-ComparableJson (Get-CompiledTypeContract $expected))
    ) "Input '$($parameter.Name)' type differs from the compiled template."
    Assert-True ($actual.required -eq (-not $hasDefault)) "Input '$($parameter.Name)' required/default presence differs from the compiled template."

    if (-not $hasDefault) {
        Assert-True ($actual.default.representation -ceq 'none') "Required input '$($parameter.Name)' must use the none default representation."
    }
    elseif ($expected.defaultValue -is [string] -and $expected.defaultValue.StartsWith('[') -and $expected.defaultValue.EndsWith(']')) {
        Assert-True ($actual.default.representation -ceq 'expression') "Input '$($parameter.Name)' must identify its compiled default as an expression."
        Assert-True ($actual.default.expression -ceq $expected.defaultValue) "Input '$($parameter.Name)' compiled default expression differs."
    }
    else {
        Assert-True ($actual.default.representation -ceq 'literal') "Input '$($parameter.Name)' must use a JSON-native literal default."
        Assert-True (
            (ConvertTo-ComparableJson $actual.default.value) -ceq (ConvertTo-ComparableJson $expected.defaultValue)
        ) "Input '$($parameter.Name)' literal default differs from the compiled template."
    }

    $expectedAllowed = @(if ($expected.PSObject.Properties.Name -contains 'allowedValues') { @($expected.allowedValues) } else { @() })
    Assert-True (
        (ConvertTo-ComparableJson (@($actual.allowedValues))) -ceq (ConvertTo-ComparableJson $expectedAllowed)
    ) "Input '$($parameter.Name)' allowedValues differ from the compiled template."
}

$compiledOutputs = @($template.outputs.PSObject.Properties)
Assert-True ($compiledOutputs.Count -eq 61) "Pinned template must expose 61 outputs; found $($compiledOutputs.Count)."
Assert-True (@($inventory.surfaceContracts.outputs).Count -eq 61) 'Inventory must contain 61 detailed outputs.'
foreach ($output in $compiledOutputs) {
    $matches = @($inventory.surfaceContracts.outputs | Where-Object { $_.name -ceq $output.Name })
    Assert-True ($matches.Count -eq 1) "Output '$($output.Name)' must have exactly one detailed contract."
    if ($matches.Count -eq 1) {
        Assert-True ($matches[0].kind -ceq 'output') "Output '$($output.Name)' kind must be output."
        Assert-True (
            (ConvertTo-ComparableJson $matches[0].type) -ceq (ConvertTo-ComparableJson (Get-CompiledTypeContract $output.Value))
        ) "Output '$($output.Name)' type differs from the compiled template."
    }
}

# Runtime keys are observable contracts rather than ARM outputs. Literal keys
# come from the pinned orchestrator; list-shaped keys are explicit patterns.
$bicep = ($pinnedMain -split "`r?`n" | Where-Object { $_.TrimStart() -notlike '//*' }) -join "`n"
$literalRuntimeKeys = @(
    [regex]::Matches($bicep, "\{\s*name:\s*'([A-Z][A-Z0-9_]+)'\s*,\s*value:") |
        ForEach-Object { $_.Groups[1].Value }
    'APP_CONFIG_ENDPOINT'
) | Sort-Object -Unique
$patternContracts = @{
    '<APP>_APIKEY' = '^[A-Z][A-Z0-9_]*_APIKEY$'
    '<APP>_ENDPOINT' = '^[A-Z][A-Z0-9_]*_ENDPOINT$'
    '<APP>_NAME' = '^[A-Z][A-Z0-9_]*_NAME$'
    '<DATABASE_CONTAINER>_NAME' = '^[A-Z][A-Z0-9_]*_NAME$'
    '<STORAGE_CONTAINER>_NAME' = '^[A-Z][A-Z0-9_]*_NAME$'
}
$patternRuntimeKeys = @($patternContracts.Keys)
$expectedRuntimeKeys = @($literalRuntimeKeys) + @($patternRuntimeKeys)
Assert-True (@($inventory.surfaceContracts.runtimeKeys).Count -eq $expectedRuntimeKeys.Count) "Inventory must contain $($expectedRuntimeKeys.Count) detailed runtime keys."
foreach ($name in $expectedRuntimeKeys) {
    $matches = @($inventory.surfaceContracts.runtimeKeys | Where-Object { $_.name -ceq $name })
    Assert-True ($matches.Count -eq 1) "Runtime key '$name' must have exactly one detailed contract."
    if ($matches.Count -eq 1) {
        $classification = if ($name -in $patternRuntimeKeys) { 'pattern' } else { 'literal' }
        Assert-True ($matches[0].kind -ceq 'runtime-key') "Runtime key '$name' kind must be runtime-key."
        Assert-True ($matches[0].classification -ceq $classification) "Runtime key '$name' classification must be $classification."
        if ($classification -eq 'pattern') {
            Assert-True ($matches[0].pattern -ceq $patternContracts[$name]) "Runtime key '$name' machine-readable pattern differs."
        }
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "Inventory coverage passed: $($ids.Count) capabilities, 188 inputs, 61 outputs, $($expectedRuntimeKeys.Count) runtime keys."
exit 0
