param name string
param location string = resourceGroup().location
param tags object = {}

@description('The type of system topic to create (e.g., Microsoft.Storage.StorageAccounts)')
param topicType string

@description('The resource ID of the source resource (e.g., storage account)')
param source string

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: name
  location: location
  tags: tags
  properties: {
    topicType: topicType
    source: source
  }
}

output name string = systemTopic.name
output id string = systemTopic.id