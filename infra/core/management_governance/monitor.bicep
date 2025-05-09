param name string
param location string = resourceGroup().location

resource monitor 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: name
  location: location
}

output id string = monitor.id
output name string = monitor.name
