<#
.SYNOPSIS
    Validates one parity JSON record against a pinned local runtime schema.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Path,
    [ValidateSet('inventory', 'assessment', 'terraformHandoff', 'parityEvidence', 'adoptionMarker')]
    [string]$Schema,
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ConfigPath = 'parity/config.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $documentPath = Resolve-ParityPath -Root $rootPath -Path $Path -MustExist
    $configurationPath = Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist
    $configuration = Read-ParityJson $configurationPath

    if (-not $Schema) {
        $document = Read-ParityJson $documentPath
        $Schema = if ($document.PSObject.Properties.Name -contains 'baseline') {
            'inventory'
        }
        elseif ($document.PSObject.Properties.Name -contains 'adoptionCommitSha') {
            'adoptionMarker'
        }
        elseif ($document.PSObject.Properties.Name -contains 'sourcePr') {
            'assessment'
        }
        elseif ($document.PSObject.Properties.Name -contains 'provenance') {
            'terraformHandoff'
        }
        elseif (
            $document.PSObject.Properties.Name -contains 'targetCommitSha' -and
            $document.PSObject.Properties.Name -contains 'workflowUrl'
        ) {
            'parityEvidence'
        }
        else {
            Throw-ParityError "Unable to discover a parity schema for '$documentPath'." 'ParitySchemaUnknown'
        }
    }

    $schemaRelativePath = $configuration.schemas.$Schema
    $schemaPath = Resolve-ParityPath -Root $rootPath -Path $schemaRelativePath -MustExist
    $validator = Resolve-ParityPath -Root $rootPath -Path 'scripts/parity/Validate-ParityJson.mjs' -MustExist
    $nodeModules = Resolve-ParityPath -Root $rootPath -Path 'node_modules/ajv/package.json'
    if (-not (Test-Path -LiteralPath $nodeModules -PathType Leaf)) {
        Throw-ParityError "Pinned validator dependencies are not installed. Run 'npm ci'." 'ParityDependencyMissing'
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Throw-ParityError "Node.js is required to run the pinned JSON Schema validator." 'ParityDependencyMissing'
    }

    & node $validator $schemaPath $documentPath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
catch {
    Write-Error $_
    exit 1
}
