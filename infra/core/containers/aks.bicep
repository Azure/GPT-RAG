/** Inputs **/
@description('Action Group Id for alerts')
param actionGroupId string

@description('The Managed Identity for the AKS Cluster')
param admnistratorObjectIds array
param adminPassword string
param podsServiceCidr string = '10.244.0.0/16'
param aksServiceCidr string = '10.100.0.0/16'
param aksNodeSku string
param k8sVersion string = '1.31.7'
param k8sNamespace string = 'gptrag'
param vmSize string = 'Standard_D2s_v5'
param resourceToken string

param certificateUri string

param webEnvs array = []
param orchEnvs array = []
param ingEnvs array = []
param mcpEnvs array = []

param repoUrl string
param useAgentic bool = false

@description('Location for all resources')
param location string

@description('Log Analytic Workspace Id to use for diagnostics')
param logAnalyticWorkspaceId string

@description('Log Analytic Workspace Resource Id to use for diagnostics')
param logAnalyticWorkspaceResourceId string

param monitorWorkspaceName string

@description('Networking resource group name')
param networkingResourceGroupName string

@description('Private DNS Zones for private endpoint')
param privateDnsZones array

@description('Network isolation? If yes it will create the private endpoints.')
@allowed([true, false])
param networkIsolation bool = false
var _networkIsolation = networkIsolation

@description('MSI Id.')
param identityId string?

// @description('Private IP for ingress')
// param privateIpIngress string

@description('Resource suffix for all resources')
param resourceSuffix string

@description('Subnet Id for private endpoint')
param subnetId string

@description('Subnet Id for private endpoint')
param subnetIdPrivateEndpoint string

@description('Tags for all resources')
param tags object

@description('Timestamp for nested deployments')
param timestamp string = utcNow()

var abbrs = loadJsonContent('../../abbreviations.json')
var roles = loadJsonContent('../../roles.json')

// @description('Managed Identity for the AKS Cluster Helm Deployments')
// param uaiDeploymentid string

/** Locals **/
var name = '${serviceType}-${resourceSuffix}'
var serviceType = 'aks'

var alerts = [
  {
    description: 'Node CPU utilization greater than 95% for 1 hour'
    evaluationFrequency: 'PT5M'
    metricName: 'node_cpu_usage_percentage'
    name: 'node-cpu'
    operator: 'GreaterThan'
    severity: 3
    threshold: 95
    timeAggregation: 'Average'
    windowSize: 'PT5M'
  }
  {
    description: 'Node memory utilization greater than 95% for 1 hour'
    evaluationFrequency: 'PT5M'
    metricName: 'node_memory_working_set_percentage'
    name: 'node-memory'
    operator: 'GreaterThan'
    severity: 3
    threshold: 100
    timeAggregation: 'Average'
    windowSize: 'PT5M'
  }
]

var logs = [
  'cloud-controller-manager'
  'cluster-autoscaler'
  'csi-azuredisk-controller'
  'csi-azurefile-controller'
  'csi-snapshot-controller'
  'guard'
  'kube-apiserver'
  'kube-audit'
  'kube-audit-admin'
  'kube-controller-manager'
  'kube-scheduler'
]

/** Data Sources **/
var zones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)

/** Resources **/
resource main 'Microsoft.ContainerService/managedClusters@2025-02-01' = {
  name: name
  location: location
  tags: tags
  dependsOn: [
    aksDcr
  ]

  identity: {
    type: identityId == null ? 'SystemAssigned' : 'UserAssigned'
    userAssignedIdentities: identityId == null
      ? null
      : {
          '${identityId}': {}
        }
  }

  sku: {
    name: 'Base'
    tier: 'Standard'
  }

  properties: {
    kubernetesVersion: k8sVersion
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    //azurePortalFqdn: _networkIsolation?name:null
    fqdnSubdomain: _networkIsolation?name:null
    dnsPrefix: name
    nodeResourceGroup: 'mrg-${name}'
    disableLocalAccounts: _networkIsolation?true:false
    workloadAutoScalerProfile: {}

    /*
    aadProfile: {
      managed: true
      adminGroupObjectIDs: admnistratorObjectIds
      enableAzureRBAC: true
      tenantID: subscription().tenantId
    }
    */

    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
          rotationPollInterval: '2m'
        }
      }

      azurepolicy: {
        config: null
        enabled: true
      }

      /*
      ingressApplicationGateway: {
        enabled: false
      }
      */

      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticWorkspaceId
          useAADAuth: 'true'
        }
      }
    }
    windowsProfile: {
      adminUsername: 'azureuser'
      adminPassword: adminPassword
      enableCSIProxy: true
    }
    agentPoolProfiles: [
      {
        availabilityZones: zones
        count: 1
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        mode: 'System'
        name: 'agentpool'
        osDiskSizeGB: 256
        osDiskType: 'Managed'
        tags: tags
        type: 'VirtualMachineScaleSets'
        //osType: 'Linux'
        //#osSKU: 'Ubuntu'
        vmSize: vmSize
        vnetSubnetID: _networkIsolation ? subnetId : null

        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]

        upgradeSettings: {
          maxSurge: '200'
        }
      }
    ]

    apiServerAccessProfile: {
      enablePrivateCluster: _networkIsolation?true:false
      enablePrivateClusterPublicFQDN: _networkIsolation?false:true
      privateDNSZone: _networkIsolation?filter(privateDnsZones, (privateDnsZone) => privateDnsZone.key == 'aks')[0].id : null
    }

    autoUpgradeProfile: { 
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
   }

    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
    }

    networkProfile: {
      dnsServiceIP: cidrHost(cidrSubnet(aksServiceCidr, 24, 254), 1)
      ipFamilies: [ 'IPv4' ]
      loadBalancerSku: 'Standard'
      networkPlugin: 'overlay'
      networkPolicy: 'none'
      outboundType: 'loadBalancer'
      podCidr: podsServiceCidr
      serviceCidr: aksServiceCidr
      podCidrs: [
        podsServiceCidr
      ]
      serviceCidrs: [ aksServiceCidr ]

      loadBalancerProfile: {
        backendPoolType: 'nodeIPConfiguration'
        managedOutboundIPs: { count: 1 }
      }
    }

    oidcIssuerProfile: { enabled: true }

    privateLinkResources: [
      {
        groupId: 'management'
        name: 'management'
        requiredMembers: [ 'management' ]
        type: 'Microsoft.ContainerService/managedClusters/privateLinkResources'
      }
    ]

    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalyticWorkspaceResourceId

        securityMonitoring: {
          enabled: true
        }
      }

      imageCleaner: {
        enabled: false
        intervalHours: 48
      }

      workloadIdentity: { enabled: true }
    }

    servicePrincipalProfile: {
      clientId: 'msi'
    }

    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }

      fileCSIDriver: {
        enabled: true
      }

      snapshotController: {
        enabled: true
      }
    }
  }
}

var privateIpIngressBackend = main.properties.networkProfile.dnsServiceIP

module ns '../../aks/namespace.bicep' = {
  name: 'ns'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    name: k8sNamespace
  }
}

module nsGateway '../../aks/namespace.bicep' = {
  name: 'nsGateway'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    name: 'gateway-system'
  }
}

module nsIngress '../../aks/namespace.bicep' = {
  name: 'nsIngress'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    name: 'ingress-ngnix'
  }
}

/*
module ingressNgnix '../../aks/ingress-ngnix.bicep' = {
  name: 'ingressNgnix'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
  }
}
*/

module certificates '../../aks/certificates.bicep' = {
  name: 'certificates'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    name: k8sNamespace
    namespace: k8sNamespace
    identityId: identityId
    keyVaultName: '${abbrs.security.keyVault}${resourceSuffix}'
  }
}

var services = [
  'frontend'
  'ingestion'
  'orchestrator'
  'mcp'
]
  
  
module frontendSvcAccount '../../aks/service-account.bicep' = {
  name: 'frontendSvcAccount'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    clientId: filter(webEnvs, (env) => env.name == 'AZURE_CLIENT_ID')[0].value
    name: 'frontend-service-account'
    namespace: k8sNamespace
  }
}

module orchSvcAccount '../../aks/service-account.bicep' = {
  name: 'orchSvcAccount'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    clientId: filter(orchEnvs, (env) => env.name == 'AZURE_CLIENT_ID')[0].value
    name: 'orchestrator-service-account'
    namespace: k8sNamespace
  }
}

module ingSvcAccount '../../aks/service-account.bicep' = {
  name: 'ingSvcAccount'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    clientId: filter(ingEnvs, (env) => env.name == 'AZURE_CLIENT_ID')[0].value
    name: 'ingestion-service-account'
    namespace: k8sNamespace
  }
}

module mcpSvcAccount '../../aks/service-account.bicep' = {
  name: 'mcpSvcAccount'
  params: {
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    clientId: filter(mcpEnvs, (env) => env.name == 'AZURE_CLIENT_ID')[0].value
    name: 'mcp-service-account'
    namespace: k8sNamespace
  }
}

module aksweb '../../aks/deployment.bicep' = {
  name: 'aksweb'
  params: {
    prefix: 'gpt-rag'
    name: 'frontend'
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    image: '${repoUrl}/gpt-rag-frontend:latest'
    namespace: k8sNamespace
    env : webEnvs
    serviceType : 'ClusterIP'
    useLoadBalancer: true
    targetPort: 8000
  }
}

module aksingest '../../aks/deployment.bicep' = {
  name: 'aksingest'
  params: {
    prefix: 'gpt-rag'
    name: 'ingestion'
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    image: '${repoUrl}/gpt-rag-ingestion:latest'
    namespace: k8sNamespace
    env : ingEnvs
    serviceType : 'ClusterIP'
    useLoadBalancer: true
    targetPort: 80
  }
}

module aksorch '../../aks/deployment.bicep' = {
  name: 'aksorch'
  params: {
    prefix: 'gpt-rag'
    name: 'orchestrator'
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    image: (useAgentic)? '${repoUrl}/gpt-rag-agentic:latest' : '${repoUrl}/gpt-rag-orchestrator:latest'
    namespace: k8sNamespace
    env : orchEnvs
    serviceType : 'ClusterIP'
    useLoadBalancer: true
    targetPort: 80
  }
}

module aksmcp '../../aks/deployment.bicep' = {
  name: 'aksmcp'
  params: {
    prefix: 'gpt-rag'
    name: 'mcp'
    kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
    image: '${repoUrl}/gpt-rag-mcp:latest'
    namespace: k8sNamespace
    env : mcpEnvs
    serviceType : 'ClusterIP'
    useLoadBalancer: true
    targetPort: 8000
  }
}

var annotations = {
  'nginx.ingress.kubernetes.io/rewrite-target': '/$1'
  'nginx.ingress.kubernetes.io/use-regex': 'true'
  'nginx.ingress.kubernetes.io/proxy-connect-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600'
}

var annotationsWithTls = {
  'nginx.ingress.kubernetes.io/rewrite-target': '/$1'
  'nginx.ingress.kubernetes.io/use-regex': 'true'
  'nginx.ingress.kubernetes.io/proxy-connect-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
  'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600'
  'kubernetes.azure.com/tls-cert-keyvault-uri': certificateUri
}

module allIngresses '../../aks/service-ingress.bicep' = [for svc in services: {
    name: 'aks${svc}-ingress'
    params: {
      name: svc
      resourceToken: resourceToken
      kubeConfig: main.listClusterAdminCredential().kubeconfigs[0].value
      namespace: k8sNamespace
      path: '/'
      pathType: 'Prefix'
      annotations: !empty(certificateUri) ? annotationsWithTls : annotations
    }
  }
]

resource userPool 'Microsoft.ContainerService/managedClusters/agentPools@2025-02-01' = {
  name: 'user'
  parent: main
  properties: {
    availabilityZones: zones
    count: 2
    enableAutoScaling: true
    maxCount: 2
    minCount: 2
    mode: 'User'
    osDiskSizeGB: 256
    osDiskType: 'Managed'
    tags: tags
    type: 'VirtualMachineScaleSets'
    vmSize: aksNodeSku
    vnetSubnetID: _networkIsolation ? subnetId : null

    upgradeSettings: {
      maxSurge: '200'
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: main
  name: 'diag-${serviceType}'
  properties: {
    workspaceId: logAnalyticWorkspaceId
    logs: [for log in logs: {
      category: log
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource dce 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' existing = {
  name: monitorWorkspaceName
  scope: resourceGroup('MA_${monitorWorkspaceName}_${location}_managed')
}

resource aksDcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'MSCI-${location}-${name}'
  location: location
  properties: {
    destinations: {
      logAnalytics: [
        {
          name: 'ciworkspace'
          workspaceResourceId: logAnalyticWorkspaceId
        }
      ]
    }

    dataCollectionEndpointId: dce.id

    dataFlows: [
      {
        destinations: ['ciworkspace']
        streams: ['Microsoft-ContainerInsights-Group-Default']
      }
      {
        streams: [ 'Microsoft-Syslog' ]
        destinations: [ 'ciworkspace' ]
      }
    ]

    dataSources: {
      syslog: [
        {
          streams: [ 'Microsoft-Syslog' ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'mark'
            'kern'
            'local0'
            'local1'
            'local2'
            'local3'
            'local4'
            'local5'
            'local6'
            'local7'
            'lpr'
            'mail'
            'news'
            'syslog'
            'user'
            'uucp'  
          ]
          logLevels: [
            'Debug'
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'  
          ]
          name: 'sysLogsDataSource'
        }
      ]
      extensions: [
        {
          streams: ['Microsoft-ContainerInsights-Group-Default']
          extensionName: 'ContainerInsights'
          extensionSettings: {
            dataCollectionSettings: {
              interval: '5m'
              namespaceFilteringMode: 'Off'
              enableContainerLogV2: true
            }
          }
          name: 'ContainerInsightsExtension'
        }
      ]
    }

    description: 'DCR for Azure Monitor Container Insights'
  }
}

#disable-next-line BCP174
resource aksDcra 'Microsoft.ContainerService/managedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${name}/microsoft.insights/ContainerInsights'
  dependsOn: [ main ]
  properties: {
    description: 'Association of data collection endpoint. Deleting this association will break the data collection for this AKS Cluster.'
    dataCollectionRuleId: aksDcr.id
  }
}

#disable-next-line BCP174
resource aksDcera 'Microsoft.ContainerService/managedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${name}/microsoft.insights/configurationAccessEndpoint'
  dependsOn: [ main ]
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster.'
    dataCollectionEndpointId: dce.id
  }
}

@description('Resource for configuring the Key Vault metric alerts.')
module metricAlerts '../util/metricAlerts.bicep' = {
  name: 'a-${main.name}-${timestamp}'
  params: {
    actionGroupId: actionGroupId
    alerts: alerts
    metricNamespace: 'Microsoft.ContainerService/managedClusters'
    nameSuffix: name
    serviceId: main.id
    tags: tags
  }
}

resource aksMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${abbrs.security.managedIdentity}${abbrs.containers.aksCluster}${resourceToken}'
}

resource aksFrontendMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${abbrs.security.managedIdentity}${abbrs.containers.aksCluster}web-${resourceToken}'
}

resource aksOrchMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${abbrs.security.managedIdentity}${abbrs.containers.aksCluster}orch-${resourceToken}'
}

resource aksIngMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${abbrs.security.managedIdentity}${abbrs.containers.aksCluster}ing-${resourceToken}'
}

resource aksMcpMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${abbrs.security.managedIdentity}${abbrs.containers.aksCluster}mcp-${resourceToken}'
}

resource aksFrontEndMsiFederated 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: 'aksFederatedFrontEnd'
  parent : aksFrontendMsi
  properties: {
    issuer: main.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${k8sNamespace}:frontend-service-account'
    audiences: ['api://AzureADTokenExchange']
  }
}

resource aksOrchMsiFederated 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: 'aksFederatedOrch'
  parent : aksOrchMsi
  properties: {
    issuer: main.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${k8sNamespace}:orchestrator-service-account'
    audiences: ['api://AzureADTokenExchange']
  }
}

resource aksIngMsiFederated 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: 'aksFederatedIng'
  parent : aksIngMsi
  properties: {
    issuer: main.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${k8sNamespace}:ingestion-service-account'
    audiences: ['api://AzureADTokenExchange']
  }
}

resource aksMcpMsiFederated 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: 'aksFederatedMcp'
  parent : aksMcpMsi
  properties: {
    issuer: main.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${k8sNamespace}:mcp-service-account'
    audiences: ['api://AzureADTokenExchange']
  }
}

/** Outputs **/
output id string = main.id
output name string = main.name
output oidcIssuerUrl string = main.properties.oidcIssuerProfile.issuerURL
output privateIpIngress string = main.properties.networkProfile.dnsServiceIP
