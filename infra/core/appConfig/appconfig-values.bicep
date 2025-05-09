
/** Inputs **/
@description('App Configuration name')
param name string

@description('Keys to add to App Configuration')
param appSettings array

@description('Secret Keys to add to App Configuration')
param secureAppSettings array

var abbrs = loadJsonContent('../../abbreviations.json')
var roles = loadJsonContent('../../roles.json')

resource main 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
  name: name
}

resource keyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (config, i) in appSettings: {
  parent: main
  name: config.name
  properties: {
    contentType: ''
    tags: {}
    value: config.value
  }
}
]

resource secureKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (config, i) in secureAppSettings: {
  parent: main
  name: config.name
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    tags: {}
    value: config.value
  }
}
]
