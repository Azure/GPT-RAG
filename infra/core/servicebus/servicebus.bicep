@description('Service Bus namespace name')
param namespaceName string

@description('Location')
param location string = resourceGroup().location

@description('Queue name')
param queueName string = 'report-jobs'

@description('Max deliveries before DLQ')
param maxDeliveryCount int = 10

@description('Message TTL (ISO8601, e.g., P1D)')
param defaultMessageTimeToLive string = 'P1D'

@description('Lock duration (ISO8601, e.g., PT60S)')
param lockDuration string = 'PT60S'

@description('Partitioning for throughput')
param enablePartitioning bool = true

param tags object = {}

resource namespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  sku: { name: 'Standard', tier: 'Standard' }
  tags: tags
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: namespace
  name: queueName
  properties: {
    maxDeliveryCount: maxDeliveryCount
    defaultMessageTimeToLive: defaultMessageTimeToLive
    lockDuration: lockDuration
    deadLetteringOnMessageExpiration: true
    enablePartitioning: enablePartitioning
    requiresSession: false
  }
}

output namespaceId string = namespace.id
output namespaceNameOut string = namespace.name
output queueId string = queue.id
