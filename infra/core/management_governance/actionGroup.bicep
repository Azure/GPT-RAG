param environmentName string
param resourceSuffix string
param project string

var name = 'ag-${resourceSuffix}'

output id string = main.id

resource main 'microsoft.insights/actionGroups@2023-01-01' = {
  location: 'Global'
  name: name

  properties: {
    enabled: true
    groupShortName: 'do-nothing'
  }

  tags: {
    Environment: environmentName
    IaC: 'Bicep'
    Project: project
    Purpose: 'DevOps'
  }
}
