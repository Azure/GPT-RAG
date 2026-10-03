<#
.SYNOPSIS
    Prepares and optionally sends a bounded parity dispatch for an approved handoff.

.DESCRIPTION
    Verifies handoff approval, provenance, repository and branch allow-lists, baseline
    freshness, and open inventory gaps, then writes an identifier-only
    repository_dispatch payload. An already recorded Terraform proposal is reconciled
    and never dispatched twice. The optional dispatch command receives only the payload
    file path, so this script never handles credentials.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory)] [string]$HandoffPath,
    [Parameter(Mandatory)] [string]$HandoffCommitSha,
    [Parameter(Mandatory)] [string]$HandoffRef,
    [Parameter(Mandatory)] [string]$PayloadPath,
    [string]$EventType = 'parity-proposal-requested',
    [string[]]$DispatchCommand = @(),
    [string]$ConfigPath = 'parity/config.json',
    [string]$InventoryPath,
    [string]$AssessmentsPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Parity.Common.ps1')

# The dispatch payload is an identifier-only allow-list. Raw pull request titles,
# bodies, diffs, credentials, and Azure identifiers are never published.
$allowedPayloadProperties = @(
    'capabilityIds', 'handoffCommitSha', 'handoffDigest', 'handoffId', 'handoffPath',
    'handoffRef', 'handoffSchemaPath', 'inventoryCommitSha', 'inventoryDigest',
    'inventoryReviewUrl', 'payloadVersion', 'provenanceId', 'provenanceType',
    'sourceCommitSha', 'sourcePrNumber', 'sourceRef', 'sourceRepository', 'targetCommitSha',
    'targetRef', 'targetRepository'
)
$maximumPayloadBytes = 60KB
$payloadVersion = '2.0.0'

function ConvertTo-RepositoryBytes {
    param([Parameter(Mandatory)] [byte[]]$Bytes)

    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    return ,[System.Text.UTF8Encoding]::new($false).GetBytes($text.Replace("`r`n", "`n"))
}

function Get-ByteDigest {
    param([Parameter(Mandatory)] [byte[]]$Bytes)

    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-GitText {
    param(
        [Parameter(Mandatory)] [string]$RepositoryPath,
        [Parameter(Mandatory)] [string[]]$Arguments
    )

    $output = & git -C $RepositoryPath @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Throw-ParityError "git $($Arguments -join ' ') failed: $($output.Trim())" 'ParityGitFailure'
    }
    return $output.Trim()
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory)] [string]$RepositoryPath,
        [Parameter(Mandatory)] [string]$CommitSha,
        [Parameter(Mandatory)] [string]$RepositoryRelativePath
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'git'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('-C', $RepositoryPath, 'cat-file', 'blob', "$CommitSha`:$RepositoryRelativePath")) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        Throw-ParityError 'Unable to start git for handoff artifact verification.' 'ParityGitFailure'
    }

    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            Throw-ParityError (
                "Artifact '$RepositoryRelativePath' is absent at handoff commit '$CommitSha': $($errorText.Trim())"
            ) 'ParityMissingHandoffArtifact'
        }
        return ,$memory.ToArray()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

try {
    $rootPath = Resolve-ParityPath -Root $Root -Path '.'
    $config = Read-ParityJson (Resolve-ParityPath -Root $rootPath -Path $ConfigPath -MustExist)

    $handoffRoot = Resolve-ParityPath -Root $rootPath -Path $config.records.handoffs
    $resolvedHandoffPath = Resolve-ParityPath -Root $rootPath -Path $HandoffPath -MustExist
    $handoffPrefix = "$handoffRoot$([System.IO.Path]::DirectorySeparatorChar)"
    if (-not $resolvedHandoffPath.StartsWith($handoffPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Throw-ParityError "Path '$HandoffPath' is outside the configured handoff records." 'ParityInvalidHandoffPath'
    }
    $handoff = Read-ParityJson $resolvedHandoffPath
    $relativeHandoffPath = [IO.Path]::GetRelativePath($rootPath, $resolvedHandoffPath).Replace('\', '/')

    if (
        $handoff.target.repository -ne $config.repositories.terraform.name -or
        $handoff.target.ref -ne $config.branches.terraformBase -or
        $handoff.source.repository -ne $config.repositories.source.name
    ) {
        Throw-ParityError (
            "Handoff '$($handoff.id)' is outside the configured repository and branch allow-list."
        ) 'ParityAllowListViolation'
    }

    $inventorySetting = if ($InventoryPath) { $InventoryPath } else { $config.records.inventory }
    $resolvedInventoryPath = Resolve-ParityPath -Root $rootPath -Path $inventorySetting -MustExist
    $inventoryBytes = ConvertTo-RepositoryBytes ([System.IO.File]::ReadAllBytes($resolvedInventoryPath))
    $inventoryDigest = Get-ByteDigest $inventoryBytes
    $inventory = Read-ParityJson $resolvedInventoryPath
    if (
        $inventory.baseline.status -ne 'active' -or
        $inventory.baseline.source.commitSha -ne $config.repositories.source.commitSha -or
        $inventory.baseline.terraform.commitSha -ne $config.repositories.terraform.commitSha -or
        $handoff.source.commitSha -ne $config.repositories.source.commitSha -or
        $handoff.target.commitSha -ne $config.repositories.terraform.commitSha -or
        $handoff.source.ref -ne $config.repositories.source.releaseTag
    ) {
        Throw-ParityError "Handoff '$($handoff.id)' uses a stale baseline." 'ParityStaleBaseline'
    }

    if (
        $handoff.PSObject.Properties.Name -contains 'terraformPullRequestUrl' -and
        -not [string]::IsNullOrWhiteSpace($handoff.terraformPullRequestUrl)
    ) {
        Write-Host (
            "Existing proposal $($handoff.terraformPullRequestUrl) already covers handoff '$($handoff.id)'; no dispatch was sent."
        )
        exit 0
    }

    if ($HandoffCommitSha -cnotmatch '^[0-9a-f]{40}$') {
        Throw-ParityError 'HandoffCommitSha must be a 40-character lower-case Git commit SHA.' 'ParityInvalidHandoffArtifact'
    }
    if ($HandoffRef -ne $config.branches.sourceIntegration) {
        Throw-ParityError (
            "Handoff ref '$HandoffRef' is outside the configured source branch allow-list."
        ) 'ParityAllowListViolation'
    }

    $headCommitSha = Invoke-GitText -RepositoryPath $rootPath -Arguments @('rev-parse', 'HEAD')
    if ($headCommitSha -ne $HandoffCommitSha) {
        Throw-ParityError (
            "Handoff commit '$HandoffCommitSha' is not the trusted checkout commit '$headCommitSha'."
        ) 'ParityInvalidHandoffArtifact'
    }
    $null = Invoke-GitText -RepositoryPath $rootPath -Arguments @('cat-file', '-e', "$HandoffCommitSha^{commit}")

    $handoffSchemaPath = "$($config.schemas.terraformHandoff)".Replace('\', '/')
    if (
        $handoffSchemaPath -notmatch '^parity/schemas/[^/]+\.schema\.json$' -or
        $relativeHandoffPath -notmatch '^parity/handoffs/.+\.json$'
    ) {
        Throw-ParityError 'Handoff artifact paths are outside the bounded parity path allow-list.' 'ParityInvalidHandoffPath'
    }
    $resolvedHandoffSchemaPath = Resolve-ParityPath -Root $rootPath -Path $handoffSchemaPath -MustExist
    $committedHandoffBytes = ConvertTo-RepositoryBytes (
        Get-GitBlobBytes -RepositoryPath $rootPath -CommitSha $HandoffCommitSha -RepositoryRelativePath $relativeHandoffPath
    )
    $workingHandoffBytes = ConvertTo-RepositoryBytes ([System.IO.File]::ReadAllBytes($resolvedHandoffPath))
    if ((Get-ByteDigest $committedHandoffBytes) -ne (Get-ByteDigest $workingHandoffBytes)) {
        Throw-ParityError (
            "Handoff '$relativeHandoffPath' differs from its committed bytes at '$HandoffCommitSha'."
        ) 'ParityHandoffArtifactMismatch'
    }
    $committedSchemaBytes = ConvertTo-RepositoryBytes (
        Get-GitBlobBytes -RepositoryPath $rootPath -CommitSha $HandoffCommitSha -RepositoryRelativePath $handoffSchemaPath
    )
    $workingSchemaBytes = ConvertTo-RepositoryBytes ([System.IO.File]::ReadAllBytes($resolvedHandoffSchemaPath))
    if ((Get-ByteDigest $committedSchemaBytes) -ne (Get-ByteDigest $workingSchemaBytes)) {
        Throw-ParityError (
            "Handoff schema '$handoffSchemaPath' differs from its committed bytes at '$HandoffCommitSha'."
        ) 'ParityHandoffArtifactMismatch'
    }
    $handoffDigest = Get-ByteDigest $committedHandoffBytes

    if ($handoff.approval.status -ne 'approved') {
        Throw-ParityError (
            "Handoff '$($handoff.id)' is '$($handoff.approval.status)' and is not dispatch-eligible; only an approved handoff can be published."
        ) 'ParityUnapprovedHandoff'
    }
    foreach ($field in @('approvalUrl', 'approvedBy', 'approvedAt')) {
        if (
            $handoff.approval.PSObject.Properties.Name -notcontains $field -or
            [string]::IsNullOrWhiteSpace($handoff.approval.$field)
        ) {
            Throw-ParityError "Approved handoff '$($handoff.id)' is missing approval.$field." 'ParityMissingApproval'
        }
    }
    if ($handoff.approval.approvalUrl -match '/issues/136(?:$|[?#])') {
        Throw-ParityError "Issue #136 is context, not handoff authorization for '$($handoff.id)'." 'ParityMissingApproval'
    }

    $sourcePullRequestNumber = $null
    if ($handoff.provenance.type -eq 'baseline-inventory') {
        foreach ($field in @('inventoryCommitSha', 'inventoryReviewUrl')) {
            if (
                $handoff.provenance.PSObject.Properties.Name -notcontains $field -or
                [string]::IsNullOrWhiteSpace($handoff.provenance.$field)
            ) {
                Throw-ParityError "Approved baseline handoff '$($handoff.id)' is missing provenance.$field." 'ParityInvalidProvenance'
            }
        }
        if ($handoff.provenance.inventoryReviewUrl -match '/issues/136(?:$|[?#])') {
            Throw-ParityError "Issue #136 is context, not inventory review evidence for '$($handoff.id)'." 'ParityInvalidProvenance'
        }
        if (
            $handoff.provenance.baselineId -ne $inventory.baseline.id -or
            $handoff.provenance.inventoryDigest.algorithm -ne 'sha256' -or
            $handoff.provenance.inventoryDigest.value -ne $inventoryDigest
        ) {
            Throw-ParityError "Handoff '$($handoff.id)' uses a stale or mismatched inventory digest." 'ParityStaleBaseline'
        }
        $provenanceId = $handoff.provenance.baselineId
    }
    else {
        $assessmentSetting = if ($AssessmentsPath) { $AssessmentsPath } else { $config.records.assessments }
        $assessmentRoot = Resolve-ParityPath -Root $rootPath -Path $assessmentSetting -MustExist
        $assessments = @(
            Get-ChildItem -LiteralPath $assessmentRoot -Filter '*.json' -File -Recurse |
                Sort-Object FullName |
                ForEach-Object { Read-ParityJson $_.FullName } |
                Where-Object { $_.PSObject.Properties.Name -contains 'sourcePr' -and $_.id -eq $handoff.provenance.assessmentId }
        )
        if ($assessments.Count -ne 1) {
            Throw-ParityError (
                "Handoff '$($handoff.id)' references unknown assessment '$($handoff.provenance.assessmentId)'."
            ) 'ParityUnknownAssessment'
        }
        $assessment = $assessments[0]
        if (
            $assessment.review.status -ne 'approved' -or
            $assessment.outcome -ne 'proposal-required' -or
            $assessment.review.approvalUrl -match '/issues/136(?:$|[?#])' -or
            @($handoff.capabilityIds | Where-Object { $_ -notin $assessment.changedCapabilities }).Count -gt 0
        ) {
            Throw-ParityError (
                "Handoff '$($handoff.id)' requires an approved proposal-required assessment covering every capability."
            ) 'ParityInvalidProvenance'
        }
        $provenanceId = $assessment.id
        $sourcePullRequestNumber = [int]$assessment.sourcePr.number
    }

    $capabilities = @($inventory.capabilities | Where-Object { $_.id -in @($handoff.capabilityIds) })
    $knownIds = @($capabilities | ForEach-Object { $_.id })
    $unknown = @(@($handoff.capabilityIds) | Where-Object { $_ -notin $knownIds })
    if ($unknown.Count -gt 0) {
        Throw-ParityError "Handoff '$($handoff.id)' references unknown capability: $($unknown -join ', ')." 'ParityUnknownCapability'
    }
    $openGaps = @(
        $capabilities |
            ForEach-Object { @($_.scenarioAssessments) } |
            Where-Object { $_.supportStatus -in @('partial', 'absent', 'blocked') }
    )
    if ($openGaps.Count -eq 0) {
        Throw-ParityError (
            "Handoff '$($handoff.id)' has no open inventory gap; publication would create an unnecessary proposal."
        ) 'ParityMissingGap'
    }

    $clientPayload = [ordered]@{
        payloadVersion = $payloadVersion
        handoffId = $handoff.id
        handoffPath = $relativeHandoffPath
        handoffSchemaPath = $handoffSchemaPath
        handoffCommitSha = $HandoffCommitSha
        handoffRef = $HandoffRef
        handoffDigest = $handoffDigest
        provenanceType = $handoff.provenance.type
        provenanceId = $provenanceId
        capabilityIds = @($handoff.capabilityIds | Sort-Object)
        sourceRepository = $handoff.source.repository
        sourceRef = $handoff.source.ref
        sourceCommitSha = $handoff.source.commitSha
        targetRepository = $handoff.target.repository
        targetRef = $handoff.target.ref
        targetCommitSha = $handoff.target.commitSha
    }
    if ($handoff.provenance.type -eq 'baseline-inventory') {
        $clientPayload['inventoryDigest'] = $handoff.provenance.inventoryDigest.value
        $clientPayload['inventoryCommitSha'] = $handoff.provenance.inventoryCommitSha
        $clientPayload['inventoryReviewUrl'] = $handoff.provenance.inventoryReviewUrl
    }
    else {
        $clientPayload['sourcePrNumber'] = $sourcePullRequestNumber
    }
    $unexpected = @($clientPayload.Keys | Where-Object { $_ -notin $allowedPayloadProperties })
    if ($unexpected.Count -gt 0) {
        Throw-ParityError "Dispatch payload contains unbounded content: $($unexpected -join ', ')." 'ParityUnboundedPayload'
    }

    $payload = [ordered]@{ event_type = $EventType; client_payload = $clientPayload }
    $payloadJson = ($payload | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    if ([System.Text.Encoding]::UTF8.GetByteCount($payloadJson) -gt $maximumPayloadBytes) {
        Throw-ParityError 'Dispatch payload exceeds the bounded size limit.' 'ParityUnboundedPayload'
    }
    $sensitivePatterns = [ordered]@{
        'Terraform source' = '(?im)(?:```(?:hcl|terraform)|\b(?:resource|data)\s+"[^"]+"\s+"[^"]+"\s*\{|\bterraform\s*\{)'
        'credential-like content' = '(?i)\b(?:password|client[_-]?secret|access[_-]?token)\s*["'':=]+\s*\S+'
        'Azure identifier' = '(?i)/subscriptions/[0-9a-f-]{36}(?:/|$)'
        'private key material' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    }
    foreach ($entry in $sensitivePatterns.GetEnumerator()) {
        if ($payloadJson -match $entry.Value) {
            Throw-ParityError "$($entry.Key) is prohibited in a parity dispatch payload." 'ParitySensitiveContent'
        }
    }

    $resolvedPayloadPath = Resolve-ParityPath -Root $rootPath -Path $PayloadPath
    Write-ParityFileAtomic -Path $resolvedPayloadPath -Content $payloadJson

    $command = @(
        $DispatchCommand |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
    if ($command.Count -eq 0) {
        Write-Host (
            "Prepared bounded dispatch payload for handoff '$($handoff.id)' at $PayloadPath; no dispatch command was supplied."
        )
        exit 0
    }

    $executable = $command[0]
    $arguments = @($command | Select-Object -Skip 1) + @($resolvedPayloadPath)
    $output = & $executable @arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Throw-ParityError (
            "The target repository rejected the parity dispatch for handoff '$($handoff.id)': $($output.Trim())"
        ) 'ParityDispatchRejected'
    }
    Write-Host "Dispatched handoff '$($handoff.id)' to $($handoff.target.repository) as event '$EventType'."
}
catch {
    Write-Error "$($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    exit 1
}
