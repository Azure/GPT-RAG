<#
.SYNOPSIS
    Creates a reviewable Terraform proposal handoff without Terraform source.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory)] [ValidatePattern('^handoff-[a-z0-9-]+$')] [string]$Id,
    [Parameter(Mandatory)] [ValidateSet('baseline-inventory', 'alignment-assessment')] [string]$ProvenanceType,
    [Parameter(Mandatory)] [string[]]$CapabilityIds,
    [Parameter(Mandatory)] [string]$OutputPath,
    [string]$InventoryPath = 'parity/inventory.json',
    [string]$InventoryCommitSha,
    [uri]$InventoryReviewUrl,
    [uri]$ApprovalUrl,
    [string]$AssessmentPath,
    [string[]]$AdditionalRequirement = @()
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

function Test-HandoffSensitiveText {
    param([Parameter(Mandatory)] [string[]]$Text)

    $joined = $Text -join "`n"
    $patterns = [ordered]@{
        'Terraform source' = '(?im)(?:```(?:hcl|terraform)|\b(?:resource|data)\s+"[^"]+"\s+"[^"]+"\s*\{|\b(?:module|variable|output)\s+"[^"]+"\s*\{|\bterraform\s*\{)'
        'credential-like content' = '(?i)\b(?:password|client[_-]?secret|access[_-]?token)\s*[:=]\s*\S+'
        'tenant or subscription ID' = '(?i)(?:/subscriptions/[0-9a-f-]{36}(?:/|$)|\b(?:tenant|subscription)(?:\s+id|Id)?\s*[:=]\s*[0-9a-f]{8}-[0-9a-f-]{27,}\b)'
        'private IP address' = '(?<![0-9])(?:10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}|192\.168\.(?:[0-9]{1,3}\.)[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.(?:[0-9]{1,3}\.)[0-9]{1,3})(?![0-9])'
        'environment-specific resource name' = '(?i)\b(?:environment|resource)\s+name\s*[:=]\s*[a-z0-9][a-z0-9._-]{2,}\b'
    }
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($joined -match $entry.Value) {
            Throw-ParityError "$($entry.Key) is prohibited in a Terraform handoff." 'ParitySensitiveContent'
        }
    }
}

function ConvertTo-InventoryRepositoryBytes {
    param([Parameter(Mandatory)] [byte[]]$Bytes)

    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    return ,[System.Text.UTF8Encoding]::new($false).GetBytes($text.Replace("`r`n", "`n"))
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $config = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path 'parity/config.json' -MustExist)
    $resolvedInventoryPath = Resolve-ParityPath -Root $rootPath -Path $InventoryPath -MustExist
    $inventoryBytes = ConvertTo-InventoryRepositoryBytes (
        [System.IO.File]::ReadAllBytes($resolvedInventoryPath)
    )
    $inventoryDigest = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($inventoryBytes)
    ).ToLowerInvariant()
    $inventory = Read-ParityJson $resolvedInventoryPath
    if (
        $inventory.baseline.status -ne 'active' -or
        $inventory.baseline.source.commitSha -ne $config.repositories.source.commitSha -or
        $inventory.baseline.terraform.commitSha -ne $config.repositories.terraform.commitSha
    ) {
        Throw-ParityError 'The inventory baseline is stale or inactive.' 'ParityStaleBaseline'
    }

    $expandedCapabilityIds = @($CapabilityIds | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    $requestedIds = @($expandedCapabilityIds | Sort-Object -Unique)
    if ($requestedIds.Count -ne $expandedCapabilityIds.Count) {
        Throw-ParityError 'Capability IDs must not be duplicated.' 'ParityDuplicateCapability'
    }
    $capabilities = @($inventory.capabilities | Where-Object { $_.id -in $requestedIds })
    $knownCapabilityIds = @($capabilities | ForEach-Object { $_.id })
    $unknown = @($requestedIds | Where-Object { $_ -notin $knownCapabilityIds })
    if ($unknown.Count -gt 0) {
        Throw-ParityError "Unknown capability: $($unknown -join ', ')." 'ParityUnknownCapability'
    }

    if ($ProvenanceType -eq 'baseline-inventory') {
        if ($InventoryCommitSha -or $InventoryReviewUrl -or $ApprovalUrl) {
            Throw-ParityError 'Pending baseline provenance must not claim an inventory commit, inventory review, or handoff approval.' 'ParityInvalidProvenance'
        }
        $provenance = [ordered]@{
            type = 'baseline-inventory'
            baselineId = $inventory.baseline.id
            inventoryDigest = [ordered]@{
                algorithm = 'sha256'
                value = $inventoryDigest
            }
        }
    }
    else {
        if (
            [string]::IsNullOrWhiteSpace($AssessmentPath) -or
            $InventoryCommitSha -or
            $InventoryReviewUrl -or
            $ApprovalUrl
        ) {
            Throw-ParityError 'Alignment provenance requires only an assessment path.' 'ParityInvalidProvenance'
        }
        $assessment = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $AssessmentPath -MustExist)
        if (
            $assessment.review.status -ne 'approved' -or
            $assessment.outcome -ne 'proposal-required' -or
            $assessment.review.approvalUrl -match '/issues/136(?:$|[?#])' -or
            @($requestedIds | Where-Object { $_ -notin $assessment.changedCapabilities }).Count -gt 0
        ) {
            Throw-ParityError 'Alignment provenance must be an approved proposal-required assessment covering every capability.' 'ParityInvalidProvenance'
        }
        $provenance = [ordered]@{ type = 'alignment-assessment'; assessmentId = $assessment.id }
    }

    if ($AdditionalRequirement.Count -gt 0) {
        Test-HandoffSensitiveText -Text $AdditionalRequirement
    }
    $handoffRoot = Resolve-ParityPath -Root $rootPath -Path $config.records.handoffs
    if (Test-Path -LiteralPath $handoffRoot) {
        foreach ($file in @(Get-ChildItem -LiteralPath $handoffRoot -Filter '*.json' -File -Recurse)) {
            $existing = Read-ParityJson $file.FullName
            if ($existing.approval.status -notin @('pending', 'approved')) { continue }
            $sameProvenance = if ($ProvenanceType -eq 'baseline-inventory') {
                $existing.provenance.type -eq $ProvenanceType -and
                $existing.provenance.baselineId -eq $inventory.baseline.id -and
                $existing.provenance.inventoryDigest.value -eq $inventoryDigest
            }
            else {
                $existing.provenance.type -eq $ProvenanceType -and
                $existing.provenance.assessmentId -eq $assessment.id
            }
            if (
                $sameProvenance -and
                (@($existing.capabilityIds | Sort-Object) -join "`n") -ceq ($requestedIds -join "`n")
            ) {
                Throw-ParityError "Duplicate active handoff '$($existing.id)'." 'ParityDuplicateActiveHandoff'
            }
        }
    }

    $owners = @($capabilities.owner | Sort-Object -Unique)
    $compatibilityRecords = @($capabilities | ForEach-Object { $_.scenarioAssessments } | ForEach-Object { $_.compatibility })
    $migrationRequired = @($compatibilityRecords | ForEach-Object { $_.migrationRequired }) -contains $true
    $defaultDifferences = @(
        $compatibilityRecords |
            ForEach-Object { @($_.defaultDifferences) } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    $defaultBehavior = if ($defaultDifferences.Count) {
        @('Preserve existing Terraform defaults unless a documented migration and semantic-version decision explicitly changes them.') + $defaultDifferences
    } else {
        'Preserve existing Terraform defaults and match the Bicep reference for newly introduced inputs.'
    }
    $migrationPlan = if ($migrationRequired) {
        'Document affected consumers, retain deprecated aliases for a transition, and publish upgrade guidance before changing behavior.'
    } else {
        'No consumer migration is intended; reject implementation choices that require one and return for review.'
    }
    $requiredBehavior = @($capabilities | Sort-Object id | ForEach-Object { "$($_.title): $($_.description)" })
    $identityRbac = @(
        $capabilities |
            ForEach-Object { @($_.identityRbacAssertions) } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    $networking = @(
        $capabilities |
            ForEach-Object { @($_.networkAssertions) } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    $standardAcceptance = @(
        $capabilities |
            ForEach-Object {
                $capabilityRecord = $_
                $_.scenarioAssessments |
                    Where-Object scenario -eq 'standalone-standard' |
                    ForEach-Object {
                        $blocked = if ($_.PSObject.Properties.Name -contains 'blockedReason') { $_.blockedReason } else { '' }
                        "$($capabilityRecord.id): $($_.supportStatus) - $($_.consumerImpact) $blocked".Trim()
                    }
            }
    )
    $isolatedAcceptance = @(
        $capabilities |
            ForEach-Object {
                $capabilityRecord = $_
                $_.scenarioAssessments |
                    Where-Object scenario -eq 'standalone-network-isolated' |
                    ForEach-Object {
                        $blocked = if ($_.PSObject.Properties.Name -contains 'blockedReason') { $_.blockedReason } else { '' }
                        "$($capabilityRecord.id): $($_.supportStatus) - $($_.consumerImpact) $blocked".Trim()
                    }
            }
    )
    $handoff = [ordered]@{
        schemaVersion = '1.0.0'
        id = $Id
        provenance = $provenance
        capabilityIds = $requestedIds
        source = [ordered]@{
            repository = $config.repositories.source.name
            ref = $config.repositories.source.releaseTag
            commitSha = $config.repositories.source.commitSha
        }
        target = [ordered]@{
            repository = $config.repositories.terraform.name
            ref = $config.branches.terraformBase
            commitSha = $config.repositories.terraform.commitSha
        }
        requiredBehavior = $requiredBehavior + $AdditionalRequirement
        compatibilityConstraints = @('Preserve existing Terraform inputs and outputs; use a reviewed deprecation transition before any removal.')
        defaultBehavior = @($defaultBehavior)
        migrationPlan = @($migrationPlan)
        scenarioAcceptance = [ordered]@{
            'standalone-standard' = $standardAcceptance
            'standalone-network-isolated' = $isolatedAcceptance
        }
        identityRequirements = @('Prefer managed identity; preserve inventory identity behavior and do not introduce credentials.') + $identityRbac
        rbacRequirements = @('Apply least-privilege RBAC and preserve explicit control-plane and data-plane role boundaries.') + $identityRbac
        networkingRequirements = @('Preserve scenario-specific public access, private endpoint, DNS, route, subnet, delegation, and dependency-ordering behavior recorded by the inventory.') + $networking
        securityInvariants = @('Do not store secrets, private environment values, or claim effective isolation from static inspection.')
        avmRequirements = @('Run the target repository formatting, lint, documentation, examples, test, and AVM pattern-module compliance checks.')
        acceptanceCriteria = @('The target proposal is human-reviewable, links this handoff and both baselines, and contains no unrelated contract change.')
        evidenceRequirements = [ordered]@{
            'standalone-standard' = @('Static checks and plan are non-parity evidence; require a successful approved test deployment and reviewed capability comparison for this scenario.')
            'standalone-network-isolated' = @('Require a separate successful approved test deployment plus reviewed DNS, endpoint, reachability, RBAC, and isolation comparison for this scenario.')
        }
        owner = [ordered]@{
            source = $owners -join '; '
            target = 'Terraform AI Landing Zone maintainers'
        }
        excludedScenarios = @('hub-spoke')
        exclusions = @('Do not implement hub-spoke or arbitrary optional-feature combinations in this proposal unless separately reviewed.')
        semanticVersionExpectation = if ($migrationRequired) { 'major' } else { 'minor' }
        migrationRequired = $migrationRequired
        approval = [ordered]@{ status = 'pending' }
    }

    Test-HandoffSensitiveText -Text @($handoff | ConvertTo-Json -Depth 100)
    $resolvedOutput = Resolve-ParityPath -Root $rootPath -Path $OutputPath
    $serializableHandoff = $handoff | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    Write-ParityFileAtomic -Path $resolvedOutput -Content (ConvertTo-ParityStableJson $serializableHandoff)
    Write-Host "Created pending Terraform handoff '$Id' at $OutputPath."
}
catch {
    Write-Error "$($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    exit 1
}
