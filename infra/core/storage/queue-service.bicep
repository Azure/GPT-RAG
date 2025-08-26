@description('Existing Storage account name')
param storageAccountName string

@description('Queue name to create')
param queueName string = 'report-jobs'

@description('Optional per-queue metadata')
param metadata object = {}

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  name: 'default'
  parent: sa
  properties: {
    // Optional: add CORS/metrics if needed
    // cors: { corsRules: [ { allowedOrigins: ['*'], allowedMethods: ['GET','HEAD','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['*'], exposedHeaders: ['*'], maxAgeInSeconds: 200 } ] }
  }
}

resource queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = {
  name: queueName
  parent: queueService
  properties: {
    metadata: metadata
  }
}

output queueServiceId string = queueService.id
output queueId string = queue.id
output queueNameOut string = queue.name
