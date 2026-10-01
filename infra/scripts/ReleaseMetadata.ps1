<#
.SYNOPSIS
    Shared release-metadata assertions; comparison baselines are separate.
#>

function Assert-ReleaseMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Changelog
    )

    $versionPattern = '\Av(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\z'
    foreach ($field in @('tag', 'ailz_tag')) {
        if (-not $Manifest.Contains($field) -or $Manifest[$field] -isnot [string] -or
            $Manifest[$field] -cnotmatch $versionPattern) {
            throw "RELEASE: manifest.$field must be exactly vMAJOR.MINOR.PATCH without leading zeros or suffixes."
        }
    }
    if ($Manifest.tag -cne $Manifest.ailz_tag) {
        throw 'RELEASE: manifest.tag and manifest.ailz_tag must match.'
    }

    $sections = @(
        [regex]::Matches($Changelog, '(?m)^## \[([^\]\r\n]+)\](?:[^\r\n]*)\r?$') |
            ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -cne 'Unreleased' }
    )
    if ($sections.Count -eq 0 -or $sections[0] -cne $Manifest.tag -or
        @($sections | Where-Object { $_ -ceq $Manifest.tag }).Count -ne 1) {
        throw 'RELEASE: the latest versioned changelog section must match the manifest exactly and occur once.'
    }
}
