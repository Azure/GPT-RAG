import { roleAssignmentInfo } from '../security/managed-identity.bicep'

@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}
@description('MSI Id.')
param identityId string?

param containerRegistryReuse bool
param existingContainerRegistryResourceGroupName string

@export()
@description('SKU information for Container Registry.')
type skuInfo = {
  @description('Name of the SKU.')
  name: 'Basic' | 'Premium' | 'Standard'
}

@description('Whether to enable an admin user that has push and pull access. Defaults to false.')
param adminUserEnabled bool = false
@description('Whether to allow public network access. Defaults to Enabled.')
@allowed([
  'Disabled'
  'Enabled'
])
param publicNetworkAccess string = 'Enabled'
@description('Container Registry SKU. Defaults to Basic.')
param sku skuInfo = {
  name: 'Basic'
}
@description('Role assignments to create for the Container Registry.')
param roleAssignments roleAssignmentInfo[] = []

resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' existing = if (containerRegistryReuse) {
  scope: resourceGroup(existingContainerRegistryResourceGroupName)
  name: name
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = if (!containerRegistryReuse) {
  name: name
  location: location
  tags: tags
  identity: {
    type: identityId == null ? 'SystemAssigned' : 'UserAssigned'
    userAssignedIdentities: identityId == null
      ? null
      : {
          '${identityId}': {}
        }
  }
  sku: sku
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: [
      ]
    }
  }
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleAssignment in roleAssignments: {
    name: guid(containerRegistry.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    scope: containerRegistry
    properties: {
      principalId: roleAssignment.principalId
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalType: roleAssignment.principalType
    }
  }
]

@description('ID for the deployed Container Registry resource.')
output id string = containerRegistryReuse ? existingContainerRegistry.id: containerRegistry.id
@description('Name for the deployed Container Registry resource.')
output name string = containerRegistryReuse ? existingContainerRegistry.name : containerRegistry.name
@description('Login server for the deployed Container Registry resource.')
output loginServer string = containerRegistryReuse ? existingContainerRegistry.properties.loginServer : containerRegistry.properties.loginServer
