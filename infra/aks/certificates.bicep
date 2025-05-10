@secure()
param kubeConfig string

param name string
param namespace string = 'default'
param identityId string
param keyVaultName string

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource secretsStoreCsiXK8sIoSecretProviderClass_gptragCertificates 'secrets-store.csi.x-k8s.io/SecretProviderClass@v1' = {
  metadata: {
    name: '${namespace}-certificates'
  }
  spec: {
    provider: 'azure'
    secretObjects: [
      {
        secretName: '${name}-tls'
        type: 'kubernetes.io/tls'
        data: [
          {
            objectName: name
            key: 'tls.key'
          }
          {
            objectName: name
            key: 'tls.crt'
          }
        ]
      }
    ]
    parameters: {
      keyvaultName: keyVaultName
      tenantId: subscription().tenantId
      usePodIdentity: 'false'
      useVMManagedIdentity: 'true'
      userAssignedIdentityID: identityId
      objects: 'array:\n  - |\n    objectName: ${name}\n    objectType: secret'
    }
  }
}
