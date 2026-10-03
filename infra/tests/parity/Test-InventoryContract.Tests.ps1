<#
.SYNOPSIS
    Exercises scenario, compatibility, proposal, and parity-evidence inventory rules.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$inventory = Get-Content (Join-Path $root 'parity\inventory.json') -Raw | ConvertFrom-Json -Depth 100
$failures = [System.Collections.Generic.List[string]]::new()
$knownProposalIds = @(
    Get-ChildItem (Join-Path $root 'parity\handoffs') -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { (Get-Content $_.FullName -Raw | ConvertFrom-Json).id }
)
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

$designSchema = [IO.File]::ReadAllBytes((Join-Path $root 'specs/001-terraform-foundry-parity/contracts/inventory.schema.json'))
$runtimeSchema = [IO.File]::ReadAllBytes((Join-Path $root 'parity/schemas/inventory.schema.json'))
Assert-True ([Linq.Enumerable]::SequenceEqual[byte]($designSchema, $runtimeSchema)) 'Design and runtime inventory schemas must byte-match.'

foreach ($capability in $inventory.capabilities) {
    foreach ($assessment in $capability.scenarioAssessments) {
        Assert-True (
            $assessment.supportStatus -ne 'blocked' -or
            -not [string]::IsNullOrWhiteSpace($assessment.blockedReason)
        ) "Blocked assessment '$($capability.id)/$($assessment.scenario)' requires a reason."
        foreach ($field in 'expectation', 'affectedInputs', 'affectedOutputs', 'defaultDifferences', 'migrationRequired') {
            Assert-True ($assessment.compatibility.PSObject.Properties.Name -contains $field) "Compatibility field '$field' is required."
        }
        Assert-True ($assessment.proposalIds -is [array]) 'proposalIds must be an array.'
        foreach ($proposalId in $assessment.proposalIds) {
            Assert-True ($proposalId -in $knownProposalIds) "Unknown proposal reference '$proposalId'."
        }
        Assert-True (-not $assessment.parityDeclared) 'Static inventory must not declare parity.'
        Assert-True (
            -not $assessment.parityDeclared -or
            ($assessment.evidenceLevel -eq 'reviewed' -and $assessment.evidenceIds.Count -ge 2)
        ) 'Parity declarations require reviewed evidence gates.'
    }
}

$inputs = @($inventory.surfaceContracts.inputs)
$outputs = @($inventory.surfaceContracts.outputs)
$runtimeKeys = @($inventory.surfaceContracts.runtimeKeys)
Assert-True ((@($inputs.name) -join "`n") -ceq (@($inputs.name | Sort-Object) -join "`n")) 'Detailed inputs must be sorted by name.'
Assert-True ((@($outputs.name) -join "`n") -ceq (@($outputs.name | Sort-Object) -join "`n")) 'Detailed outputs must be sorted by name.'
Assert-True ((@($runtimeKeys.name) -join "`n") -ceq (@($runtimeKeys.name | Sort-Object) -join "`n")) 'Detailed runtime keys must be sorted by name.'
foreach ($input in $inputs) {
    foreach ($field in 'name', 'kind', 'type', 'required', 'default', 'allowedValues') {
        Assert-True ($input.PSObject.Properties.Name -contains $field) "Detailed input '$($input.name)' is missing $field."
    }
    Assert-True ($input.allowedValues -is [array]) "Detailed input '$($input.name)' allowedValues must be an explicit array."
    Assert-True (
        ($input.required -and $input.default.representation -eq 'none') -or
        (-not $input.required -and $input.default.representation -in @('literal', 'expression'))
    ) "Detailed input '$($input.name)' has inconsistent required/default metadata."
}
foreach ($output in $outputs) {
    foreach ($field in 'name', 'kind', 'type') {
        Assert-True ($output.PSObject.Properties.Name -contains $field) "Detailed output '$($output.name)' is missing $field."
    }
}
foreach ($runtimeKey in $runtimeKeys) {
    Assert-True ($runtimeKey.classification -in @('literal', 'pattern')) "Runtime key '$($runtimeKey.name)' requires literal/pattern classification."
    Assert-True (
        $runtimeKey.classification -ne 'pattern' -or
        -not [string]::IsNullOrWhiteSpace($runtimeKey.pattern)
    ) "Pattern runtime key '$($runtimeKey.name)' requires a machine-readable pattern."
}

$differences = @($inventory.capabilities.scenarioAssessments.compatibility.defaultDifferences)
foreach ($required in @(
    'Bicep aiFoundryDisableLocalAuth defaults true; Terraform local_auth_enabled defaults true.',
    'Bicep deployAAfAgentSvc defaults true; Terraform create_ai_agent_service defaults false.',
    'Terraform standalone GenAI storage defaults GRS with shared access keys enabled; Foundry BYOR storage defaults ZRS with shared access keys disabled.'
)) {
    Assert-True ($required -in $differences) "Required default difference is missing: $required"
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'Inventory contract tests passed.'
exit 0
