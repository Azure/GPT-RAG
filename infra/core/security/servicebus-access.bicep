@description('Object (principal) ID of the managed identity to grant access to')
param principalId string

@description('Service Bus namespace name (existing)')
param namespaceName string

@description('Access level to grant on the namespace')
@allowed([
  'Sender' // Azure Service Bus Data Sender
  'Receiver' // Azure Service Bus Data Receiver
])
param access string = 'Sender'

// Built-in role GUIDs
var ROLE_SERVICEBUS_SENDER = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
var ROLE_SERVICEBUS_RECEIVER = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

// Pick the role ID based on requested access
var roleGuid = access == 'Sender' ? ROLE_SERVICEBUS_SENDER : ROLE_SERVICEBUS_RECEIVER

// Existing namespace (for scope)
resource sbNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: toLower(namespaceName)
}

// RBAC assignment at the namespace scope
resource serviceBusRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sbNamespace.id, principalId, roleGuid)
  scope: sbNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output assignedRoleGuid string = roleGuid
output scopeId string = sbNamespace.id
