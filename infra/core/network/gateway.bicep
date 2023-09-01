param location string
param subnetName string
param gatewayName string = 'vpngateway'
param vpnType string = 'RouteBased'
param vpnClientAddressPoolPrefix string
param tags object = {}


var tenantId = subscription().tenantId
var audienceMap = {
  AzureCloud: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
  AzureUSGovernment: '51bb15d4-3a4f-4ebf-9dca-40096fe32426'
  AzureGermanCloud: '538ee9e6-310a-468d-afef-ea97365856a9'
  AzureChinaCloud: '49f817b6-84ae-4cc0-928c-73f27289b3aa'
}
var cloud = environment().name
var audience = audienceMap[cloud]
var tenant = uri(environment().authentication.loginEndpoint, tenantId)
var issuer = 'https://sts.windows.net/${tenantId}/'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${gatewayName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: subnetName
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-04-01' = {
  name: gatewayName
  location: location
  tags: tags
  properties: {
    vpnType: vpnType
    enablePrivateIpAddress: false
    sku: {
      name: 'VpnGw2'
      tier: 'VpnGw2'
    }
    ipConfigurations: [
      {
        name: 'gwipconfig'
        // id: ''
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    vpnClientConfiguration: {
      aadAudience: audience
      aadIssuer: issuer
      aadTenant: tenant      
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPoolPrefix
        ]
      }
      vpnClientProtocols: ['OpenVPN']
      vpnAuthenticationTypes: ['AAD']
    }
    gatewayType: 'Vpn'
    vpnGatewayGeneration: 'Generation1'    
  }
}
