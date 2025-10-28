targetScope = 'subscription'

metadata name = 'Bring Your Own Resources'
metadata description = 'Creates an AI Foundry account and project and provides option to bring your own resources created elsewhere.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-bicep-${serviceShort}-rg'

// Due to AI Services capacity constraints, this region must be used in the AVM testing subscription
#disable-next-line no-hardcoded-location
import { enforcedLocation } from '../../shared/constants.bicep'

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'fndrybyo'

@description('Optional. A token to inject into the name of each resource. This value can be automatically injected by the CI.')
param namePrefix string = '#_namePrefix_#'

// Setting max length to 12 to stay within bounds of baseName length constraints.
// Setting min length to 12 to prevent min-char warnings on the test deployment.
// These warnings cannot be disabled due to AVM processes not able to parse the # characer.
var workloadName = take(padLeft('${namePrefix}${serviceShort}', 12), 12)

// ============ //
// Dependencies //
// ============ //

resource dependenciesResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'dep-${namePrefix}-bicep-${serviceShort}-dependencies-rg'
  location: enforcedLocation
}

module dependencies 'dependencies.bicep' = {
  name: take('module.dependencies.${workloadName}', 64)
  scope: dependenciesResourceGroup
  params: {
    workloadName: workloadName
    location: enforcedLocation
  }
}

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: enforcedLocation
}

// ============== //
// Test Execution //
// ============== //

@batchSize(1)
module testDeployment '../../../main.bicep' = [
  for iteration in ['init', 'idem']: {
    scope: resourceGroup
    name: '${uniqueString(deployment().name, enforcedLocation)}-test-${serviceShort}-${iteration}'
    params: {
      baseName: workloadName
      includeAssociatedResources: true
      aiFoundryConfiguration: {
        createCapabilityHosts: true
      }
      keyVaultConfiguration: {
        existingResourceId: dependencies.outputs.keyVaultResourceId
      }
      storageAccountConfiguration: {
        existingResourceId: dependencies.outputs.storageAccountResourceId
      }
      cosmosDbConfiguration: {
        existingResourceId: dependencies.outputs.cosmosDbAccountResourceId
      }
      aiSearchConfiguration: {
        existingResourceId: dependencies.outputs.aiSearchResourceId
      }
      aiModelDeployments: [
        {
          name: 'gpt-4o'
          model: {
            format: 'OpenAI'
            name: 'gpt-4o'
            version: '2024-11-20'
          }
          sku: {
            name: 'Standard'
            capacity: 1
          }
        }
      ]
    }
  }
]
