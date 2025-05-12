@secure()
param kubeConfig string

param name string
param namespace string = 'default'
param data array

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource coreSecret_secretName 'core/Secret@v1' = {
  metadata: {
    name: 'secret-${name}'
    labels: {
      app: name
    }
  }
  type: 'Opaque'
  data: data
}
