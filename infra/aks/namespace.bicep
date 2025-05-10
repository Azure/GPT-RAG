@secure()
param kubeConfig string

param name string

extension kubernetes with {
  namespace: 'default'
  kubeConfig: kubeConfig
}

resource ns 'core/Namespace@v1' = {
  metadata: {
    name: name
  }
}
