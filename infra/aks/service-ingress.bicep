@secure()
param kubeConfig string

param name string
param namespace string = 'default'
param path string = '/'
param pathType string = 'ImplementationSpecific'
param port int = 80
param ingressClassName string = 'nginx'

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource coreService_frontend 'core/Service@v1' = {
  metadata: {
    name: name
  }
  spec: {
    type: 'ExternalName'
    externalName: '${name}.${namespace}.svc.cluster.local'
  }
}

resource networkingK8sIoIngress_frontend 'networking.k8s.io/Ingress@v1' = {
  metadata: {
    name: name
    annotations: {
      'nginx.ingress.kubernetes.io/rewrite-target': '/$1'
      'nginx.ingress.kubernetes.io/use-regex': 'true'
      'nginx.ingress.kubernetes.io/proxy-connect-timeout': '3600'
      'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
      'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600'
    }
  }
  spec: {
    ingressClassName: ingressClassName
    tls: [
      {
        hosts: [
          name
        ]
        secretName: '${namespace}-tls'
      }
    ]
    rules: [
      {
        host: name
        http: {
          paths: [
            {
              path: path
              pathType: pathType
              backend: {
                service: {
                  name: name
                  port: {
                    number: port
                  }
                }
              }
            }
          ]
        }
      }
    ]
  }
}
