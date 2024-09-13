param vnetName string
param location string
param vnetAddress string = '10.0.0.0/16'
param aiSubnetName string
param appIntSubnetName string
param appServicesSubnetName string
param databaseSubnetName string
param bastionSubnetName string
param aiSubnetPrefix string = '10.0.1.0/24'
param appIntSubnetPrefix string = '10.0.2.0/24'
param appServicesSubnetPrefix string = '10.0.3.0/24'
param databaseSubnetPrefix string = '10.0.4.0/24'
param bastionSubnetPrefix string = '10.0.5.0/24'
param appServicePlanId string
param appServicePlanName string
param tags object = {}
param vnetReuse bool
param existingVnetResourceGroupName string

// Parameters for NSG names
param aiNsgName string = 'ai-nsg'
param appIntNsgName string = 'appInt-nsg'
param appServicesNsgName string = 'appServices-nsg'
param databaseNsgName string = 'database-nsg'
param bastionNsgName string = 'bastion-nsg'

// Network Security Groups
resource aiNsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: aiNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appIntNsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: appIntNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appServicesNsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: appServicesNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource databaseNsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: databaseNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: bastionNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowInternetInbound443'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowInternetOutbound443'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowInternetOutbound3389'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// Virtual Network and Subnets
resource existingVnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = if (vnetReuse) {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: vnetName
}

resource newVnet 'Microsoft.Network/virtualNetworks@2020-11-01' = if (!vnetReuse) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddress
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
output appServicesSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appServicesSubnetName) : newVnet.properties.subnets[1].id
output databaseSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, databaseSubnetName) : newVnet.properties.subnets[2].id
output bastionSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName) : newVnet.properties.subnets[3].id
output appIntSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appIntSubnetName) : newVnet.properties.subnets[4].id
