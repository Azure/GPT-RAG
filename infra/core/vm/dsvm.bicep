param location string
param name string
param tags object = {}
param aiSubId string
param bastionSubId string
param resourceGroupName string
@secure()
param vmUserPassword string
param vmUserName string
param authenticationType string = 'password' //'sshPublicKey'

var osDiskType = 'StandardSSD_LRS'
var vmSize = {
  'CPU-4GB': 'Standard_B2s'
  'CPU-7GB': 'Standard_D2s_v3'
  'CPU-8GB': 'Standard_D2s_v3'
  'CPU-14GB': 'Standard_D4s_v3'
  'CPU-16GB': 'Standard_D4s_v3'
  'GPU-56GB': 'Standard_NC6_Promo'
}
var publicIpName = '${name}PublicIp'
var nicName = '${name}Nic'
var diskName = '${name}Disk'
var bastionName = '${name}Bastion'

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${vmUserName}/.ssh/authorized_keys'
        keyData: vmUserPassword
      }
    ]
  }
}

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
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize['CPU-8GB']
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'winserver-2019'
        version: 'latest'
      }
      osDisk: {
        name: diskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }      
    }
    osProfile: {
      computerName: 'gptragvm'
      adminUsername: vmUserName
      adminPassword: vmUserPassword
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
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

output vmPrincipalId string = virtualMachine.identity.principalId

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


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroupName, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: virtualMachine.identity.principalId
  }
}
