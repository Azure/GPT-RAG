targetScope = 'resourceGroup'

param vnetName string
param location string
param aiSubnetName string
param acaSubnetName string
param aksSubnetName string
param appIntSubnetName string
param appServicesSubnetName string
param databaseSubnetName string
param bastionSubnetName string = 'AzureBastionSubnet'
param vnetAddress string = '10.0.0.0/23'
param vnetAddressAks string = '10.220.128.0/20'
param aiSubnetPrefix string = '10.0.0.0/26'
param acaSubnetPrefix string = '10.0.1.64/26'
param aksSubnetPrefix string = '10.220.132.0/22'
param appIntSubnetPrefix string = '10.0.0.128/26'
param appServicesSubnetPrefix string = '10.0.0.192/26'
param databaseSubnetPrefix string = '10.0.1.0/26'
param bastionSubnetPrefix string = '10.0.0.64/26'
param appServicePlanId string
param appServicePlanName string
param tags object = {}
param vnetReuse bool
param existingVnetResourceGroupName string

// Parameters for NSG names
param aiNsgName string = ''
param acaNsgName string = ''
param aksNsgName string = ''
param appIntNsgName string = ''
param appServicesNsgName string = ''
param databaseNsgName string = ''
param bastionNsgName string = ''

var abbrs = loadJsonContent('../../abbreviations.json')
var roles = loadJsonContent('../../roles.json')

var _aiNsgName = !empty(aiNsgName) ? aiNsgName : '${abbrs.networking.networkSecurityGroup}ai'
var _acaNsgName = !empty(acaNsgName) ? acaNsgName : '${abbrs.networking.networkSecurityGroup}aca'
var _aksNsgName = !empty(aksNsgName) ? aksNsgName : '${abbrs.networking.networkSecurityGroup}aks'
var _appIntNsgName = !empty(appIntNsgName) ? appIntNsgName : '${abbrs.networking.networkSecurityGroup}appInt'
var _appServicesNsgName = !empty(appServicesNsgName) ? appServicesNsgName : '${abbrs.networking.networkSecurityGroup}appServices'
var _databaseNsgName = !empty(databaseNsgName) ? databaseNsgName : '${abbrs.networking.networkSecurityGroup}db'
var _bastionNsgName = !empty(bastionNsgName) ? bastionNsgName : '${abbrs.networking.networkSecurityGroup}bastion'

// Network Security Groups
module aiNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _aiNsgName
  params: {
    location: location
    name: _aiNsgName
    tags: tags
    securityRules : []
  }
}

module acaNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _acaNsgName
  params: {
    location: location
    name: _acaNsgName
    tags: tags
    securityRules : []
  }
}

module aksNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _aksNsgName
  params: {
    location: location
    name: _aksNsgName
    tags: tags
    securityRules : []
  }
}

module appIntNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _appIntNsgName
  params: {
    location: location
    name: _appIntNsgName
    tags: tags
    securityRules : []
  }
}

module appServicesNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _appServicesNsgName
  params: {
    location: location
    name: _appServicesNsgName
    tags: tags
    securityRules : []
  }
}

module databaseNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _databaseNsgName
  params: {
    location: location
    name: _databaseNsgName
    tags: tags
    securityRules : []
  }
}

module bastionNsg './security-group.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: _bastionNsgName
  params: {
    location: location
    name: _bastionNsgName
    tags: tags
    securityRules : [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowLoadBalancerInbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

var subnets = [
  {
    name: aiSubnetName
    properties: {
      addressPrefix: aiSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: aiNsg.outputs.id
      }
    }
  }
  {
    name: acaSubnetName
    properties: {
      addressPrefix: acaSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: acaNsg.outputs.id
      }
    }
  }
  {
    name: aksSubnetName
    properties: {
      addressPrefix: aksSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: aksNsg.outputs.id
      }
    }
  }
  {
    name: appServicesSubnetName
    properties: {
      addressPrefix: appServicesSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: appServicesNsg.outputs.id
      }
    }
  }
  {
    name: databaseSubnetName
    properties: {
      addressPrefix: databaseSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: databaseNsg.outputs.id
      }
    }
  }
  {
    name: bastionSubnetName 
    properties: {
      addressPrefix: bastionSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: bastionNsg.outputs.id
      }
    }
  }
  {
    name: appIntSubnetName
    properties: {
      addressPrefix: appIntSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      delegations: [
        {
          id: appServicePlanId
          name: appServicePlanName
          properties: {
            serviceName: 'Microsoft.Web/serverFarms'
          }
        }
      ]
      networkSecurityGroup: {
        id: appIntNsg.outputs.id
      }
    }
  }
]

module vnet './vnet_core.bicep' = {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: vnetName
  params : {
    name : vnetName
    location: location
    tags: tags
    addressPrefixes: [
      vnetAddress
      vnetAddressAks
    ]
    subnets: subnets
  }
}

output name string = vnet.outputs.name
output id string = vnet.outputs.id
output aiSubId string = vnet.outputs.subnets[0].id
output acaSubId string = vnet.outputs.subnets[1].id
output aksSubId string = vnet.outputs.subnets[2].id
output appServicesSubId string = vnet.outputs.subnets[3].id
output databaseSubId string = vnet.outputs.subnets[4].id
output bastionSubId string = vnet.outputs.subnets[5].id
output appIntSubId string = vnet.outputs.subnets[6].id
