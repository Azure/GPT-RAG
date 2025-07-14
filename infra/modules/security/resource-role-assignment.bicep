type roleAssignmentInfo = {
  @description('Role definition ID for the RBAC role to assign to the identity.')
  roleDefinitionId: string
  @description('Principal ID of the identity to assign to.')
  principalId: string
  @description('Resource ID to assing too.')
  resourceId: string
  @description('Type of principal to assign the role to.')
  principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
}


param name string = ''

@description('Role assignments to create.')
param roleAssignments roleAssignmentInfo[] = []

module roleAssignment './resource-role-assignment.json' = {
  name: 'role-${name}'
  params: {
    roleAssignments: roleAssignments
  }
}
