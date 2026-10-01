<#
.SYNOPSIS
    Checks release metadata independently of immutable comparison baselines.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\ReleaseMetadata.ps1')
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
$config = Get-Content (Join-Path $root 'parity\config.json') -Raw | ConvertFrom-Json -AsHashtable
$inventory = Get-Content (Join-Path $root 'parity\inventory.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
Assert-ReleaseMetadata -Manifest $manifest -Changelog $changelog

function Assert-ComparisonBaseline {
    param($Configuration, $Inventory)
    foreach ($baseline in @($Configuration.repositories, $Inventory.baseline)) {
        if (
            $baseline.source.releaseTag -cne 'v2.6.1' -or
            $baseline.terraform.releaseTag -cne 'v0.5.1' -or
            $baseline.source.commitSha -cne '64195c01b70974fa7256c2f54a0035fb06804139' -or
            $baseline.terraform.commitSha -cne 'abe337894f93de3ddda525ea44898b33e1484070'
        ) {
            throw 'BASELINE: comparison tags and immutable commits require a separate reviewed baseline change.'
        }
    }
}
Assert-ComparisonBaseline $config $inventory

$rejected = 0
foreach ($record in @('config', 'inventory')) {
    foreach ($repository in @('source', 'terraform')) {
        foreach ($field in @('releaseTag', 'commitSha')) {
            $changedConfig = $config | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
            $changedInventory = $inventory | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
            $baseline = if ($record -ceq 'config') { $changedConfig.repositories } else { $changedInventory.baseline }
            $baseline[$repository][$field] = 'unexpected-drift'
            $caught = $false
            try { Assert-ComparisonBaseline $changedConfig $changedInventory }
            catch {
                if (-not $_.Exception.Message.StartsWith('BASELINE:')) { throw }
                $caught = $true
            }
            if (-not $caught) { throw "Comparison guard accepted $record.$repository.$field drift." }
            $rejected++
        }
    }
}
Write-Host "Baseline contract passed: independent release metadata; immutable comparison pins; $rejected pin mutations rejected."
exit 0
