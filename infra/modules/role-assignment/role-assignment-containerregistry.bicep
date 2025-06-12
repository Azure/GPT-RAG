// modules/role-assignment-containerregistry.bicep
@description('Name of the Container Registry')
param registryName      string

@description('Object ID of the principal to assign')
param principalId       string

@description('Role definition GUID or name')
param roleDefinition    string

// Reference existing Container Registry
resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: registryName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name:  guid(registry.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
