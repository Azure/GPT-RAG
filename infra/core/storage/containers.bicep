// Parameters matching your existing style
param storageAccountName string
param containers array = [
  {
    name: 'emails'
    publicAccess: 'None'
  }
  {
    name: 'emails-archived'
    publicAccess: 'None'
  }
  {
    name: 'financial-reports'
    publicAccess: 'None'
  }
  {
    name: 'financial-reports-archived'
    publicAccess: 'None'
  }
]
resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: storage
  properties: {
    cors: {
      corsRules: [
        {
          allowedHeaders: ['*']
          allowedMethods: ['GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS', 'POST', 'PATCH']
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
          ]
          exposedHeaders: ['*']
          maxAgeInSeconds: 1800
        }
        {
          allowedHeaders: ['*']
          allowedMethods: ['GET', 'OPTIONS', 'POST', 'PUT']
          allowedOrigins: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 200
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 3
      allowPermanentDelete: false
    }
  }
  resource container 'containers' = [for container in containers: {
    name: container.name
    properties: {
      publicAccess: container.publicAccess
    }
  }]
}
