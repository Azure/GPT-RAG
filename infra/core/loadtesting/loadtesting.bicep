param name string
param location string = resourceGroup().location
param tags object = {}

// Define the resource for Azure Load Testing
resource loadTestingService 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: name
  tags: tags  
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

output id string = loadTestingService.identity.principalId
output name string = loadTestingService.name
