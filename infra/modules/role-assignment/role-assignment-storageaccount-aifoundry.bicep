@description('Name of the Storage Account')
param storageAccountName string

@description('Object ID of the principal to assign')
param principalId        string

@description('Workspace Id of the AI Project')
param workspaceId        string

@description('Role definition GUID or name')
param roleDefinition     string

// Reference existing Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Build the condition string using the workspaceId
var conditionStr= '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${workspaceId}\' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase \'*-azureml-agent\'))'

// Assign the role with condition
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name:  guid(storage.id, principalId, roleDef.id, workspaceId)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
    conditionVersion: '2.0'
    condition:        conditionStr
  }
}



