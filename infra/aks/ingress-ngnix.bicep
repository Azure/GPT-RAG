@secure()
param kubeConfig string

extension kubernetes with {
  namespace: 'default'
  kubeConfig: kubeConfig
}

resource coreNamespace_ingressNginx 'core/Namespace@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
    }
    name: 'ingress-nginx'
  }
}

resource coreServiceAccount_ingressNginx 'core/ServiceAccount@v1' = {
  automountServiceAccountToken: true
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx'
    namespace: 'ingress-nginx'
  }
}

resource coreServiceAccount_ingressNginxAdmission 'core/ServiceAccount@v1' = {
  automountServiceAccountToken: true
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
    namespace: 'ingress-nginx'
  }
}

resource rbacAuthorizationK8sIoRole_ingressNginx 'rbac.authorization.k8s.io/Role@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx'
    namespace: 'ingress-nginx'
  }
  rules: [
    {
      apiGroups: [
        ''
      ]
      resources: [
        'namespaces'
      ]
      verbs: [
        'get'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'configmaps'
        'pods'
        'secrets'
        'endpoints'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'services'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingresses'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingresses/status'
      ]
      verbs: [
        'update'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingressclasses'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'coordination.k8s.io'
      ]
      resourceNames: [
        'ingress-nginx-leader'
      ]
      resources: [
        'leases'
      ]
      verbs: [
        'get'
        'update'
      ]
    }
    {
      apiGroups: [
        'coordination.k8s.io'
      ]
      resources: [
        'leases'
      ]
      verbs: [
        'create'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'events'
      ]
      verbs: [
        'create'
        'patch'
      ]
    }
    {
      apiGroups: [
        'discovery.k8s.io'
      ]
      resources: [
        'endpointslices'
      ]
      verbs: [
        'list'
        'watch'
        'get'
      ]
    }
  ]
}

resource rbacAuthorizationK8sIoRole_ingressNginxAdmission 'rbac.authorization.k8s.io/Role@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
    namespace: 'ingress-nginx'
  }
  rules: [
    {
      apiGroups: [
        ''
      ]
      resources: [
        'secrets'
      ]
      verbs: [
        'get'
        'create'
      ]
    }
  ]
}

resource rbacAuthorizationK8sIoClusterRole_ingressNginx 'rbac.authorization.k8s.io/ClusterRole@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx'
  }
  rules: [
    {
      apiGroups: [
        ''
      ]
      resources: [
        'configmaps'
        'endpoints'
        'nodes'
        'pods'
        'secrets'
        'namespaces'
      ]
      verbs: [
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'coordination.k8s.io'
      ]
      resources: [
        'leases'
      ]
      verbs: [
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'nodes'
      ]
      verbs: [
        'get'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'services'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingresses'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        ''
      ]
      resources: [
        'events'
      ]
      verbs: [
        'create'
        'patch'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingresses/status'
      ]
      verbs: [
        'update'
      ]
    }
    {
      apiGroups: [
        'networking.k8s.io'
      ]
      resources: [
        'ingressclasses'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
    {
      apiGroups: [
        'discovery.k8s.io'
      ]
      resources: [
        'endpointslices'
      ]
      verbs: [
        'list'
        'watch'
        'get'
      ]
    }
  ]
}

resource rbacAuthorizationK8sIoClusterRole_ingressNginxAdmission 'rbac.authorization.k8s.io/ClusterRole@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
  }
  rules: [
    {
      apiGroups: [
        'admissionregistration.k8s.io'
      ]
      resources: [
        'validatingwebhookconfigurations'
      ]
      verbs: [
        'get'
        'update'
      ]
    }
  ]
}

resource rbacAuthorizationK8sIoRoleBinding_ingressNginx 'rbac.authorization.k8s.io/RoleBinding@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx'
    namespace: 'ingress-nginx'
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'Role'
    name: 'ingress-nginx'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'ingress-nginx'
      namespace: 'ingress-nginx'
    }
  ]
}

resource rbacAuthorizationK8sIoRoleBinding_ingressNginxAdmission 'rbac.authorization.k8s.io/RoleBinding@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
    namespace: 'ingress-nginx'
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'Role'
    name: 'ingress-nginx-admission'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'ingress-nginx-admission'
      namespace: 'ingress-nginx'
    }
  ]
}

resource rbacAuthorizationK8sIoClusterRoleBinding_ingressNginx 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx'
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'ClusterRole'
    name: 'ingress-nginx'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'ingress-nginx'
      namespace: 'ingress-nginx'
    }
  ]
}

resource rbacAuthorizationK8sIoClusterRoleBinding_ingressNginxAdmission 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'ClusterRole'
    name: 'ingress-nginx-admission'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'ingress-nginx-admission'
      namespace: 'ingress-nginx'
    }
  ]
}

resource coreConfigMap_ingressNginxController 'core/ConfigMap@v1' = {
  data: 'null'
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-controller'
    namespace: 'ingress-nginx'
  }
}

resource coreService_ingressNginxController 'core/Service@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-controller'
    namespace: 'ingress-nginx'
  }
  spec: {
    externalTrafficPolicy: 'Local'
    ipFamilies: [
      'IPv4'
    ]
    ipFamilyPolicy: 'SingleStack'
    ports: [
      {
        appProtocol: 'http'
        name: 'http'
        port: 80
        protocol: 'TCP'
        targetPort: 'http'
      }
      {
        appProtocol: 'https'
        name: 'https'
        port: 443
        protocol: 'TCP'
        targetPort: 'https'
      }
    ]
    selector: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
    }
    type: 'LoadBalancer'
  }
}

resource coreService_ingressNginxControllerAdmission 'core/Service@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-controller-admission'
    namespace: 'ingress-nginx'
  }
  spec: {
    ports: [
      {
        appProtocol: 'https'
        name: 'https-webhook'
        port: 443
        targetPort: 'webhook'
      }
    ]
    selector: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
    }
    type: 'ClusterIP'
  }
}

resource appsDeployment_ingressNginxController 'apps/Deployment@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-controller'
    namespace: 'ingress-nginx'
  }
  spec: {
    minReadySeconds: 0
    revisionHistoryLimit: 10
    selector: {
      matchLabels: {
        'app.kubernetes.io/component': 'controller'
        'app.kubernetes.io/instance': 'ingress-nginx'
        'app.kubernetes.io/name': 'ingress-nginx'
      }
    }
    strategy: {
      rollingUpdate: {
        maxUnavailable: 1
      }
      type: 'RollingUpdate'
    }
    template: {
      metadata: {
        labels: {
          'app.kubernetes.io/component': 'controller'
          'app.kubernetes.io/instance': 'ingress-nginx'
          'app.kubernetes.io/name': 'ingress-nginx'
          'app.kubernetes.io/part-of': 'ingress-nginx'
          'app.kubernetes.io/version': '1.12.2'
        }
      }
      spec: {
        containers: [
          {
            args: [
              '/nginx-ingress-controller'
              '--publish-service=$(POD_NAMESPACE)/ingress-nginx-controller'
              '--election-id=ingress-nginx-leader'
              '--controller-class=k8s.io/ingress-nginx'
              '--ingress-class=nginx'
              '--configmap=$(POD_NAMESPACE)/ingress-nginx-controller'
              '--validating-webhook=:8443'
              '--validating-webhook-certificate=/usr/local/certificates/cert'
              '--validating-webhook-key=/usr/local/certificates/key'
            ]
            env: [
              {
                name: 'POD_NAME'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.name'
                  }
                }
              }
              {
                name: 'POD_NAMESPACE'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.namespace'
                  }
                }
              }
              {
                name: 'LD_PRELOAD'
                value: '/usr/local/lib/libmimalloc.so'
              }
            ]
            image: 'registry.k8s.io/ingress-nginx/controller:v1.12.2@sha256:03497ee984628e95eca9b2279e3f3a3c1685dd48635479e627d219f00c8eefa9'
            imagePullPolicy: 'IfNotPresent'
            lifecycle: {
              preStop: {
                exec: {
                  command: [
                    '/wait-shutdown'
                  ]
                }
              }
            }
            livenessProbe: {
              failureThreshold: 5
              httpGet: {
                path: '/healthz'
                port: 10254
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 1
            }
            name: 'controller'
            ports: [
              {
                containerPort: 80
                name: 'http'
                protocol: 'TCP'
              }
              {
                containerPort: 443
                name: 'https'
                protocol: 'TCP'
              }
              {
                containerPort: 8443
                name: 'webhook'
                protocol: 'TCP'
              }
            ]
            readinessProbe: {
              failureThreshold: 3
              httpGet: {
                path: '/healthz'
                port: 10254
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 1
            }
            resources: {
              requests: {
                cpu: '100m'
                memory: '90Mi'
              }
            }
            securityContext: {
              allowPrivilegeEscalation: false
              capabilities: {
                add: [
                  'NET_BIND_SERVICE'
                ]
                drop: [
                  'ALL'
                ]
              }
              readOnlyRootFilesystem: false
              runAsGroup: 82
              runAsNonRoot: true
              runAsUser: 101
              seccompProfile: {
                type: 'RuntimeDefault'
              }
            }
            volumeMounts: [
              {
                mountPath: '/usr/local/certificates/'
                name: 'webhook-cert'
                readOnly: true
              }
            ]
          }
        ]
        dnsPolicy: 'ClusterFirst'
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        serviceAccountName: 'ingress-nginx'
        terminationGracePeriodSeconds: 300
        volumes: [
          {
            name: 'webhook-cert'
            secret: {
              secretName: 'ingress-nginx-admission'
            }
          }
        ]
      }
    }
  }
}

resource batchJob_ingressNginxAdmissionCreate 'batch/Job@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission-create'
    namespace: 'ingress-nginx'
  }
  spec: {
    template: {
      metadata: {
        labels: {
          'app.kubernetes.io/component': 'admission-webhook'
          'app.kubernetes.io/instance': 'ingress-nginx'
          'app.kubernetes.io/name': 'ingress-nginx'
          'app.kubernetes.io/part-of': 'ingress-nginx'
          'app.kubernetes.io/version': '1.12.2'
        }
        name: 'ingress-nginx-admission-create'
      }
      spec: {
        containers: [
          {
            args: [
              'create'
              '--host=ingress-nginx-controller-admission,ingress-nginx-controller-admission.$(POD_NAMESPACE).svc'
              '--namespace=$(POD_NAMESPACE)'
              '--secret-name=ingress-nginx-admission'
            ]
            env: [
              {
                name: 'POD_NAMESPACE'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.namespace'
                  }
                }
              }
            ]
            image: 'registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.3@sha256:2cf4ebfa82a37c357455458f6dfc334aea1392d508270b2517795a9933a02524'
            imagePullPolicy: 'IfNotPresent'
            name: 'create'
            securityContext: {
              allowPrivilegeEscalation: false
              capabilities: {
                drop: [
                  'ALL'
                ]
              }
              readOnlyRootFilesystem: true
              runAsGroup: 65532
              runAsNonRoot: true
              runAsUser: 65532
              seccompProfile: {
                type: 'RuntimeDefault'
              }
            }
          }
        ]
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        restartPolicy: 'OnFailure'
        serviceAccountName: 'ingress-nginx-admission'
      }
    }
  }
}

resource batchJob_ingressNginxAdmissionPatch 'batch/Job@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission-patch'
    namespace: 'ingress-nginx'
  }
  spec: {
    template: {
      metadata: {
        labels: {
          'app.kubernetes.io/component': 'admission-webhook'
          'app.kubernetes.io/instance': 'ingress-nginx'
          'app.kubernetes.io/name': 'ingress-nginx'
          'app.kubernetes.io/part-of': 'ingress-nginx'
          'app.kubernetes.io/version': '1.12.2'
        }
        name: 'ingress-nginx-admission-patch'
      }
      spec: {
        containers: [
          {
            args: [
              'patch'
              '--webhook-name=ingress-nginx-admission'
              '--namespace=$(POD_NAMESPACE)'
              '--patch-mutating=false'
              '--secret-name=ingress-nginx-admission'
              '--patch-failure-policy=Fail'
            ]
            env: [
              {
                name: 'POD_NAMESPACE'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.namespace'
                  }
                }
              }
            ]
            image: 'registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.3@sha256:2cf4ebfa82a37c357455458f6dfc334aea1392d508270b2517795a9933a02524'
            imagePullPolicy: 'IfNotPresent'
            name: 'patch'
            securityContext: {
              allowPrivilegeEscalation: false
              capabilities: {
                drop: [
                  'ALL'
                ]
              }
              readOnlyRootFilesystem: true
              runAsGroup: 65532
              runAsNonRoot: true
              runAsUser: 65532
              seccompProfile: {
                type: 'RuntimeDefault'
              }
            }
          }
        ]
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        restartPolicy: 'OnFailure'
        serviceAccountName: 'ingress-nginx-admission'
      }
    }
  }
}

resource networkingK8sIoIngressClass_nginx 'networking.k8s.io/IngressClass@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'controller'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'nginx'
  }
  spec: {
    controller: 'k8s.io/ingress-nginx'
  }
}

resource admissionregistrationK8sIoValidatingWebhookConfiguration_ingressNginxAdmission 'admissionregistration.k8s.io/ValidatingWebhookConfiguration@v1' = {
  metadata: {
    labels: {
      'app.kubernetes.io/component': 'admission-webhook'
      'app.kubernetes.io/instance': 'ingress-nginx'
      'app.kubernetes.io/name': 'ingress-nginx'
      'app.kubernetes.io/part-of': 'ingress-nginx'
      'app.kubernetes.io/version': '1.12.2'
    }
    name: 'ingress-nginx-admission'
  }
  webhooks: [
    {
      admissionReviewVersions: [
        'v1'
      ]
      clientConfig: {
        service: {
          name: 'ingress-nginx-controller-admission'
          namespace: 'ingress-nginx'
          path: '/networking/v1/ingresses'
          port: 443
        }
      }
      failurePolicy: 'Fail'
      matchPolicy: 'Equivalent'
      name: 'validate.nginx.ingress.kubernetes.io'
      rules: [
        {
          apiGroups: [
            'networking.k8s.io'
          ]
          apiVersions: [
            'v1'
          ]
          operations: [
            'CREATE'
            'UPDATE'
          ]
          resources: [
            'ingresses'
          ]
        }
      ]
      sideEffects: 'None'
    }
  ]
}
