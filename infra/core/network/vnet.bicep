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
resource aiNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _aiNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource acaNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _acaNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource aksNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _aksNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appIntNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _appIntNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appServicesNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _appServicesNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource databaseNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _databaseNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: _bastionNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
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

// Virtual Network and Subnets
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (vnetReuse) {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: vnetName
}

resource newVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!vnetReuse) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddress
        vnetAddressAks
      ]
    }
    subnets: [
      {
        name: aiSubnetName
        properties: {
          addressPrefix: aiSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: aiNsg.id
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
            id: acaNsg.id
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
            id: aksNsg.id
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
            id: appServicesNsg.id
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
            id: databaseNsg.id
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
            id: bastionNsg.id
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
            id: appIntNsg.id
          }
        }
      }
    ]
  }
}

output name string = vnetReuse ? existingVnet.name : newVnet.name
output id string = vnetReuse ? existingVnet.id : newVnet.id
output aiSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, aiSubnetName) : newVnet.properties.subnets[0].id
output acaSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, aiSubnetName) : newVnet.properties.subnets[1].id
output aksSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, aiSubnetName) : newVnet.properties.subnets[2].id
output appServicesSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appServicesSubnetName) : newVnet.properties.subnets[3].id
output databaseSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, databaseSubnetName) : newVnet.properties.subnets[4].id
output bastionSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName) : newVnet.properties.subnets[5].id
output appIntSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appIntSubnetName) : newVnet.properties.subnets[6].id
