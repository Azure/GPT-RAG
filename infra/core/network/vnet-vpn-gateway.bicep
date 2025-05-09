param vnetName string
param location string = resourceGroup().location
param tags object = {}

param gatewayName string = 'vnetGateway'
param gatewayPublicIPName string = 'vnetGatewayPublicIP'

param vnetAddressPrefix string = '10.0.0.0/23'
param gatewaySubPrefix string = '10.0.2.0/26'

@description('The SKU of the Gateway. This must be either Standard or HighPerformance to work with OpenVPN')
@allowed([
  'Standard'
  'HighPerformance'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw4'
  'VpnGw5'
])
param gatewaySku string = 'VpnGw1'

@description('Route based (Dynamic Gateway) or Policy based (Static Gateway)')
@allowed([
  'RouteBased'
  'PolicyBased'
])
param vpnType string = 'RouteBased'

@description('The IP address range from which VPN clients will receive an IP address when connected. Range specified must not overlap with on-premise network')
param vpnClientAddressPool string = '172.16.0.0/24'

var audienceMap = {
  AzureCloud: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
  AzureUSGovernment: '51bb15d4-3a4f-4ebf-9dca-40096fe32426'
  AzureGermanCloud: '538ee9e6-310a-468d-afef-ea97365856a9'
  AzureChinaCloud: '49f817b6-84ae-4cc0-928c-73f27289b3aa'
}

var tenantId = subscription().tenantId
var cloud = environment().name
var audience = audienceMap[cloud]
var tenant = uri(environment().authentication.loginEndpoint, tenantId)
var issuer = 'https://sts.windows.net/${tenantId}/'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
  scope: resourceGroup()
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'GatewaySubnet'
  parent: virtualNetwork
  properties:{
    addressPrefix: gatewaySubPrefix
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: gatewayPublicIPName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnet.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    gatewayType: 'Vpn'
    vpnType: vpnType
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
      ]
      aadTenant: tenant
      aadAudience: audience
      aadIssuer: issuer
    }
    customRoutes: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

output name string = vpnGateway.name
output id string = vpnGateway.id
output publicIp string = publicIp.properties.ipAddress
