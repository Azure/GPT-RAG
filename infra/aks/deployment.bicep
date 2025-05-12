@secure()
param kubeConfig string

param prefix string
param name string
param namespace string

param image string
param env array = []
param port int = 80
param targetPort int = 8000
param serviceType string = 'LoadBalancer'
param useLoadBalancer bool = false

var fullName = '${prefix}-${name}'

extension kubernetes with {
  namespace: namespace
  kubeConfig: kubeConfig
}

resource ns 'core/Namespace@v1' = {
  metadata: {
    name: namespace
  }
}

resource appsDeployment_gptRagFrontend 'apps/Deployment@v1' = {
  metadata: {
    name: fullName
    labels: {
      app: fullName
    }
    namespace: namespace
  }
  spec: {
    replicas: 1
    template: {
      metadata: {
        name: fullName
        labels: {
          app: fullName
          'azure.workload.identity/use' : 'true'
        }
        annotations: {
          //'azure.workload.identity/use' : 'true'
        }
      }
      spec: {
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        serviceAccountName: '${name}-service-account'
        containers: [
          {
            name: fullName
            image: image
            imagePullPolicy: 'Always'
            env: env
            ports: [
              {
                containerPort: 80
              }
            ]
          }
        ]
      }
    }
    selector: {
      matchLabels: {
        app: fullName
      }
    }
  }
}

resource secret 'core/Secret@v1' = {
  metadata: {
    name: '${name}-secret'
    namespace: namespace
  }
  type: 'Opaque'
  data: {
    secret: 'dGVzdA=='
  }
}

resource coreServiceExt 'core/Service@v1' = if (useLoadBalancer) {
  metadata: {
    name: '${name}-ext'
    namespace: namespace
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        name: 'http'
        port: port
        targetPort: targetPort
      }
    ]
    selector: {
      app: fullName
    }
  }
}

resource coreServiceInt 'core/Service@v1' = {
  metadata: {
    name: name
    namespace: namespace
  }
  spec: {
    type: 'ClusterIP'
    ports: [
      {
        name: 'http'
        port: port
        targetPort: targetPort
      }
    ]
    selector: {
      app: fullName
    }
  }
}
