// core/identity/b2c-policies.bicep
param name string
param tenantId string
param keyVaultName string

@description('B2C Policy ID')
param policyId string = 'B2C_1_signupsignin1'

@description('Storage account name for B2C custom UI')
param azureB2cStorageAccountName string = ''
var b2cStorageAccountName = !empty(azureB2cStorageAccountName) ? azureB2cStorageAccountName : 'adb2auth'

@description('Storage container name for B2C custom UI')
param azureB2cContainerName string = ''
var b2cContainerName = !empty(azureB2cContainerName) ? azureB2cContainerName : 'auth'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: b2cStorageAccountName
}

resource signUpSignInPolicy 'Microsoft.AzureActiveDirectory/b2cDirectories/userFlows@2021-04-01' = {
  name: '${name}/${policyId}'
  properties: {
    userFlowType: 'signUpOrSignIn'
    contentDefinitions: [
      {
        id: 'api.signuporsignin'
        loadUri: 'https://${storageAccount.name}.blob.core.windows.net/${b2cContainerName}/loginpage.html'
        dataUri: 'urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.19'
      }
      {
        id: 'api.localaccountpasswordchange'
        loadUri: 'https://${storageAccount.name}.blob.core.windows.net/${b2cContainerName}/loginpage.html'
        dataUri: 'urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.31'
      }
      {
        id: 'api.selfasserted.emailverify'
        loadUri: 'https://${storageAccount.name}.blob.core.windows.net/${b2cContainerName}/multifactor.html'
        dataUri: 'urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.31'
      }
    ]
    identityProviders: [
      {
        id: 'localAccount'
        type: 'local'
        properties: {
          signInMethods: [
            'emailAddress'
          ]
        }
      }
    ]
    userAttributes: [
      {
        id: 'displayName'
        required: true
        userInputType: 'textBox'
      }
      {
        id: 'emailAddress'
        required: true
        userInputType: 'emailBox'
      }
      {
        id: 'extension_Role'
        required: false
        userInputType: 'textBox'
      }
      {
        id: 'extension_organizationId'
        required: false
        userInputType: 'textBox'
      }
      {
        id: 'extension_stripe_subscription_id'
        required: false
        userInputType: 'textBox'
      }
    ]
    tokenLifetimeConfiguration: {
      accessTokenLifetime: 'PT1H'
      idTokenLifetime: 'PT1H'
      refreshTokenLifetime: 'P14D'
      rollingRefreshTokenLifetime: 'P90D'
    }
  }
}

// Store B2C tenant details in Key Vault
resource b2cTenantIdSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'b2cTenantId'
  properties: {
    value: tenantId
  }
}

resource b2cPolicyIdSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'b2cPolicyId'
  properties: {
    value: policyId
  }
}

output policyId string = signUpSignInPolicy.name
output policyUrl string = 'https://${name}.b2clogin.com/${tenantId}/oauth2/v2.0/authorize?p=${policyId}'
