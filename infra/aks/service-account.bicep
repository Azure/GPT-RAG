@secure()
param kubeConfig string

param clientId string
param name string
param namespace string

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource coreServiceAccount_SERVICE_ACCOUNT_NAME 'core/ServiceAccount@v1' = {
  metadata: {
    annotations: {
      'azure.workload.identity/client-id': clientId
      'azure.workload.identity/tenant-id': subscription().tenantId
    }
    name: name
    namespace: namespace
  }
}
