@description('Required. Name of the Foundry account.')
param accountName string

@description('Required. Name of the Foundry project.')
param projectName string

@description('Required. Location for the Foundry account.')
param location string

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-script-purge-account-${accountName}'
  location: location
}

resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  scope: resourceGroup()
}

resource locksContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '28bf596f-4eb7-45ce-b5bc-6cf482fec137' // Locks Contributor
  scope: resourceGroup()
}

resource resourceGroupContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(scriptIdentity.id, contributorRole.id, resourceGroup().id)
  properties: {
    principalId: scriptIdentity.properties.principalId
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
  }
}

resource resourceGroupLocksContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(scriptIdentity.id, locksContributorRole.id, resourceGroup().id)
  properties: {
    principalId: scriptIdentity.properties.principalId
    roleDefinitionId: locksContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

resource deleteAccountScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'script-purge-account-${accountName}'
  location: location
  dependsOn: [
    resourceGroupContributorRoleAssignment
    resourceGroupLocksContributorRoleAssignment
  ]
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    arguments: '-SubscriptionId \'${subscription().subscriptionId}\' -ResourceGroupName \'${resourceGroup().name}\' -CognitiveServiceAccountName \'${accountName}\' -ProjectName \'${projectName}\' -Location \'${location}\' -ArmEndpoint \'${environment().resourceManager}\''
    scriptContent: '''
    param(
      [Parameter(Mandatory = $true)]
      [string]$SubscriptionId,

      [Parameter(Mandatory = $true)]
      [string]$ResourceGroupName,

      [Parameter(Mandatory = $true)]
      [string]$CognitiveServiceAccountName,

      [Parameter(Mandatory = $true)]
      [string]$ProjectName,

      [Parameter(Mandatory = $true)]
      [string]$Location,

      [Parameter(Mandatory = $true)]
      [string]$ArmEndpoint,

      [Parameter(Mandatory = $false)]
      [string]$ApiVersion = "2025-06-01"
    )

    try {
      # Remove locks from Cognitive Services project
      Write-Host "Getting any locks Cognitive Services project ${ProjectName}..."
      $projectLockUri = "${ArmEndpoint}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$CognitiveServiceAccountName/projects/$ProjectName/providers/Microsoft.Authorization/locks?api-version=2016-09-01"
      $projectLocks = (Invoke-AzRestMethod -Method GET -Uri $projectLockUri).Content | ConvertFrom-Json
      if ($projectLocks.value) {
          Write-Host "Found locks on Cognitive Services project ${ProjectName}:" -ForegroundColor Yellow
          foreach ($lock in $projectLocks.value) {
              Write-Host "Removing lock $($lock.id)..." -ForegroundColor Yellow
              $lockId = $lock.id
              Invoke-AzRestMethod -Method DELETE -Uri "${ArmEndpoint}${lockId}?api-version=2016-09-01"
              Write-Host "Lock $($lock.id) removed successfully." -ForegroundColor Green
          }

          Write-Host "Waiting for locks to be removed..."
          Start-Sleep -Seconds 10
      } else {
          Write-Host "No locks found on Cognitive Services project ${ProjectName}." -ForegroundColor Green
      }

      # Remove locks from Cognitive Services account
      Write-Host "Getting any locks on Cognitive Services account ${CognitiveServiceAccountName}..."
      $accountLockUri = "${ArmEndpoint}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$CognitiveServiceAccountName/providers/Microsoft.Authorization/locks?api-version=2016-09-01"
      $accountLocks = (Invoke-AzRestMethod -Method GET -Uri $accountLockUri).Content | ConvertFrom-Json
      if ($accountLocks.value) {
          Write-Host "Found locks on Cognitive Services account ${CognitiveServiceAccountName}:" -ForegroundColor Yellow
          foreach ($lock in $accountLocks.value) {
              Write-Host "Removing lock $($lock.id)..." -ForegroundColor Yellow
              $lockId = $lock.id
              Invoke-AzRestMethod -Method DELETE -Uri "${ArmEndpoint}${lockId}?api-version=2016-09-01"
              Write-Host "Lock $($lock.id) removed successfully." -ForegroundColor Green
          }

          Write-Host "Waiting for locks to be removed..."
          Start-Sleep -Seconds 10
      } else {
          Write-Host "No locks found on Cognitive Services account ${CognitiveServiceAccountName}." -ForegroundColor Green
      }

      # Delete Cognitive Services project
      Write-Host "Deleting Cognitive Services project ${ProjectName}..." -ForegroundColor Yellow
      Invoke-AzRestMethod -Method DELETE -Uri "${ArmEndpoint}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$CognitiveServiceAccountName/projects/${ProjectName}?api-version=$ApiVersion"
      Write-Host "Cognitive Services project ${ProjectName} deleted successfully." -ForegroundColor Green

      Write-Host "Waiting for project to be removed..."
      Start-Sleep -Seconds 5

      # Delete Cognitive Services account
      Write-Host "Deleting Cognitive Services account ${CognitiveServiceAccountName}..." -ForegroundColor Yellow
      Remove-AzCognitiveServicesAccount -ResourceGroupName $ResourceGroupName -Name $CognitiveServiceAccountName -Force
      Write-Host "Cognitive Services account ${CognitiveServiceAccountName} deleted successfully." -ForegroundColor Green

      Write-Host "Waiting for account to be removed..."
      Start-Sleep -Seconds 5

      # Purge deleted Cognitive Services account
      Write-Host "Purging deleted Cognitive Services account ${CognitiveServiceAccountName}..." -ForegroundColor Yellow
      Invoke-AzRestMethod -Method DELETE -Uri "${ArmEndpoint}subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Location/resourceGroups/$ResourceGroupName/deletedAccounts/${CognitiveServiceAccountName}?api-version=$ApiVersion"
      Write-Host "Cognitive Services account ${CognitiveServiceAccountName} purged successfully." -ForegroundColor Green

      Write-Host "Purge operation completed successfully." -ForegroundColor Green
    } catch {
      Write-Host "ERROR: An error occurred while removing locking dependences:" -ForegroundColor Red
      Write-Error $_
      throw
    }
    '''
    timeout: 'P1D'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}
