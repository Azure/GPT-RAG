@description('Required. Name of the deployment script.')
param name string

@description('Required. Location for the deployment script.')
param location string

@description('Required. Sleep/wait time for the deployment script in seconds.')
param seconds int

resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: name
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
    timeout: 'P1D'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}
