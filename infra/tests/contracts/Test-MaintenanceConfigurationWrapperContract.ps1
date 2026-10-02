<#
.SYNOPSIS
    Validates the AVM Maintenance Configuration wrapper parameter forwarding.

.DESCRIPTION
    Regression test for Azure/bicep-ptn-aiml-landing-zone#122. It compiles a
    default and an InGuestPatch invocation, then proves the wrapper forwards
    every typed property to AVM 0.3.1 without flattening maintenanceWindow or
    installPatches. Omitted non-nullable properties retain AVM 0.3.1 defaults;
    nullable lock, roleAssignments, and tags remain nullable.
#>

[CmdletBinding()]
param(
    [string]$FixtureFile = (Join-Path $PSScriptRoot 'fixtures/maintenance-configuration/main.bicep')
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()
$compiledFile = Join-Path ([System.IO.Path]::GetTempPath()) "maintenance-wrapper-contract-$([guid]::NewGuid()).json"

function Add-Failure {
    param([Parameter(Mandatory)] [string]$Message)
    $failures.Add($Message) | Out-Null
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Add-Pass {
    param([Parameter(Mandatory)] [string]$Message)
    Write-Host "  [PASS] $Message" -ForegroundColor Green
}

function Assert-Equal {
    param(
        [Parameter(Mandatory)] [string]$Description,
        [AllowNull()] $Actual,
        [AllowNull()] $Expected
    )
    $actualJson = ConvertTo-Json -InputObject $Actual -Depth 30 -Compress
    $expectedJson = ConvertTo-Json -InputObject $Expected -Depth 30 -Compress
    if ($actualJson -cne $expectedJson) {
        Add-Failure "$Description Expected '$Expected', got '$Actual'."
    }
    else {
        Add-Pass $Description
    }
}

Write-Host 'Maintenance Configuration wrapper contract (issue #122)' -ForegroundColor Cyan

try {
    if (Get-Command az -ErrorAction SilentlyContinue) {
        $env:PYTHONIOENCODING = 'utf-8'
        & az bicep build --file $FixtureFile --outfile $compiledFile
    }
    elseif (Get-Command bicep -ErrorAction SilentlyContinue) {
        & bicep build $FixtureFile --outfile $compiledFile
    }
    else {
        throw 'Neither bicep nor az is available on PATH.'
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Bicep compilation failed with exit code $LASTEXITCODE."
    }

    $template = Get-Content -LiteralPath $compiledFile -Raw | ConvertFrom-Json -Depth 100
    $defaultDeployment = $template.resources |
        Where-Object { $_.name -eq 'maintenance-default-contract' } |
        Select-Object -First 1
    $inGuestDeployment = $template.resources |
        Where-Object { $_.name -eq 'maintenance-in-guest-patch-contract' } |
        Select-Object -First 1

    if ($null -eq $defaultDeployment -or $null -eq $inGuestDeployment) {
        Add-Failure 'Compiled fixture does not contain both default and InGuestPatch wrapper deployments.'
    }
    else {
        $defaultInput = $defaultDeployment.properties.parameters.maintenanceConfig.value
        Assert-Equal 'Default invocation supplies only the required name.' @($defaultInput.PSObject.Properties.Name) @('name')

        $inGuestInput = $inGuestDeployment.properties.parameters.maintenanceConfig.value
        Assert-Equal 'InGuestPatch scope remains in the typed maintenanceConfig object.' $inGuestInput.maintenanceScope 'InGuestPatch'
        Assert-Equal 'Schedule fields remain nested under maintenanceWindow.' $inGuestInput.maintenanceWindow ([ordered]@{
                duration      = '03:00'
                recurEvery    = '1Week Saturday'
                startDateTime = '2024-06-15 22:00'
                timeZone      = 'UTC'
            })
        Assert-Equal 'Patch settings remain nested under installPatches.' $inGuestInput.installPatches ([ordered]@{
                linuxParameters = [ordered]@{
                    classificationsToInclude = @('Critical', 'Security')
                    packageNameMasksToExclude = @('kernel*')
                    packageNameMasksToInclude = @('openssl*')
                }
                rebootSetting = 'IfRequired'
                windowsParameters = [ordered]@{
                    classificationsToInclude = @('Critical', 'Security')
                    excludeKbsRequiringReboot = $true
                    kbNumbersToExclude = @('KB0000001')
                    kbNumbersToInclude = @('KB0000002')
                }
            })
        Assert-Equal 'InGuestPatchMode remains nested under extensionProperties.' $inGuestInput.extensionProperties ([ordered]@{
                InGuestPatchMode = 'User'
            })

        $wrapperTemplate = $defaultDeployment.properties.template
        $innerParameters = $wrapperTemplate.resources.inner.properties.parameters
        $expectedParameterNames = @(
            'enableTelemetry', 'extensionProperties', 'installPatches', 'location',
            'lock', 'maintenanceScope', 'maintenanceWindow', 'name', 'namespace',
            'roleAssignments', 'tags', 'visibility'
        )
        $actualParameterNames = @($innerParameters.PSObject.Properties.Name | Sort-Object)
        Assert-Equal 'Nested AVM deployment forwards the complete wrapper contract.' $actualParameterNames $expectedParameterNames

        $expectedDefaults = [ordered]@{
            enableTelemetry     = "[coalesce(tryGet(parameters('maintenanceConfig'), 'enableTelemetry'), true())]"
            extensionProperties = "[coalesce(tryGet(parameters('maintenanceConfig'), 'extensionProperties'), createObject())]"
            installPatches      = "[coalesce(tryGet(parameters('maintenanceConfig'), 'installPatches'), createObject())]"
            location            = "[coalesce(tryGet(parameters('maintenanceConfig'), 'location'), resourceGroup().location)]"
            maintenanceScope    = "[coalesce(tryGet(parameters('maintenanceConfig'), 'maintenanceScope'), 'Host')]"
            maintenanceWindow   = "[coalesce(tryGet(parameters('maintenanceConfig'), 'maintenanceWindow'), createObject())]"
            namespace           = "[coalesce(tryGet(parameters('maintenanceConfig'), 'namespace'), '')]"
            visibility          = "[coalesce(tryGet(parameters('maintenanceConfig'), 'visibility'), '')]"
        }
        foreach ($parameterName in $expectedDefaults.Keys) {
            Assert-Equal "Omitted $parameterName preserves the AVM 0.3.1 default." $innerParameters.$parameterName.value $expectedDefaults[$parameterName]
        }

        foreach ($parameterName in @('lock', 'roleAssignments', 'tags')) {
            Assert-Equal "Nullable $parameterName is forwarded without a synthetic default." $innerParameters.$parameterName.value "[tryGet(parameters('maintenanceConfig'), '$parameterName')]"
        }

        $unexpectedFlattenedParameters = @(
            'duration', 'rebootSetting', 'recurEvery', 'startDateTime', 'timeZone'
        ) | Where-Object { $_ -in @($innerParameters.PSObject.Properties.Name) }
        Assert-Equal 'Schedule and reboot fields are not flattened into AVM parameters.' @($unexpectedFlattenedParameters) @()
    }
}
finally {
    Remove-Item -LiteralPath $compiledFile -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host "`n$($failures.Count) maintenance wrapper contract check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nMaintenance Configuration wrapper contract checks passed." -ForegroundColor Green
exit 0
