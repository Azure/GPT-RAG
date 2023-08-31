param location string
param name string
param tags object = {}
param vnetName string 
param subnetName string
param bastionsubnetName string

// resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
//   name: vnetName
// }

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: subnetName
}

resource bastionsubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: bastionsubnetName
}


resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: 'testvmPublicIp'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-05-01' = {
  name: 'testvmBastion'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: bastionsubnet.id 
          }
          publicIPAddress: {
            id: bastionPublicIp.id // use a public IP address for the bastion
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: 'testvmNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
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
  dependsOn: [
    nic
  ]
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
        name: 'testvmDisk'
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: 'testvm'
      adminUsername: 'gptrag'
      adminPassword: 'P@ssw0rd123456'
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
