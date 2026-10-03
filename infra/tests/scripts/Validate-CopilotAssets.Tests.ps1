<#
.SYNOPSIS
    Fixture tests for .github/scripts/Validate-CopilotAssets.ps1.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validator = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.github\scripts\Validate-CopilotAssets.ps1')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-assets-{0}" -f [guid]::NewGuid())
$failures = 0

function Set-FixtureFile {
    param([string]$RelativePath, [string]$Content)
    $path = Join-Path $tempRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    Set-Content -Path $path -Value $Content -Encoding utf8
}

function Invoke-Validator {
    $output = & pwsh -NoProfile -File $validator -Root $tempRoot 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Assert-Result {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] $Name - $Detail" -ForegroundColor Red
        $script:failures++
    }
}

try {
    Set-FixtureFile '.github/agents/implementation.agent.md' @'
---
name: implementation
description: Implements a fixture.
tools: ["read", "edit"]
---
# Implementation
'@
    Set-FixtureFile '.github/skills/example/SKILL.md' @'
---
name: example
description: Exercises a fixture.
---
# Example
[Reference](references/example.md)
'@
    Set-FixtureFile '.github/skills/example/references/example.md' '# Reference'
    Set-FixtureFile '.github/instructions/example.instructions.md' @'
---
applyTo: "**/*.bicep"
---
# Example
'@

    $valid = Invoke-Validator
    Assert-Result 'Valid assets pass' ($valid.ExitCode -eq 0) $valid.Output

    Set-FixtureFile '.github/agents/duplicate.agent.md' @'
---
name: implementation
description: Duplicates a fixture.
tools: ["read", "unknown"]
---
# Duplicate
'@
    $invalid = Invoke-Validator
    Assert-Result 'Duplicate names fail' ($invalid.ExitCode -ne 0 -and $invalid.Output -match 'duplicate agent') $invalid.Output
    Assert-Result 'Unsupported tools fail' ($invalid.ExitCode -ne 0 -and $invalid.Output -match 'unsupported tool aliases') $invalid.Output

    Remove-Item (Join-Path $tempRoot '.github/agents/duplicate.agent.md') -Force
    Set-FixtureFile '.github/agents/terraform-parity.agent.md' @'
---
name: terraform-parity
description: Reviews approved handoffs.
tools: ["read", "edit"]
---
approval.status=approved
Pending handoffs cannot be consumed.
inventoryCommitSha
inventoryReviewUrl
Azure/terraform-azurerm-avm-ptn-aiml-landing-zone
Do not edit, merge, deploy, or publish.
'@
    $writableParity = Invoke-Validator
    Assert-Result 'Terraform parity agent rejects write tools' (
        $writableParity.ExitCode -ne 0 -and $writableParity.Output -match 'must be read-only'
    ) $writableParity.Output

    Set-FixtureFile '.github/agents/terraform-parity.agent.md' @'
---
name: terraform-parity
description: Reviews approved handoffs.
tools: ["read", "search"]
---
approval.status=approved
Pending handoffs cannot be consumed.
inventoryCommitSha
inventoryReviewUrl
Azure/terraform-azurerm-avm-ptn-aiml-landing-zone
Do not edit, merge, deploy, or publish.
'@
    $validParity = Invoke-Validator
    Assert-Result 'Read-only Terraform parity agent requires approved provenance boundaries' (
        $validParity.ExitCode -eq 0
    ) $validParity.Output

    Set-FixtureFile '.github/agents/terraform-parity.agent.md' @'
---
name: terraform-parity
description: Reviews approved handoffs.
tools: ["read", "search"]
---
Missing required operational boundaries.
'@
    $missingBoundary = Invoke-Validator
    Assert-Result 'Terraform parity agent requires allow-list and approval boundaries' (
        $missingBoundary.ExitCode -ne 0 -and $missingBoundary.Output -match 'missing required boundary text'
    ) $missingBoundary.Output
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures -gt 0) {
    exit 1
}
exit 0
