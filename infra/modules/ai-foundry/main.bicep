metadata name = 'ai-foundry'
metadata description = 'Creates an AI Foundry account and project with Standard Agent Services.'

@minLength(3)
@maxLength(12)
@description('Required. A friendly application/environment name to serve as the "base" when using the default naming for all resources in this deployment.')
param baseName string

@maxLength(5)
@description('Optional. A unique text value for the application/environment. This is used to ensure resource names are unique for global resources. Defaults to a 5-character substring of the unique string generated from the subscription ID, resource group name, and base name.')
param baseUniqueName string = substring(uniqueString(subscription().id, resourceGroup().name, baseName), 0, 5)

@description('Optional. Location for all Resources. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

import { deploymentType } from 'br/public:avm/res/cognitive-services/account:0.12.0'
@description('Optional. Specifies the OpenAI deployments to create.')
param aiModelDeployments deploymentType[] = []

@description('Optional. Specifies the resource tags for all the resources.')
param tags resourceInput<'Microsoft.Resources/resourceGroups@2025-04-01'>.tags = {}

import { lockType } from 'br/public:avm/utl/types/avm-common-types:0.6.1'
@description('Optional. The lock settings of the AI resources.')
param lock lockType?

@description('Optional. Whether to include associated resources: Key Vault, AI Search, Storage Account, and Cosmos DB. If true, these resources will be created. Optionally, existing resources of these types can be supplied in their respective parameters. Defaults to false.')
param includeAssociatedResources bool = false

@description('Optional. The Resource ID of the subnet to establish Private Endpoint(s). If provided, private endpoints will be created for the AI Foundry account and associated resources when creating those resource. Each resource will also require supplied private DNS zone resource ID(s) to establish those private endpoints.')
param privateEndpointSubnetResourceId string?

@description('Optional. Custom configuration for the AI Foundry.')
param aiFoundryConfiguration foundryConfigurationType?

@description('Optional. Custom configuration for the Key Vault.')
param keyVaultConfiguration resourceConfigurationType?

@description('Optional. Custom configuration for the AI Search resource.')
param aiSearchConfiguration resourceConfigurationType?

@description('Optional. Custom configuration for the Storage Account.')
param storageAccountConfiguration storageAccountConfigurationType?

@description('Optional. Custom configuration for the Cosmos DB Account.')
param cosmosDbConfiguration resourceConfigurationType?

var resourcesName = toLower(trim(replace(
  replace(
    replace(replace(replace(replace('${baseName}${baseUniqueName}', '-', ''), '_', ''), '.', ''), '/', ''),
    ' ',
    ''
  ),
  '*',
  ''
)))

// set proj name here to also be used for a default storage container name
var projectName = !empty(aiFoundryConfiguration.?project.?name)
  ? aiFoundryConfiguration!.project!.name!
  : 'proj-${resourcesName}'

#disable-next-line no-deployments-resources
resource avmTelemetry 'Microsoft.Resources/deployments@2024-03-01' = if (enableTelemetry) {
  name: '46d3xbcp.ptn.aiml-aifoundry.${replace('-..--..-', '.', '-')}.${substring(uniqueString(deployment().name, location), 0, 4)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        telemetry: {
          type: 'String'
          value: 'For more information, see https://aka.ms/avm/TelemetryInfo'
        }
      }
    }
  }
}

module foundryAccount 'modules/account.bicep' = {
  name: take('module.account.${resourcesName}', 64)
  params: {
    name: !empty(aiFoundryConfiguration.?accountName) ? aiFoundryConfiguration!.accountName! : 'ai${resourcesName}'
    location: !empty(aiFoundryConfiguration.?location) ? aiFoundryConfiguration!.location! : location
    sku: !empty(aiFoundryConfiguration.?sku) ? aiFoundryConfiguration!.sku! : 'S0'
    allowProjectManagement: aiFoundryConfiguration.?allowProjectManagement ?? true
    aiModelDeployments: aiModelDeployments
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    agentSubnetResourceId: aiFoundryConfiguration.?networking.?agentServiceSubnetResourceId
    privateDnsZoneResourceIds: !empty(privateEndpointSubnetResourceId) && !empty(aiFoundryConfiguration.?networking)
      ? [
          aiFoundryConfiguration!.networking!.cognitiveServicesPrivateDnsZoneResourceId!
          aiFoundryConfiguration!.networking!.openAiPrivateDnsZoneResourceId!
          aiFoundryConfiguration!.networking!.aiServicesPrivateDnsZoneResourceId!
        ]
      : []
    roleAssignments: aiFoundryConfiguration.?roleAssignments
    tags: tags
    enableTelemetry: enableTelemetry
    lock: lock
  }
}



module keyVault 'modules/keyVault.bicep' = if (includeAssociatedResources) {
  name: take('module.keyVault.${resourcesName}', 64)
  params: {
    existingResourceId: keyVaultConfiguration.?existingResourceId
    name: take(
      !empty(keyVaultConfiguration) && !empty(keyVaultConfiguration.?name)
        ? keyVaultConfiguration!.name!
        : 'kv${resourcesName}',
      24
    )
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateDnsZoneResourceId: keyVaultConfiguration.?privateDnsZoneResourceId
    roleAssignments: keyVaultConfiguration.?roleAssignments
  }
}

module aiSearch 'modules/aiSearch.bicep' = if (includeAssociatedResources) {
  name: take('module.aiSearch.${resourcesName}', 64)
  params: {
    existingResourceId: aiSearchConfiguration.?existingResourceId
    name: take(!empty(aiSearchConfiguration.?name) ? aiSearchConfiguration!.name! : 'srch${resourcesName}', 60)
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateDnsZoneResourceId: aiSearchConfiguration.?privateDnsZoneResourceId
    roleAssignments: aiSearchConfiguration.?roleAssignments
  }
}

module storageAccount 'modules/storageAccount.bicep' = if (includeAssociatedResources) {
  name: take('module.storageAccount.${resourcesName}', 64)
  #disable-next-line no-unnecessary-dependson
  dependsOn: [aiSearch]
  params: {
    existingResourceId: storageAccountConfiguration.?existingResourceId
    name: take(
      !empty(storageAccountConfiguration.?name) ? storageAccountConfiguration!.name! : 'st${resourcesName}',
      24
    )
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    blobPrivateDnsZoneResourceId: storageAccountConfiguration.?blobPrivateDnsZoneResourceId
    roleAssignments: concat(
      !empty(storageAccountConfiguration) && !empty(storageAccountConfiguration.?roleAssignments)
        ? storageAccountConfiguration!.roleAssignments!
        : [],
      [
        {
          principalId: foundryAccount.outputs.systemAssignedMIPrincipalId!
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        }
      ],
      empty(aiSearchConfiguration.?existingResourceId)
        ? [
            {
              principalId: aiSearch!.outputs.systemAssignedMIPrincipalId!
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
          ]
        : []
    )
  }
}

module cosmosDb 'modules/cosmosDb.bicep' = if (includeAssociatedResources) {
  name: take('module.cosmosDb.${resourcesName}', 64)
  params: {
    existingResourceId: cosmosDbConfiguration.?existingResourceId
    name: take(!empty(cosmosDbConfiguration.?name) ? cosmosDbConfiguration!.name! : 'cos${resourcesName}', 44)
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateDnsZoneResourceId: cosmosDbConfiguration.?privateDnsZoneResourceId
    roleAssignments: cosmosDbConfiguration.?roleAssignments
  }
}

var createCapabilityHosts = (aiFoundryConfiguration.?createCapabilityHosts ?? false) && includeAssociatedResources

module foundryProject 'modules/project/main.bicep' = {
  name: take('module.project.main.${projectName}', 64)
  #disable-next-line no-unnecessary-dependson
  dependsOn: [storageAccount, aiSearch, cosmosDb, keyVault]
  params: {
    name: projectName
    desc: !empty(aiFoundryConfiguration.?project.?desc)
      ? aiFoundryConfiguration!.project!.desc!
      : 'This is the default project for AI Foundry.'
    displayName: !empty(aiFoundryConfiguration.?project.?displayName)
      ? aiFoundryConfiguration!.project!.displayName!
      : '${baseName} Default Project'
    accountName: foundryAccount.outputs.name
    location: foundryAccount.outputs.location
    // NOTE: Only creating capability host for the Foundry Account if associated resources are included AND if the agent service subnet is NOT provided.
    //       When injecting the agent subnet into the Foundry Account, the capability host seems to be automatically created.
    createAccountCapabilityHost: (createCapabilityHosts && empty(aiFoundryConfiguration.?networking.?agentServiceSubnetResourceId))
    createProjectCapabilityHost: createCapabilityHosts
    storageAccountConnection: includeAssociatedResources
      ? {
          resourceName: storageAccount!.outputs.name
          subscriptionId: storageAccount!.outputs.subscriptionId
          resourceGroupName: storageAccount!.outputs.resourceGroupName
        }
      : null
    aiSearchConnection: includeAssociatedResources
      ? {
          resourceName: aiSearch!.outputs.name
          subscriptionId: aiSearch!.outputs.subscriptionId
          resourceGroupName: aiSearch!.outputs.resourceGroupName
        }
      : null
    cosmosDbConnection: includeAssociatedResources
      ? {
          resourceName: cosmosDb!.outputs.name
          subscriptionId: cosmosDb!.outputs.subscriptionId
          resourceGroupName: cosmosDb!.outputs.resourceGroupName
        }
      : null
    tags: tags
    lock: lock
  }
}

@description('Name of the deployed Azure Resource Group.')
output resourceGroupName string = resourceGroup().name

@description('Name of the deployed Azure Key Vault.')
output keyVaultName string = includeAssociatedResources ? keyVault!.outputs.name : ''

@description('Name of the deployed Azure AI Services account.')
output aiServicesName string = foundryAccount.outputs.name

@description('Name of the deployed Azure AI Search service.')
output aiSearchName string = includeAssociatedResources ? aiSearch!.outputs.name : ''

@description('Name of the deployed Azure AI Project.')
output aiProjectName string = foundryProject.outputs.name

@description('Name of the deployed Azure Storage Account.')
output storageAccountName string = includeAssociatedResources ? storageAccount!.outputs.name : ''

@description('Name of the deployed Azure Cosmos DB account.')
output cosmosAccountName string = includeAssociatedResources ? cosmosDb!.outputs.name : ''

@description('Principal ID of the AI Project system-assigned managed identity.')
output aiProjectPrincipalId string = foundryProject.outputs.principalId

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.6.0'

@export()
@description('Custom configuration for a resource, including optional name, existing resource ID, and role assignments.')
type resourceConfigurationType = {
  @description('Optional. Resource ID of an existing resource to use instead of creating a new one. If provided, other parameters are ignored.')
  existingResourceId: string?

  @description('Optional. Name to be used when creating the resource. This is ignored if an existingResourceId is provided.')
  name: string?

  @description('Optional. The Resource ID of the Private DNS Zone that associates with the resource. This is required to establish a Private Endpoint and when \'privateEndpointSubnetResourceId\' is provided.')
  privateDnsZoneResourceId: string?

  @description('Optional. Role assignments to apply to the resource when creating it. This is ignored if an existingResourceId is provided.')
  roleAssignments: roleAssignmentType[]?
}

@export()
@description('Custom configuration for a Storage Account, including optional name, existing resource ID, containers, and role assignments.')
type storageAccountConfigurationType = {
  @description('Optional. Resource Id of an existing Storage Account to use instead of creating a new one. If provided, other parameters are ignored.')
  existingResourceId: string?

  @description('Optional. Name to be used when creating the Storage Account. This is ignored if an existingResourceId is provided.')
  name: string?

  @description('Optional. The Resource ID of the DNS zone "blob" for the Azure Storage Account. This is required to establish a Private Endpoint and when \'privateEndpointSubnetResourceId\' is provided.')
  blobPrivateDnsZoneResourceId: string?

  @description('Optional. Role assignments to apply to the resource when creating it. This is ignored if an existingResourceId is provided.')
  roleAssignments: roleAssignmentType[]?
}

@export()
@description('Custom configuration for a AI Foundry, including optional account name and project configuration.')
type foundryConfigurationType = {
  @description('Optional. The name of the AI Foundry account.')
  accountName: string?

  @description('Optional. The location of the AI Foundry account. Will default to the resource group location if not specified.')
  location: string?

  @description('Optional. SKU of the AI Foundry / Cognitive Services account. Use \'Get-AzCognitiveServicesAccountSku\' to determine a valid combinations of \'kind\' and \'SKU\' for your Azure region. Defaults to \'S0\'.')
  sku:
    | null
    | 'C2'
    | 'C3'
    | 'C4'
    | 'F0'
    | 'F1'
    | 'S'
    | 'S0'
    | 'S1'
    | 'S10'
    | 'S2'
    | 'S3'
    | 'S4'
    | 'S5'
    | 'S6'
    | 'S7'
    | 'S8'
    | 'S9'
    | 'DC0'

  @description('Optional. Whether to create Capability Hosts for the AI Agent Service. If true, the AI Foundry Account and default Project will be created with the capability host for the associated resources. Can only be true if \'includeAssociatedResources\' is true. Defaults to false.')
  createCapabilityHosts: bool?

  @description('Optional. Whether to allow project management in the AI Foundry account. If true, users can create and manage projects within the AI Foundry account. Defaults to true.')
  allowProjectManagement: bool?

  @description('Optional. Values to establish private networking for the AI Foundry account and project.')
  networking: foundryNetworkConfigurationType?

  @description('Optional. AI Foundry default project.')
  project: foundryProjectConfigurationType?

  @description('Optional. Role assignments to apply to the AI Foundry resource when creating it.')
  roleAssignments: roleAssignmentType[]?
}

@export()
@description('Values to establish private networking for the AI Foundry service.')
type foundryNetworkConfigurationType = {
  @description('Optional. The Resource ID of the subnet for the Azure AI Services account. This is required if \'createAIAgentService\' is true.')
  agentServiceSubnetResourceId: string?

  @description('Required. The Resource ID of the Private DNS Zone for the Azure AI Services account.')
  cognitiveServicesPrivateDnsZoneResourceId: string

  @description('Required. The Resource ID of the Private DNS Zone for the OpenAI account.')
  openAiPrivateDnsZoneResourceId: string

  @description('Required. The Resource ID of the Private DNS Zone for the Azure AI Services account.')
  aiServicesPrivateDnsZoneResourceId: string
}

@export()
@description('Custom configuration for an AI Foundry project, including optional name, friendly name, and description.')
type foundryProjectConfigurationType = {
  @description('Optional. The name of the AI Foundry project.')
  name: string?

  @description('Optional. The friendly/display name of the AI Foundry project.')
  displayName: string?

  @description('Optional. The description of the AI Foundry project.')
  desc: string?
}
