param actionGroupId string
param alerts array
param metricNamespace string
param nameSuffix string
param serviceId string
param tags object

/*
  This resource block creates a metric alert for a resource.
  It iterates over the 'alerts' array and creates a metric alert for each alert object.
  The alert properties are defined based on the values provided in the alert object.
*/
resource alert 'Microsoft.Insights/metricAlerts@2018-03-01' = [for alert in alerts: {
  name: 'alert-${alert.name}-${nameSuffix}'
  location: 'global'
  tags: tags
  properties: {
    autoMitigate: true
    description: alert.description
    enabled: true
    evaluationFrequency: alert.evaluationFrequency
    scopes: [ serviceId ]
    severity: alert.severity
    windowSize: alert.windowSize

    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {}
      }
    ]

    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          metricName: alert.metricName
          metricNamespace: metricNamespace
          name: alert.name
          operator: alert.operator
          skipMetricValidation: false
          threshold: alert.threshold
          timeAggregation: alert.timeAggregation
        }
      ]
    }
  }
}]
