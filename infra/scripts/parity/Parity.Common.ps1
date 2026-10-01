Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Throw-ParityError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$ErrorId = 'ParityValidationFailed'
    )

    throw [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new($Message),
        $ErrorId,
        [System.Management.Automation.ErrorCategory]::InvalidData,
        $null
    )
}

function Resolve-ParityPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Path,
        [switch]$MustExist
    )

    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $rootPath $Path))
    }
    $rootPrefix = "$rootPath$([System.IO.Path]::DirectorySeparatorChar)"

    if (
        -not $candidate.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        Throw-ParityError "Path '$Path' resolves outside the configured root '$rootPath'." 'ParityPathTraversal'
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $candidate)) {
        Throw-ParityError "Required path does not exist: $candidate" 'ParityPathNotFound'
    }

    return $candidate
}

function Read-ParityJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
        $value = $content | ConvertFrom-Json -Depth 100
        return $value
    }
    catch {
        Throw-ParityError "Malformed JSON in '$Path': $($_.Exception.Message)" 'ParityMalformedJson'
    }
}

function ConvertTo-ParityStableObject {
    [CmdletBinding()]
    param([AllowNull()] $InputObject)

    if ($null -eq $InputObject -or $InputObject -is [string] -or $InputObject.GetType().IsValueType) {
        return $InputObject
    }
    if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [pscustomobject]) {
        $ordered = [ordered]@{}
        foreach ($property in ($InputObject.PSObject.Properties | Sort-Object -Property Name)) {
            $ordered[$property.Name] = ConvertTo-ParityStableObject $property.Value
        }
        return [pscustomobject]$ordered
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        $items = @($InputObject | ForEach-Object { ConvertTo-ParityStableObject $_ })
        Write-Output -NoEnumerate $items
        return
    }
    return $InputObject
}

function Sort-ParityRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Records,
        [string[]]$Property = @('id')
    )

    Write-Output -NoEnumerate @($Records | Sort-Object -Property $Property -Stable)
}

function ConvertTo-ParityStableJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $InputObject)

    $stable = ConvertTo-ParityStableObject $InputObject
    return (($stable | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Write-ParityFileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $temporaryPath = Join-Path $directory (".{0}.{1}.tmp" -f (Split-Path -Leaf $Path), [guid]::NewGuid())
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}
