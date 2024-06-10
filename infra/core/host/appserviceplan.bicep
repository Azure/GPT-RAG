param name string
param location string = resourceGroup().location
param tags object = {}

param appServerPlanReuse bool
param existingAppServerPlanResourceGroupName string
param existingAppServerPlanName string

param kind string = ''
param reserved bool = true
param sku object

resource existingAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing  = if (appServerPlanReuse) {
  scope: resourceGroup(existingAppServerPlanResourceGroupName)
  name: existingAppServerPlanName
}


resource newAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = if (!appServerPlanReuse) {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
  }
}

output id string = appServerPlanReuse ? existingAppServicePlan.id: newAppServicePlan.id
output name string = appServerPlanReuse ? existingAppServicePlan.name: newAppServicePlan.name
