import { roleAssignmentInfo } from '../security/managed-identity.bicep'

param name string = ''

@description('Role assignments to create for the Resource Group.')
param roleAssignments roleAssignmentInfo[] = []

param timestamp string = utcNow()

/*
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleAssignment in roleAssignments: {
    name: guid(resourceGroup().id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    scope: resourceGroup()
    properties: {
      principalId: roleAssignment.principalId
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalType: roleAssignment.principalType
    }
  }
]
*/

module roleAssignment './resource-role-assignment.json' = {
  name: 'roleAssignment-${name}-${timestamp}'
  params: {
    roleAssignments: roleAssignments
  }
}
