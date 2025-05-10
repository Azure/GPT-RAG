@secure()
param kubeConfig string

param name string
param namespace string = 'default'
param path string = '/'
param pathType string = 'ImplementationSpecific'
param port int = 80
param ingressClassName string = 'nginx'
param annotations object = {
  'nginx.ingress.kubernetes.io/rewrite-target': '/$1'
  'nginx.ingress.kubernetes.io/use-regex': 'true'
  'nginx.ingress.kubernetes.io/proxy-connect-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600'
}

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource networkingK8sIoIngress_frontend 'networking.k8s.io/Ingress@v1' = {
  metadata: {
    name: name
    namespace: namespace
    annotations: annotations
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
