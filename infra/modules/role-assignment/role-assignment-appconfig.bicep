@description('Name of the App Configuration resource')
param appConfigName   string

@description('Object ID of the principal to assign')
param principalId     string

@description('Role definition GUID or name')
param roleDefinition  string

// Reference existing App Configuration
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2021-03-01-preview' existing = {
  name: appConfigName
}

// Lookup the roleDefinition exactly as given
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfig
  name:  guid(appConfig.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
