param name string
param systemTopicName string

@description('The resource ID of the Function App')
param functionAppId string

@description('The name of the specific function to target')
param functionName string = 'EventGridTrigger'

@description('Array of event types to subscribe to')
param eventTypes array = ['Microsoft.Storage.BlobCreated', 'Microsoft.Storage.BlobDeleted']

@description('Subject filter - events must begin with this value')
param subjectBeginsWith string = ''

@description('Array of file extensions to filter for')
param fileExtensions array = ['.xlsx', '.xls', '.csv']

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' existing = {
  name: systemTopicName
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: systemTopic
  name: name
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/${functionName}'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: eventTypes
      subjectBeginsWith: subjectBeginsWith
      advancedFilters: [
        {
          operatorType: 'StringEndsWith'
          key: 'Subject'
          values: fileExtensions
        }
      ]
    }
  }
}

output name string = eventSubscription.name
output id string = eventSubscription.id