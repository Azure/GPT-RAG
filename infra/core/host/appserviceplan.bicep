param name string
param location string = resourceGroup().location
param tags object = {}

param appServicePlanReuse bool
param existingAppServicePlanResourceGroupName string

param kind string = ''
param reserved bool = true
param sku object

resource existingAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing  = if (appServicePlanReuse) {
  scope: resourceGroup(existingAppServicePlanResourceGroupName)
  name: name
}


resource newAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = if (!appServicePlanReuse) {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
  }
}

output id string = appServicePlanReuse ? existingAppServicePlan.id: newAppServicePlan.id
output name string = appServicePlanReuse ? existingAppServicePlan.name: newAppServicePlan.name
