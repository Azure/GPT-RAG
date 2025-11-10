# Changelog

The latest version of the changelog can be found [here](https://github.com/Azure/bicep-registry-modules/blob/main/avm/ptn/ai-ml/ai-foundry/CHANGELOG.md).

## 0.3.0

### Changes

- Added Capability Hosts support
- Added Foundry Account network injection via Agents subnet
- Updated Foundry Storage Account Connection to be of type `AzureStorageAccount` instead of `AzureBlob`
- Added RBAC for the Foundry Project Identity to associated resources and their data plane
- Added input parameter `aiFoundryConfiguration.createCapabilityHosts`
- Added input parameter `aiFoundryConfiguration.networking.agentServiceSubnetResourceId`
- Set Foundry Account `disableLocalAuth` to false to support Capability Hosts
- Set Foundry Account `networkAcls.defaultAction` to 'Allow' to support Capability Hosts
- Enabled custom notes for locks.
- Updated ReadMe with AzAdvertizer reference

### Breaking Changes

- Moved input parameter `sku` to `aiFoundryConfiguration.sku`
- Renamed all input parameters ending in `subnetId` to `subnetResourceId`
- Renamed all input parameters ending in `privateDnsZoneId` to `privateDnsZoneResourceId`
- Removed input parameter `storageAccountConfiguration.containerName`

## 0.2.0

### Changes

- Added support to bring your own associated resources. Associated resource configuration input parameters include an `existingResourceId` that, when supplied, will reference and connect the existing resource rather than creating a new resource.
- Added support to provide optional `name`, `privateDnsZoneId`, and `roleAssignments` per associated resource.
- Added support to provide optional `containerName` and `blobPrivateDnsZoneId` for the Storage Account
- Added support to provide optional `displayName`, `description`, and `location` for AI Foundry Project
- Added support to provide optional `accountName`, `location`, `allowProjectManagement`, `rollAssignments` and private DNS zone resource Ids for the AI Foundry Account
- Added support to provide existing networking resources to establish private networking
- Added AI Foundry Project role assignments to associated resources
- Added input parameter `baseUniqueName` for optional string used for naming globally unique resources
- Added input parameter `lock` for the AI Foundry / Cognitive Services account
- Added input parameter `includeAssociatedResources`
- Added input parameter `sku` for the SKU of the AI Foundry / Cognitive Services account
- Added input parameter `privateEndpointSubnetId`
- Added input parameter `aiFoundryConfiguration`
- Added input parameter `keyVaultConfiguration`
- Added input parameter `aiSearchConfiguration`
- Added input parameter `storageAccountConfiguration`
- Added input parameter `cosmosDbConfiguration`
- Updated input parameter `tags` to use direct `resourceInput` type over `object`
- Removed `azd-env-name` tag from being added to provided `tags`
- Added tests for `associated-resources`, `bring-your-own`, and `max`
- Various fixes, documentation, and refactoring updates

### Breaking Changes

- Renamed input parameter `name` to `baseName`
- Removed input parameter `aiFoundryType`
- Removed input parameter `userObjectId`
- Removed input parameter `vmSize`
- Removed input parameter `vmAdminPasswordOrKey`
- Removed input parameter `vmAdminUsername`
- Removed input parameter `cosmosDatabases`
- Removed input parameter `allowedIpAddress`
- Removed input parameter `logAnalyticsWorkspaceResourceId`
- Removed input parameter `enableVmMonitoring`
- Removed input parameter `contentSafetyEnabled`
- Removed input parameter `networkAcls`
- Removed `azure` prefix from output parameters
- Removed output parameter `azureContainerRegistryName`
- Removed output parameter `azureBastionName`
- Removed output parameter `azureVmResourceId`
- Removed output parameter `azureVmUsername`
- Removed output parameter `azureVirtualNetworkName`
- Removed output parameter `azureVirtualNetworkSubnetName`
- Removed output parameter `azureVmUsername`
- Removed logic that would create a Virtual Network and associated networking resrouces. This includes a `virtual network`, `bastion`, `private DNS zones`, and `virtual machine`. Enable private networking using the `privateEndpointSubnetId` and `privateDnsZoneId` per resource configuration
- Removed logic that would create an Azure Container Registry
- Removed logic that would create a Cognitive Services account type of Content Safety
- Removed logic that would assign various RBAC roles to the supplied (now removed) `userObjectId`

## 0.1.1

### Changes

- Regenerate main.json with latest bicep version 0.36.177.2456

### Breaking Changes

- None

## 0.1.0

### Changes

- Initial Release

### Breaking Changes

- None
