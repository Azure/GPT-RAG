@description('List of key/value pairs to create')
param keyValues array

@description('Name of the existing App Configuration store')
param storeName string

resource store 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
  name: storeName
}

resource kvResources 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [
  for kv in keyValues: {
    parent: store
    name: empty(kv.label) ? kv.name : '${kv.name}$${kv.label}' 
    properties: {
      value:        kv.value
      contentType:  kv.contentType
    }
  }
]


