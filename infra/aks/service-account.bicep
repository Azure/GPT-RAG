@secure()
param kubeConfig string

param clientId string
param name string
param namespace string

//https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet
//https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource coreServiceAccount_SERVICE_ACCOUNT_NAME 'core/ServiceAccount@v1' = {
  metadata: {
    annotations: {
      'azure.workload.identity/client-id': clientId
      'azure.workload.identity/tenant-id': subscription().tenantId
      'azure.workload.identity/service-account-token-expiration': '3600'  //can go to a maximum of 86400
    }
    labels: {
      'azure.workload.identity/use': 'true'
    }
    name: name
    namespace: namespace
  }
}
