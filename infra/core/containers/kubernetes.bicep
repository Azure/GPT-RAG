@secure()
param kubeConfig string

extension kubernetes with {
  namespace: 'default'
  kubeConfig: kubeConfig
} as k8s
