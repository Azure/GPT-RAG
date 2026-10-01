<#
.SYNOPSIS
    Validates parity configuration, records, references, evidence, and sensitive content.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ConfigPath = 'parity/config.json',
    [string]$InventoryPath,
    [string]$AssessmentsPath,
    [string]$HandoffsPath,
    [string]$EvidencePath,
    [string]$GitRepositoryPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
function Add-Failure {
    param([Parameter(Mandatory)] [string]$Message)
    $script:failures.Add($Message)
}

function Get-RecordFiles {
    param([Parameter(Mandatory)] [string]$ConfiguredPath)

    $resolved = Resolve-ParityPath -Root $rootPath -Path $ConfiguredPath
    if (-not (Test-Path -LiteralPath $resolved)) {
        return @()
    }
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        return @($resolved)
    }
    return @(
        Get-ChildItem -LiteralPath $resolved -Filter '*.json' -File -Recurse |
            Sort-Object -Property FullName |
            Select-Object -ExpandProperty FullName
    )
}

function Test-RecordSchema {
    param([string]$RecordPath, [string]$SchemaName)

    $schemaPath = Resolve-ParityPath -Root $rootPath -Path $configuration.schemas.$SchemaName -MustExist
    $validator = Resolve-ParityPath -Root $rootPath -Path 'scripts/parity/Validate-ParityJson.mjs' -MustExist
    $output = & node $validator $schemaPath $RecordPath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Add-Failure ($output.Trim())
        return $false
    }
    return $true
}

function Test-UniqueValues {
    param([object[]]$Records, [string]$Property, [string]$Label)

    $duplicates = @(
        $Records |
            Where-Object { $null -ne $_ -and $_.PSObject.Properties.Name -contains $Property } |
            ForEach-Object { $_.$Property } |
            Group-Object |
            Where-Object Count -gt 1 |
            Sort-Object Name
    )
    foreach ($duplicate in $duplicates) {
        Add-Failure "Duplicate $Label '$($duplicate.Name)'."
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory)] [byte[]]$Bytes)

    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function ConvertTo-InventoryRepositoryBytes {
    param([Parameter(Mandatory)] [byte[]]$Bytes)

    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    return ,[System.Text.UTF8Encoding]::new($false).GetBytes($text.Replace("`r`n", "`n"))
}

function Get-GitInventoryBytes {
    param(
        [Parameter(Mandatory)] [string]$RepositoryPath,
        [Parameter(Mandatory)] [string]$CommitSha
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'git'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add('-C')
    $startInfo.ArgumentList.Add($RepositoryPath)
    $startInfo.ArgumentList.Add('--no-pager')
    $startInfo.ArgumentList.Add('show')
    $startInfo.ArgumentList.Add("${CommitSha}:parity/inventory.json")
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Unable to start git for inventory commit '$CommitSha'."
    }
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
        if ($process.ExitCode -ne 0) {
            throw "git show ${CommitSha}:parity/inventory.json failed: $stderr"
        }
        return ,$memory.ToArray()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Test-SensitiveValue {
    param($Value, [string]$JsonPath = '$')

    if ($null -eq $Value) {
        return
    }
    if ($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary]) {
        foreach ($property in $Value.PSObject.Properties) {
            $propertyPath = "$JsonPath.$($property.Name)"
            if ($property.Name -match '(?i)^(password|clientSecret|accessToken|privateKey|tenantId|subscriptionId|environmentName|resourceName)$') {
                Add-Failure "Sensitive field is prohibited at $propertyPath."
            }
            Test-SensitiveValue -Value $property.Value -JsonPath $propertyPath
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $index = 0
        foreach ($item in $Value) {
            Test-SensitiveValue -Value $item -JsonPath "$JsonPath[$index]"
            $index++
        }
        return
    }
    if ($Value -is [string]) {
        if ($JsonPath -match '^\$.*handoff' -and $Value -match '(?im)(?:```(?:hcl|terraform)|\b(?:resource|data)\s+"[^"]+"\s+"[^"]+"\s*\{|\b(?:module|variable|output)\s+"[^"]+"\s*\{|\bterraform\s*\{)') {
            Add-Failure "Terraform source is prohibited at $JsonPath."
        }
        if ($Value -match '(?i)/subscriptions/[0-9a-f-]{36}(?:/|$)') {
            Add-Failure "Azure subscription resource ID is prohibited at $JsonPath."
        }
        if ($Value -match '(?i)\b(?:tenant|subscription)(?:\s+id|Id)?\s*[:=]\s*[0-9a-f]{8}-[0-9a-f-]{27,}\b') {
            Add-Failure "Tenant or subscription ID is prohibited at $JsonPath."
        }
        # Pinned public Bicep defaults include example private subnet CIDRs.
        # They are source contract data, not environment evidence.
        if (
            $JsonPath -notmatch '^\$\.surfaceContracts\.inputs\[[0-9]+\]\.default\.value' -and
            $Value -match '(?<![0-9])(?:10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}|192\.168\.(?:[0-9]{1,3}\.)[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.(?:[0-9]{1,3}\.)[0-9]{1,3})(?![0-9])'
        ) {
            Add-Failure "Private IP address is prohibited at $JsonPath."
        }
        if ($Value -match '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----') {
            Add-Failure "Private key material is prohibited at $JsonPath."
        }
        if ($Value -match '(?i)\b(?:password|client[_-]?secret|access[_-]?token)\s*[:=]\s*\S+') {
            Add-Failure "Credential-like content is prohibited at $JsonPath."
        }
        if ($Value -match '(?i)\b(?:environment|resource)\s+name\s*[:=]\s*[a-z0-9][a-z0-9._-]{2,}\b') {
            Add-Failure "Environment-specific resource name is prohibited at $JsonPath."
        }
    }
}

function Test-SensitiveFileContent {
    param([Parameter(Mandatory)] [string]$Path, [Parameter(Mandatory)] [string]$RelativePath)

    $text = [System.IO.File]::ReadAllText($Path)
    $patterns = [ordered]@{
        'credential-like content' = '(?i)\b(?:password|client[_-]?secret|access[_-]?token)\s*["'':=]+\s*[^\s"'',}]+'
        'private key material' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
        'GitHub token material' = '\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b'
        'Azure subscription resource ID' = '(?i)/subscriptions/[0-9a-f-]{36}(?:/|$)'
        'tenant or subscription ID' = '(?i)\b(?:tenant|subscription)(?:\s+id|Id)?\s*["'':=]+\s*[0-9a-f]{8}-[0-9a-f-]{27,}\b'
        'private IP address' = '(?<![0-9])(?:10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}|192\.168\.(?:[0-9]{1,3}\.)[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.(?:[0-9]{1,3}\.)[0-9]{1,3})(?![0-9])'
    }
    # Documented sensitive-scanning exclusions:
    # 1. parity/inventory.json records the pinned public Bicep default address
    #    prefixes as source contract data under surfaceContracts[].default.value.
    #    Structured record scanning keeps the same rule for every other field, so
    #    only the raw private-address pattern is excluded for that one file.
    # 2. parity/schemas/**/*.json declares prohibited field names inside patterns
    #    and enumerations, which the credential pattern would otherwise match.
    # 3. Workflow run logs cannot be scanned offline. The parity workflows never
    #    print record content, tokens, or dispatch payload bodies, and
    #    tests/parity/Test-WorkflowSecurity.Tests.ps1 enforces that contract.
    if ($RelativePath -eq 'parity/inventory.json') {
        $patterns.Remove('private IP address')
    }
    if ($RelativePath -like 'parity/schemas/*') {
        $patterns.Remove('credential-like content')
    }
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($text -match $entry.Value) {
            Add-Failure "$($entry.Key) is prohibited in $RelativePath."
        }
    }
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $gitRootPath = if ($GitRepositoryPath) {
        (Resolve-Path -LiteralPath $GitRepositoryPath).Path
    }
    else {
        $rootPath
    }
    $configurationPath = Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist
    $configuration = Read-ParityJson $configurationPath

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Throw-ParityError 'Node.js is required for parity validation.' 'ParityDependencyMissing'
    }
    $nodeModules = Resolve-ParityPath -Root $rootPath -Path 'node_modules/ajv/package.json'
    if (-not (Test-Path -LiteralPath $nodeModules -PathType Leaf)) {
        Throw-ParityError "Pinned validator dependencies are not installed. Run 'npm ci'." 'ParityDependencyMissing'
    }

    $expectedScenarios = @('standalone-standard', 'standalone-network-isolated')
    if (@($configuration.scenarios).Count -ne 2 -or (Compare-Object $expectedScenarios @($configuration.scenarios))) {
        Add-Failure 'Configuration must contain exactly the two supported standalone scenarios.'
    }
    if (
        $configuration.repositories.source.name -ne 'Azure/bicep-ptn-aiml-landing-zone' -or
        $configuration.repositories.source.releaseTag -ne 'v2.6.1' -or
        $configuration.repositories.source.commitSha -ne '64195c01b70974fa7256c2f54a0035fb06804139'
    ) {
        Add-Failure 'Configured Bicep baseline does not match pinned v2.6.1.'
    }
    if (
        $configuration.repositories.terraform.name -ne 'Azure/terraform-azurerm-avm-ptn-aiml-landing-zone' -or
        $configuration.repositories.terraform.releaseTag -ne 'v0.5.1' -or
        $configuration.repositories.terraform.commitSha -ne 'abe337894f93de3ddda525ea44898b33e1484070'
    ) {
        Add-Failure 'Configured Terraform baseline does not match pinned v0.5.1.'
    }

    $inventorySetting = if ($InventoryPath) { $InventoryPath } else { $configuration.records.inventory }
    $assessmentSetting = if ($AssessmentsPath) { $AssessmentsPath } else { $configuration.records.assessments }
    $handoffSetting = if ($HandoffsPath) { $HandoffsPath } else { $configuration.records.handoffs }
    $evidenceSetting = if ($EvidencePath) { $EvidencePath } else { $configuration.records.evidence }

    $inventoryFiles = @(Get-RecordFiles $inventorySetting)
    $resolvedAssessmentSetting = Resolve-ParityPath -Root $rootPath -Path $assessmentSetting
    $adoptionMarkerPath = if (Test-Path -LiteralPath $resolvedAssessmentSetting -PathType Container) {
        Join-Path $resolvedAssessmentSetting 'adoption-marker.json'
    }
    else {
        $null
    }
    $assessmentFiles = @(
        Get-RecordFiles $assessmentSetting |
            Where-Object { [IO.Path]::GetFileName($_) -ne 'adoption-marker.json' }
    )
    $handoffFiles = @(Get-RecordFiles $handoffSetting)
    $evidenceFiles = @(Get-RecordFiles $evidenceSetting)
    if ($inventoryFiles.Count -gt 1) {
        Add-Failure 'Only one parity inventory record is allowed.'
    }

    $inventories = @()
    foreach ($file in $inventoryFiles) {
        if (Test-RecordSchema $file 'inventory') {
            $inventories += Read-ParityJson $file
        }
    }
    $assessments = @()
    foreach ($file in $assessmentFiles) {
        if (Test-RecordSchema $file 'assessment') {
            $assessments += Read-ParityJson $file
        }
    }
    $handoffs = @()
    foreach ($file in $handoffFiles) {
        if (Test-RecordSchema $file 'terraformHandoff') {
            $handoffs += Read-ParityJson $file
        }
    }
    $evidence = @()
    foreach ($file in $evidenceFiles) {
        if (Test-RecordSchema $file 'parityEvidence') {
            $evidence += Read-ParityJson $file
        }
    }
    if ($adoptionMarkerPath -and (Test-Path -LiteralPath $adoptionMarkerPath -PathType Leaf)) {
        if (Test-RecordSchema $adoptionMarkerPath 'adoptionMarker') {
            $adoptionMarker = Read-ParityJson $adoptionMarkerPath
            if ($adoptionMarker.ledgerBranch -ne $configuration.branches.assessmentLedger) {
                Add-Failure 'The adoption marker ledger branch does not match parity/config.json.'
            }
            if ($adoptionMarker.integrationBranch -ne $configuration.branches.sourceIntegration) {
                Add-Failure 'The adoption marker integration branch does not match parity/config.json.'
            }
        }
    }

    $capabilities = @($inventories | ForEach-Object { $_.capabilities })
    $inventoryDigest = if ($inventoryFiles.Count -eq 1) {
        Get-Sha256Hex (ConvertTo-InventoryRepositoryBytes (
            [System.IO.File]::ReadAllBytes($inventoryFiles[0])
        ))
    }
    else {
        $null
    }
    Test-UniqueValues $capabilities 'id' 'capability ID'
    Test-UniqueValues $assessments 'id' 'assessment ID'
    Test-UniqueValues $handoffs 'id' 'handoff ID'
    Test-UniqueValues $evidence 'id' 'evidence ID'

    $activeBaselines = @($inventories | Where-Object { $_.baseline.status -eq 'active' })
    if ($inventories.Count -gt 0 -and $activeBaselines.Count -ne 1) {
        Add-Failure 'Exactly one active inventory baseline is required.'
    }
    if ($activeBaselines.Count -eq 1) {
        $baseline = $activeBaselines[0].baseline
        foreach ($side in @('source', 'terraform')) {
            $configuredSide = $configuration.repositories.$side
            $actualSide = $baseline.$side
            if (
                $actualSide.repository -ne $configuredSide.name -or
                $actualSide.releaseTag -ne $configuredSide.releaseTag -or
                $actualSide.commitSha -ne $configuredSide.commitSha
            ) {
                Add-Failure "Inventory $side baseline does not match parity/config.json."
            }
        }
    }

    $capabilityIds = @($capabilities | ForEach-Object { $_.id })
    $assessmentIds = @($assessments | ForEach-Object { $_.id })
    $handoffIds = @($handoffs | ForEach-Object { $_.id })
    $evidenceById = @{}
    foreach ($item in $evidence) { $evidenceById[$item.id] = $item }

    foreach ($assessment in $assessments) {
        if ($activeBaselines.Count -eq 1 -and $assessment.baselineId -ne $activeBaselines[0].baseline.id) {
            Add-Failure "Assessment '$($assessment.id)' references an inactive or unknown baseline."
        }
        foreach ($id in $assessment.changedCapabilities) {
            if ($id -notin $capabilityIds) { Add-Failure "Assessment '$($assessment.id)' references unknown capability '$id'." }
        }
        foreach ($id in $assessment.handoffIds) {
            if ($id -notin $handoffIds) { Add-Failure "Assessment '$($assessment.id)' references unknown handoff '$id'." }
        }
    }
    $approvedEligibleHandoffIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($handoff in $handoffs) {
        $eligible = $handoff.approval.status -eq 'approved'
        foreach ($id in $handoff.capabilityIds) {
            if ($id -notin $capabilityIds) { Add-Failure "Handoff '$($handoff.id)' references unknown capability '$id'." }
        }
        if (
            $handoff.provenance.type -eq 'alignment-assessment' -and
            $handoff.provenance.assessmentId -notin $assessmentIds
        ) {
            Add-Failure "Handoff '$($handoff.id)' references unknown assessment '$($handoff.provenance.assessmentId)'."
        }
        if (
            $handoff.source.repository -ne $configuration.repositories.source.name -or
            $handoff.source.ref -ne $configuration.repositories.source.releaseTag -or
            $handoff.source.commitSha -ne $configuration.repositories.source.commitSha -or
            $handoff.target.repository -ne $configuration.repositories.terraform.name -or
            $handoff.target.commitSha -ne $configuration.repositories.terraform.commitSha -or
            $handoff.target.ref -ne $configuration.branches.terraformBase
        ) {
            Add-Failure "Handoff '$($handoff.id)' does not use configured repositories, branch, and baselines."
        }
        if ($handoff.provenance.type -eq 'baseline-inventory') {
            if (
                $activeBaselines.Count -ne 1 -or
                $handoff.provenance.baselineId -ne $activeBaselines[0].baseline.id -or
                $handoff.provenance.inventoryDigest.algorithm -ne 'sha256' -or
                $handoff.provenance.inventoryDigest.value -ne $inventoryDigest
            ) {
                Add-Failure "Handoff '$($handoff.id)' uses stale or mismatched baseline-inventory provenance."
                $eligible = $false
            }
            if ($handoff.approval.status -eq 'approved') {
                foreach ($field in @('inventoryCommitSha', 'inventoryReviewUrl')) {
                    if (
                        $handoff.provenance.PSObject.Properties.Name -notcontains $field -or
                        [string]::IsNullOrWhiteSpace($handoff.provenance.$field)
                    ) {
                        Add-Failure "Approved baseline handoff '$($handoff.id)' is missing provenance.$field."
                        $eligible = $false
                    }
                }
                if (
                    $handoff.provenance.PSObject.Properties.Name -contains 'inventoryReviewUrl' -and
                    $handoff.provenance.inventoryReviewUrl -match '/issues/136(?:$|[?#])'
                ) {
                    Add-Failure "Issue #136 is context, not inventory review evidence for handoff '$($handoff.id)'."
                    $eligible = $false
                }
                if ($handoff.provenance.PSObject.Properties.Name -contains 'inventoryCommitSha') {
                    try {
                        $committedBytes = Get-GitInventoryBytes $gitRootPath $handoff.provenance.inventoryCommitSha
                        $committedDigest = Get-Sha256Hex $committedBytes
                        $committedInventory = [System.Text.UTF8Encoding]::new($false, $true).GetString(
                            $committedBytes
                        ) | ConvertFrom-Json -Depth 100
                        if ($committedDigest -ne $handoff.provenance.inventoryDigest.value) {
                            Add-Failure "Approved baseline handoff '$($handoff.id)' inventory digest does not match its committed inventory."
                            $eligible = $false
                        }
                        if (
                            $committedInventory.baseline.id -ne $handoff.provenance.baselineId -or
                            $committedInventory.baseline.source.commitSha -ne $handoff.source.commitSha -or
                            $committedInventory.baseline.terraform.commitSha -ne $handoff.target.commitSha
                        ) {
                            Add-Failure "Approved baseline handoff '$($handoff.id)' committed inventory has mismatched baseline, source, or target commits."
                            $eligible = $false
                        }
                    }
                    catch {
                        Add-Failure "Approved baseline handoff '$($handoff.id)' cannot verify committed inventory: $($_.Exception.Message)"
                        $eligible = $false
                    }
                }
            }
        }
        elseif ($handoff.approval.status -eq 'approved') {
            $assessment = @($assessments | Where-Object id -eq $handoff.provenance.assessmentId)
            if (
                $assessment.Count -ne 1 -or
                $assessment[0].review.status -ne 'approved' -or
                $assessment[0].outcome -ne 'proposal-required' -or
                $assessment[0].review.approvalUrl -match '/issues/136(?:$|[?#])' -or
                @($handoff.capabilityIds | Where-Object { $_ -notin $assessment[0].changedCapabilities }).Count -gt 0
            ) {
                Add-Failure "Approved alignment handoff '$($handoff.id)' must reference an approved proposal-required assessment covering every capability."
                $eligible = $false
            }
        }
        if ($handoff.approval.status -eq 'approved') {
            foreach ($field in @('approvalUrl', 'approvedBy', 'approvedAt')) {
                if (
                    $handoff.approval.PSObject.Properties.Name -notcontains $field -or
                    [string]::IsNullOrWhiteSpace($handoff.approval.$field)
                ) {
                    Add-Failure "Approved handoff '$($handoff.id)' is missing approval.$field."
                    $eligible = $false
                }
            }
            if (
                $handoff.approval.PSObject.Properties.Name -contains 'approvalUrl' -and
                $handoff.approval.approvalUrl -match '/issues/136(?:$|[?#])'
            ) {
                Add-Failure "Issue #136 is context, not handoff authorization for '$($handoff.id)'."
                $eligible = $false
            }
        }
        if ($eligible) {
            $approvedEligibleHandoffIds.Add($handoff.id) | Out-Null
        }
    }
    $activeHandoffs = @($handoffs | Where-Object { $_.approval.status -in @('pending', 'approved') })
    $activeKeys = @($activeHandoffs | ForEach-Object {
        $provenanceKey = if ($_.provenance.type -eq 'baseline-inventory') {
            "baseline-inventory:$($_.provenance.baselineId):$($_.provenance.inventoryDigest.value)"
        }
        else {
            "alignment-assessment:$($_.provenance.assessmentId)"
        }
        "$provenanceKey|$(@($_.capabilityIds | Sort-Object) -join ',')"
    })
    foreach ($duplicate in @($activeKeys | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "Duplicate active handoff for provenance and capability set '$($duplicate.Name)'."
    }
    foreach ($item in $evidence) {
        $itemCapabilityIds = if ($item.PSObject.Properties.Name -contains 'capabilityIds') {
            @($item.capabilityIds)
        }
        else {
            @()
        }
        foreach ($id in $itemCapabilityIds) {
            if ($id -notin $capabilityIds) { Add-Failure "Evidence '$($item.id)' references unknown capability '$id'." }
        }
        if ($item.targetCommitSha -ne $configuration.repositories.terraform.commitSha) {
            Add-Failure "Evidence '$($item.id)' does not target the configured Terraform baseline."
        }
        if ($item.review.status -eq 'approved') {
            foreach ($field in @('reviewer', 'reviewedAt', 'approvalUrl')) {
                if ($item.review.PSObject.Properties.Name -notcontains $field -or [string]::IsNullOrWhiteSpace($item.review.$field)) {
                    Add-Failure "Approved evidence '$($item.id)' is missing review.$field."
                }
            }
        }
    }

    foreach ($capability in $capabilities) {
        foreach ($scenarioAssessment in $capability.scenarioAssessments) {
            foreach ($id in $scenarioAssessment.proposalIds) {
                if ($id -notin $handoffIds) { Add-Failure "Capability '$($capability.id)' references unknown proposal '$id'." }
                elseif (-not $approvedEligibleHandoffIds.Contains($id)) {
                    Add-Failure "Capability '$($capability.id)' references handoff '$id', which is not approved proposal-eligible."
                }
            }

            foreach ($id in $scenarioAssessment.evidenceIds) {
                if (-not $evidenceById.ContainsKey($id)) {
                    Add-Failure "Capability '$($capability.id)' references unknown evidence '$id'."
                }
                elseif ($evidenceById[$id].scenario -ne $scenarioAssessment.scenario) {
                    Add-Failure "Evidence '$id' is for the wrong scenario for capability '$($capability.id)'."
                }
            }
            if ($scenarioAssessment.parityDeclared) {
                $referenced = @($scenarioAssessment.evidenceIds | ForEach-Object { $evidenceById[$_] } | Where-Object { $null -ne $_ })
                $deployment = @($referenced | Where-Object {
                    $_.type -eq 'scenario-deployment' -and $_.result -eq 'succeeded'
                })
                $comparison = @($referenced | Where-Object {
                    $_.type -eq 'reviewed-capability-comparison' -and
                    $_.result -eq 'succeeded' -and
                    $_.review.status -eq 'approved'
                })
                if ($deployment.Count -eq 0 -or $comparison.Count -eq 0) {
                    Add-Failure "Parity declaration for '$($capability.id)'/$($scenarioAssessment.scenario) lacks successful deployment and approved comparison evidence."
                }
            }
        }
    }

    foreach ($capability in $capabilities) {
        foreach ($scenarioAssessment in $capability.scenarioAssessments) {
            if ($scenarioAssessment.supportStatus -in @('partial', 'absent', 'blocked')) {
                $covering = @($handoffs | Where-Object {
                    $_.approval.status -in @('pending', 'approved', 'rejected', 'superseded') -and
                    $capability.id -in $_.capabilityIds
                })
                if ($covering.Count -eq 0) {
                    Add-Failure "Actionable gap '$($capability.id)'/$($scenarioAssessment.scenario) has no active handoff."
                }
            }
        }
    }

    foreach ($record in @($inventories) + @($assessments) + @($evidence)) {
        Test-SensitiveValue $record
    }
    foreach ($handoff in $handoffs) {
        Test-SensitiveValue -Value $handoff -JsonPath '$.handoff'
    }

    $scanRoots = @('parity', 'tests/parity/fixtures')
    $scannedFiles = 0
    foreach ($scanRoot in $scanRoots) {
        $resolvedScanRoot = Resolve-ParityPath -Root $rootPath -Path $scanRoot
        if (-not (Test-Path -LiteralPath $resolvedScanRoot -PathType Container)) { continue }
        foreach ($file in @(
            Get-ChildItem -LiteralPath $resolvedScanRoot -File -Recurse |
                Where-Object { $_.Extension -in @('.json', '.md', '.yml', '.yaml', '.txt') } |
                Sort-Object FullName
        )) {
            $relative = [IO.Path]::GetRelativePath($rootPath, $file.FullName).Replace('\', '/')
            Test-SensitiveFileContent -Path $file.FullName -RelativePath $relative
            $scannedFiles++
        }
    }

    if ($failures.Count -gt 0) {
        foreach ($failure in ($failures | Sort-Object -Unique)) {
            [Console]::Error.WriteLine($failure)
        }
        exit 1
    }

    Write-Host (
        'Parity assets passed: {0} inventory, {1} capabilities, {2} assessments, {3} handoffs, {4} approved proposal-eligible, {5} evidence records, {6} scanned files.' -f
        $inventories.Count, $capabilities.Count, $assessments.Count, $handoffs.Count,
        $approvedEligibleHandoffIds.Count, $evidence.Count, $scannedFiles
    )
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
