@secure()
param kubeConfig string

param name string
param namespace string = 'default'
param path string = '/'
param pathType string = 'Prefix'
param port int = 80
param ingressClassName string = 'nginx'
param resourceToken string

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

param annotations object = {
    'nginx.ingress.kubernetes.io/rewrite-target': '/$1'
    'nginx.ingress.kubernetes.io/use-regex': 'true'
    'nginx.ingress.kubernetes.io/proxy-connect-timeout': '3600'
    'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
    'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600'
}

resource networkingK8sIoIngress_frontend 'networking.k8s.io/Ingress@v1' = {
  metadata: {
    name: name
    annotations: annotations
  }
  spec: {
    ingressClassName: ingressClassName
    tls: [
      {
        hosts: [
          '${name}.${resourceToken}.com'
        ]
        //secretName: '${namespace}-tls'
        secretName: 'keyvault-${name}'
      }
    ]
    rules: [
      {
        host: '${name}.${resourceToken}.com'
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
