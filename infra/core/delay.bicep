param location string = resourceGroup().location
param utcValue string = utcNow()
param sleepName string = 'sleep-1'
param sleepSeconds int = 120
resource sleepDelay 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: sleepName
  location: location
  kind: 'AzurePowerShell'  
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '8.3'
    timeout: 'PT10M'    
    arguments: '-seconds ${sleepSeconds}'    
    scriptContent: '''
    param ( [string] $seconds )    
    Write-Output Sleeping for: $seconds ....
    Start-Sleep -Seconds $seconds   
    Write-Output Sleep over - resuming ....
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
output location string = sleepDelay.location
