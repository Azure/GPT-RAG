targetScope = 'subscription'

metadata name = 'Using large parameter set'
metadata description = 'This instance deploys the module with most of its features enabled.'

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
param serviceShort string = 'fndrymax'

@description('Optional. A token to inject into the name of each resource. This value can be automatically injected by the CI.')
param namePrefix string = '#_namePrefix_#'

@description('Optional. Whether to remove the locking dependency after deployment. Defaults to false.')
param removeLockingDependencyAfterDeployment bool = false

// Setting max length to 12 to stay within bounds of baseName length constraints.
// Setting min length to 12 to prevent min-char warnings on the test deployment.
// These warnings cannot be disabled due to AVM processes not able to parse the # characer.
var workloadName = take(padLeft('${namePrefix}${serviceShort}', 12), 12)

// ============ //
// Dependencies //
// ============ //

module dependencies 'dependencies.bicep' = {
  name: take('module.dependencies.${workloadName}', 64)
  scope: resourceGroup
  params: {
    workloadName: workloadName
    location: enforcedLocation
  }
}

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
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
      baseUniqueName: substring(uniqueString(subscription().id, resourceGroup.name, serviceShort), 0, 5)
      location: enforcedLocation
      includeAssociatedResources: true
      privateEndpointSubnetResourceId: dependencies.outputs.subnetPrivateEndpointsResourceId
      aiFoundryConfiguration: {
        accountName: 'aifcustom${workloadName}'
        location: enforcedLocation
        sku: 'S0'
        createCapabilityHosts: true
        project: {
          name: 'projcustom${workloadName}'
          displayName: 'Custom Project for ${workloadName}'
          desc: 'This is a custom project for testing.'
        }
        allowProjectManagement: true
        networking: {
          agentServiceSubnetResourceId: dependencies.outputs.subnetAgentResourceId
          aiServicesPrivateDnsZoneResourceId: dependencies.outputs.servicesAiDnsZoneResourceId
          openAiPrivateDnsZoneResourceId: dependencies.outputs.openaiDnsZoneResourceId
          cognitiveServicesPrivateDnsZoneResourceId: dependencies.outputs.cognitiveServicesDnsZoneResourceId
        }
        roleAssignments: [
          {
            principalId: dependencies.outputs.managedIdentityPrincipalId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
          }
        ]
      }
      keyVaultConfiguration: {
        name: 'kvcustom${workloadName}'
        privateDnsZoneResourceId: dependencies.outputs.keyVaultDnsZoneResourceId
        roleAssignments: [
          {
            principalId: dependencies.outputs.managedIdentityPrincipalId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Key Vault Secrets User'
          }
        ]
      }
      storageAccountConfiguration: {
        name: 'stcustom${workloadName}'
        blobPrivateDnsZoneResourceId: dependencies.outputs.blobDnsZoneResourceId
        roleAssignments: [
          {
            principalId: dependencies.outputs.managedIdentityPrincipalId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Storage Blob Data Contributor'
          }
        ]
      }
      cosmosDbConfiguration: {
        name: 'cosmoscustom${workloadName}'
        privateDnsZoneResourceId: dependencies.outputs.documentsDnsZoneResourceId
        roleAssignments: [
          {
            principalId: dependencies.outputs.managedIdentityPrincipalId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Cosmos DB Account Reader Role'
          }
        ]
      }
      aiSearchConfiguration: {
        name: 'srchcustom${workloadName}'
        privateDnsZoneResourceId: dependencies.outputs.searchDnsZoneResourceId
        roleAssignments: [
          {
            principalId: dependencies.outputs.managedIdentityPrincipalId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Search Index Data Contributor'
          }
        ]
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
      lock: {
        kind: 'CanNotDelete'
        name: 'lock${workloadName}'
      }
      tags: {
        'hidden-title': 'This is visible in the resource name'
        Environment: 'Example'
        Role: 'DeploymentValidation'
      }
    }
  }
]

// Custom module call to remove locking dependencies that can cause errors during the resource removal step
module removeLockingDependencies '../../shared/removeLockingDependencies.bicep' = if (removeLockingDependencyAfterDeployment) {
  name: take('module.removeLockingDependencies.${workloadName}', 64)
  scope: resourceGroup
  dependsOn: [testDeployment]
  params: {
    accountName: testDeployment[0].outputs.aiServicesName
    projectName: testDeployment[0].outputs.aiProjectName
    location: enforcedLocation
  }
}
