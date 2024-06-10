param name string
param resourceGroupName string

resource AppServiceEnvironment 'Microsoft.Web/hostingEnvironments@2021-02-01' existing  = {
  scope: resourceGroup(resourceGroupName)
  name: name
}

output id string = AppServiceEnvironment.id
output name string = AppServiceEnvironment.name
