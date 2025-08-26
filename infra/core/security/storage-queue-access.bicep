@description('Object (principal) ID of the managed identity to grant access to')
param principalId string

@description('Existing Storage account name')
param storageAccountName string

@description('Access level to grant on the storage account (queue data roles)')
@allowed([
  // Full queue data R/W/D access
  'DataContributor'
  // Add-only (enqueue) — useful for strict least-privilege senders
  'DataMessageSender'
  // Peek/dequeue/delete messages (processor)
  'DataMessageProcessor'
  // Read/list queues and messages
  'DataReader'
])
param access string = 'DataContributor'

// Built-in role GUIDs (Azure RBAC)
var ROLE_STORAGE_QUEUE_DATA_CONTRIBUTOR = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var ROLE_STORAGE_QUEUE_DATA_MESSAGE_SENDER = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
var ROLE_STORAGE_QUEUE_DATA_MESSAGE_PROCESSOR = '8a0f0c08-91a1-4084-bc3d-661d67233fed'
var ROLE_STORAGE_QUEUE_DATA_READER = '19e7f393-937e-4f77-808e-94535e297925'

// Map selected access to the correct role GUID
var roleGuid = access == 'DataContributor'
  ? ROLE_STORAGE_QUEUE_DATA_CONTRIBUTOR
  : access == 'DataMessageSender'
      ? ROLE_STORAGE_QUEUE_DATA_MESSAGE_SENDER
      : access == 'DataMessageProcessor' ? ROLE_STORAGE_QUEUE_DATA_MESSAGE_PROCESSOR : ROLE_STORAGE_QUEUE_DATA_READER

// Existing storage account (scope target)
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: toLower(storageAccountName)
}

// RBAC assignment at the storage account scope
resource storageQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, principalId, roleGuid)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output assignedRoleGuid string = roleGuid
output scopeId string = sa.id
