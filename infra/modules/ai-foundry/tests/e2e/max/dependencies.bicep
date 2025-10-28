@description('Workload / application name prefix.')
param workloadName string

@description('The location to deploy the resources into.')
param location string

@description('Optional. Tags of the resources.')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: 'vnet-${workloadName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      // NOTE: Foundry currently requires an address space of 192.168.0.0/16 for agent vnet integration
      addressPrefixes: ['192.168.0.0/16']
    }
    subnets: [
      {
        name: 'agents'
        properties: {
          addressPrefix: '192.168.0.0/23'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '192.168.2.0/23'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

module blobDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.storage.blob.${workloadName}', 64)
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module documentsDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.cosmos.documents.${workloadName}', 64)
  params: {
    name: 'privatelink.documents.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module searchDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.search.${workloadName}', 64)
  params: {
    name: 'privatelink.search.windows.net'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module keyVaultDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.keyvault.${workloadName}', 64)
  params: {
    name: 'privatelink.${toLower(environment().name) == 'azureusgovernment' ? 'vaultcore.usgovcloudapi.net' : 'vaultcore.azure.net'}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module openaiDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.openai.${workloadName}', 64)
  params: {
    name: 'privatelink.openai.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module servicesAiDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.services.ai.${workloadName}', 64)
  params: {
    name: 'privatelink.services.ai.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

module cognitiveServicesDnsZone '../../shared/privateDnsZone.bicep' = {
  name: take('module.dns.cognitive.services.${workloadName}', 64)
  params: {
    name: 'privatelink.cognitiveservices.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: vnet.id
    tags: tags
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-sample-${workloadName}'
  location: location
  tags: tags
}

output vnetResourceId string = vnet.id

output subnetPrivateEndpointsResourceId string = first(filter(
  vnet.properties.subnets,
  s => s.name == 'private-endpoints'
)).?id!
output subnetAgentResourceId string = first(filter(vnet.properties.subnets, s => s.name == 'agents')).?id!

output blobDnsZoneResourceId string = blobDnsZone.outputs.resourceId
output documentsDnsZoneResourceId string = documentsDnsZone.outputs.resourceId
output searchDnsZoneResourceId string = searchDnsZone.outputs.resourceId
output keyVaultDnsZoneResourceId string = keyVaultDnsZone.outputs.resourceId
output openaiDnsZoneResourceId string = openaiDnsZone.outputs.resourceId
output servicesAiDnsZoneResourceId string = servicesAiDnsZone.outputs.resourceId
output cognitiveServicesDnsZoneResourceId string = cognitiveServicesDnsZone.outputs.resourceId

output managedIdentityResourceId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
