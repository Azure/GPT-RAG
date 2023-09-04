param location string
param name string
param tags object = {}
param aiSubId string
param bastionSubId string
@secure()
param vmUserPassword string
param vmUserName string

var publicIpName = '${name}PublicIp'
var nicName = '${name}Nic'
var diskName = '${name}Disk'
var bastionName = '${name}Bastion'

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: aiSubId
          }  
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: diskName
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: 'gptragvm'
      adminUsername: vmUserName
      adminPassword: vmUserPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-05-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: bastionSubId
          }
          publicIPAddress: {
            id: bastionPublicIp.id // use a public IP address for the bastion
          }
        }
      }
    ]
  }
}
