param location string
param name string
param tags object = {}
param securityRules array = []

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

output name string = nsg.name
output id string = nsg.id
output location string = nsg.location
