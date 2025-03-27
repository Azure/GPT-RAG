param accounts_cs0_vm2b2htvuuclm_name string
param accounts_docint_vm2b2htvuuclm_name string
param accounts_oai0_vm2b2htvuuclm_name string
param actionGroups_Application_Insights_Smart_Detection_name string
param b2cDirectories_salesfactoryai2_onmicrosoft_com_name string
param components_appins0_vm2b2htvuuclm_name string
param databaseAccounts_dbgpt0_vm2b2htvuuclm_name string

@secure()
param datastores_azureml_globaldatasets_secretsType string

@secure()
param datastores_workspaceartifactstore_secretsType string

@secure()
param datastores_workspaceblobstore_secretsType string

@secure()
param datastores_workspacefilestore_secretsType string

@secure()
param datastores_workspaceworkingdirectory_secretsType string
param searchServices_search0_vm2b2htvuuclm_name string
param serverfarms_appplan0_vm2b2htvuuclm_name string
param sites_fninges0_vm2b2htvuuclm_name string
param sites_fnorch0_vm2b2htvuuclm_name string
param sites_webgpt0_vm2b2htvuuclm_name string
param smartdetectoralertrules_failure_anomalies_appins0_vm2b2htvuuclm_name string
param storageAccounts_adb2auth_name string
param storageAccounts_strag0vm2b2htvuuclm_name string
param storageAccounts_strag0vm2b2htvuuclming_name string
param storageAccounts_strag0vm2b2htvuuclmorc_name string
param userAssignedIdentities_webgpt0_vm2b2htv_id_aeec_name string
param vaults_kv0_vm2b2htvuuclm_name string
param virtualNetworks_aivnet0_vm2b2htvuuclm_name string
param workspaces_MachineLearningPromptFlowTest_name string

resource b2cDirectories_salesfactoryai2_onmicrosoft_com_name_resource 'Microsoft.AzureActiveDirectory/b2cDirectories@2023-05-17-preview' = {
  location: 'United States'
  name: b2cDirectories_salesfactoryai2_onmicrosoft_com_name
  properties: {}
  sku: {
    name: 'PremiumP1'
    tier: 'A0'
  }
}

resource accounts_cs0_vm2b2htvuuclm_name_resource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  kind: 'CognitiveServices'
  location: 'eastus'
  name: accounts_cs0_vm2b2htvuuclm_name
  properties: {
    apiProperties: {}
    customSubDomainName: accounts_cs0_vm2b2htvuuclm_name
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource accounts_docint_vm2b2htvuuclm_name_resource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  kind: 'FormRecognizer'
  location: 'eastus'
  name: accounts_docint_vm2b2htvuuclm_name
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_resource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  kind: 'OpenAI'
  location: 'eastus'
  name: accounts_oai0_vm2b2htvuuclm_name
  properties: {
    customSubDomainName: accounts_oai0_vm2b2htvuuclm_name
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  identity: {
    type: 'None'
  }
  kind: 'GlobalDocumentDB'
  location: 'East US'
  name: databaseAccounts_dbgpt0_vm2b2htvuuclm_name
  properties: {
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    backupPolicy: {
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
      type: 'Periodic'
    }
    capabilities: []
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    cors: []
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    disableKeyBasedMetadataWriteAccess: false
    disableLocalAuth: false
    enableAnalyticalStorage: true
    enableAutomaticFailover: true
    enableBurstCapacity: false
    enableFreeTier: false
    enableMultipleWriteLocations: false
    enablePartitionMerge: false
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: 'East US'
      }
    ]
    minimalTlsVersion: 'Tls'
    networkAclBypass: 'None'
    networkAclBypassResourceIds: []
    publicNetworkAccess: 'Enabled'
    virtualNetworkRules: []
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource actionGroups_Application_Insights_Smart_Detection_name_resource 'microsoft.insights/actionGroups@2023-09-01-preview' = {
  location: 'Global'
  name: actionGroups_Application_Insights_Smart_Detection_name
  properties: {
    armRoleReceivers: [
      {
        name: 'Monitoring Contributor'
        roleId: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
        useCommonAlertSchema: true
      }
      {
        name: 'Monitoring Reader'
        roleId: '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
        useCommonAlertSchema: true
      }
    ]
    automationRunbookReceivers: []
    azureAppPushReceivers: []
    azureFunctionReceivers: []
    emailReceivers: []
    enabled: true
    eventHubReceivers: []
    groupShortName: 'SmartDetect'
    itsmReceivers: []
    logicAppReceivers: []
    smsReceivers: []
    voiceReceivers: []
    webhookReceivers: []
  }
}

resource components_appins0_vm2b2htvuuclm_name_resource 'microsoft.insights/components@2020-02-02' = {
  kind: 'web'
  location: 'eastus'
  name: components_appins0_vm2b2htvuuclm_name
  properties: {
    Application_Type: 'web'
    IngestionMode: 'ApplicationInsights'
    Request_Source: 'rest'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_resource 'Microsoft.KeyVault/vaults@2023-07-01' = {
  location: 'eastus'
  name: vaults_kv0_vm2b2htvuuclm_name
  properties: {
    accessPolicies: [
      {
        objectId: 'fac79724-d3af-4316-b83f-048e2ca6c75f'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '38edc1bb-3bf9-4e2c-bf53-c55f31446ee1'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: 'e6391111-19bc-4c51-ade6-0834b05f6ae6'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '8e068ce8-6115-4bdd-a2bc-02c46d737a85'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '1b2f609f-e7c7-4a1b-8f4c-160cb07e2ee9'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
            'Recover'
            'Backup'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '16166b0c-57b2-4772-bd02-eccf4b59d98e'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '3076cda0-6b65-4c8a-bc91-378ef8879262'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: 'ea6f1bbb-1568-4d26-a1cd-b4f6c713c457'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: 'fe9a23dd-476e-415e-a7fe-543b1f1d12a5'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
      {
        objectId: '87802ac9-dea6-492f-a620-5aed38f8822e'
        permissions: {
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          storage: []
        }
        tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
      }
    ]
    enablePurgeProtection: true
    enableSoftDelete: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 90
    tenantId: 'a44ed764-ff89-4457-baf4-483d129eb07b'
    vaultUri: 'https://${vaults_kv0_vm2b2htvuuclm_name}.vault.azure.net/'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource userAssignedIdentities_webgpt0_vm2b2htv_id_aeec_name_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: 'eastus'
  name: userAssignedIdentities_webgpt0_vm2b2htv_id_aeec_name
}

resource virtualNetworks_aivnet0_vm2b2htvuuclm_name_resource 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  location: 'eastus'
  name: virtualNetworks_aivnet0_vm2b2htvuuclm_name
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableDdosProtection: false
    subnets: [
      {
        id: virtualNetworks_aivnet0_vm2b2htvuuclm_name_ai_subnet.id
        name: 'ai-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        id: virtualNetworks_aivnet0_vm2b2htvuuclm_name_AzureBastionSubnet.id
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        id: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
        name: 'app-int-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              id: '${virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id}/delegations/appplan0-vm2b2htvuuclm'
              name: 'appplan0-vm2b2htvuuclm'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource searchServices_search0_vm2b2htvuuclm_name_resource 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  identity: {
    type: 'SystemAssigned'
  }
  location: 'East US'
  name: searchServices_search0_vm2b2htvuuclm_name
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    disableLocalAuth: false
    disabledDataExfiltrationOptions: []
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
    partitionCount: 1
    publicNetworkAccess: 'Enabled'
    replicaCount: 1
    semanticSearch: 'free'
  }
  sku: {
    name: 'standard'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource storageAccounts_adb2auth_name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  kind: 'StorageV2'
  location: 'eastus'
  name: storageAccounts_adb2auth_name
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    largeFileSharesState: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
}

resource storageAccounts_strag0vm2b2htvuuclm_name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  kind: 'StorageV2'
  location: 'eastus'
  name: storageAccounts_strag0vm2b2htvuuclm_name
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: true
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource storageAccounts_strag0vm2b2htvuuclming_name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  kind: 'Storage'
  location: 'eastus'
  name: storageAccounts_strag0vm2b2htvuuclming_name
  properties: {
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_0'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource storageAccounts_strag0vm2b2htvuuclmorc_name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  kind: 'Storage'
  location: 'eastus'
  name: storageAccounts_strag0vm2b2htvuuclmorc_name
  properties: {
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_0'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource serverfarms_appplan0_vm2b2htvuuclm_name_resource 'Microsoft.Web/serverfarms@2023-12-01' = {
  kind: 'linux'
  location: 'East US'
  name: serverfarms_appplan0_vm2b2htvuuclm_name
  properties: {
    elasticScaleEnabled: false
    hyperV: false
    isSpot: false
    isXenon: false
    maximumElasticWorkerCount: 1
    perSiteScaling: false
    reserved: true
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
  sku: {
    capacity: 1
    family: 'Pv3'
    name: 'P0v3'
    size: 'P0v3'
    tier: 'Premium0V3'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_Agent 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: accounts_oai0_vm2b2htvuuclm_name_resource
  name: 'Agent'
  properties: {
    currentCapacity: 10
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-05-13'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    capacity: 10
    name: 'Standard'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_chat 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: accounts_oai0_vm2b2htvuuclm_name_resource
  name: 'chat'
  properties: {
    currentCapacity: 20
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo-16k'
      version: '0613'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    capacity: 20
    name: 'Standard'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_text_embedding_3_small 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: accounts_oai0_vm2b2htvuuclm_name_resource
  name: 'text-embedding-3-small'
  properties: {
    currentCapacity: 900
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    capacity: 900
    name: 'GlobalStandard'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_text_embedding_ada_002 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: accounts_oai0_vm2b2htvuuclm_name_resource
  name: 'text-embedding-ada-002'
  properties: {
    currentCapacity: 20
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    capacity: 20
    name: 'Standard'
  }
}

resource accounts_oai0_vm2b2htvuuclm_name_Microsoft_Default 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-04-01-preview' = {
  parent: accounts_oai0_vm2b2htvuuclm_name_resource
  name: 'Microsoft.Default'
  properties: {
    contentFilters: [
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Hate'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Hate'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Sexual'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Sexual'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Violence'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Violence'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Selfharm'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Selfharm'
        source: 'Completion'
      }
    ]
    mode: 'Blocking'
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: 'db0-vm2b2htvuuclm'
  properties: {
    resource: {
      id: 'db0-vm2b2htvuuclm'
    }
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000001 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '00000000-0000-0000-0000-000000000001'
  properties: {
    assignableScopes: [
      databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
        ]
        notDataActions: []
      }
    ]
    roleName: 'Cosmos DB Built-in Data Reader'
    type: 'BuiltInRole'
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000002 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '00000000-0000-0000-0000-000000000002'
  properties: {
    assignableScopes: [
      databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
        notDataActions: []
      }
    ]
    roleName: 'Cosmos DB Built-in Data Contributor'
    type: 'BuiltInRole'
  }
}

resource components_appins0_vm2b2htvuuclm_name_degradationindependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'degradationindependencyduration'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      DisplayName: 'Degradation in dependency duration'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: false
      Name: 'degradationindependencyduration'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_degradationinserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'degradationinserverresponsetime'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      DisplayName: 'Degradation in server response time'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: false
      Name: 'degradationinserverresponsetime'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_digestMailConfiguration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'digestMailConfiguration'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This rule describes the digest mail preferences'
      DisplayName: 'Digest Mail Configuration'
      HelpUrl: 'www.homail.com'
      IsEnabledByDefault: true
      IsHidden: true
      IsInPreview: false
      Name: 'digestMailConfiguration'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_billingdatavolumedailyspikeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_billingdatavolumedailyspikeextension'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This detection rule automatically analyzes the billing data generated by your application, and can warn you about an unusual increase in your application\'s billing costs'
      DisplayName: 'Abnormal rise in daily data volume (preview)'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/billing-data-volume-daily-spike.md'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: true
      Name: 'extension_billingdatavolumedailyspikeextension'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_canaryextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_canaryextension'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Canary extension'
      DisplayName: 'Canary extension'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/'
      IsEnabledByDefault: true
      IsHidden: true
      IsInPreview: true
      Name: 'extension_canaryextension'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_exceptionchangeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_exceptionchangeextension'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This detection rule automatically analyzes the exceptions thrown in your application, and can warn you about unusual patterns in your exception telemetry.'
      DisplayName: 'Abnormal rise in exception volume (preview)'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/abnormal-rise-in-exception-volume.md'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: true
      Name: 'extension_exceptionchangeextension'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_memoryleakextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_memoryleakextension'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This detection rule automatically analyzes the memory consumption of each process in your application, and can warn you about potential memory leaks or increased memory consumption.'
      DisplayName: 'Potential memory leak detected (preview)'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/memory-leak.md'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: true
      Name: 'extension_memoryleakextension'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_securityextensionspackage 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_securityextensionspackage'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This detection rule automatically analyzes the telemetry generated by your application and detects potential security issues.'
      DisplayName: 'Potential security issue detected (preview)'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/application-security-detection-pack.md'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: true
      Name: 'extension_securityextensionspackage'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_extension_traceseveritydetector 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'extension_traceseveritydetector'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'This detection rule automatically analyzes the trace logs emitted from your application, and can warn you about unusual patterns in the severity of your trace telemetry.'
      DisplayName: 'Degradation in trace severity ratio (preview)'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/degradation-in-trace-severity-ratio.md'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: true
      Name: 'extension_traceseveritydetector'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_longdependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'longdependencyduration'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      DisplayName: 'Long dependency duration'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: false
      Name: 'longdependencyduration'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_migrationToAlertRulesCompleted 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'migrationToAlertRulesCompleted'
  properties: {
    CustomEmails: []
    Enabled: false
    RuleDefinitions: {
      Description: 'A configuration that controls the migration state of Smart Detection to Smart Alerts'
      DisplayName: 'Migration To Alert Rules Completed'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: false
      IsHidden: true
      IsInPreview: true
      Name: 'migrationToAlertRulesCompleted'
      SupportsEmailNotifications: false
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_slowpageloadtime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'slowpageloadtime'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      DisplayName: 'Slow page load time'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: false
      Name: 'slowpageloadtime'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource components_appins0_vm2b2htvuuclm_name_slowserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_appins0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'slowserverresponsetime'
  properties: {
    CustomEmails: []
    Enabled: true
    RuleDefinitions: {
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      DisplayName: 'Slow server response time'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsEnabledByDefault: true
      IsHidden: false
      IsInPreview: false
      Name: 'slowserverresponsetime'
      SupportsEmailNotifications: true
    }
    SendEmailsToSubscriptionOwners: true
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_privatelinkServiceonnection 'Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'privatelinkServiceonnection'
  properties: {
    privateEndpoint: {}
    privateLinkServiceConnectionState: {
      actionsRequired: 'None'
      status: 'Approved'
    }
    provisioningState: 'Succeeded'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_0aa2f521_9ce8_4737_a044_8d4e26966a55_GHlMuLrApeu5vzSZBgIx_tQ6Jvp7oKKR6LsK_WafAiw 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: '0aa2f521-9ce8-4737-a044-8d4e26966a55-GHlMuLrApeu5vzSZBgIx-tQ6Jvp7oKKR6LsK-WafAiw'
  properties: {
    attributes: {
      enabled: true
      exp: 1777470657
    }
    contentType: 'application/vnd.ms-StorageAccountAccessKey'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_0aa2f521_9ce8_4737_a044_8d4e26966a55_GxOXIo4cyLe24_Y9yfExwEKseigkvBRfjs8bEoxqCAg 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: '0aa2f521-9ce8-4737-a044-8d4e26966a55-GxOXIo4cyLe24-Y9yfExwEKseigkvBRfjs8bEoxqCAg'
  properties: {
    attributes: {
      enabled: true
      exp: 1777470043
    }
    contentType: 'application/vnd.ms-StorageAccountAccessKey'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_0aa2f521_9ce8_4737_a044_8d4e26966a55_M_oiJv1cPI1Z_jy17NVrUflhLWMjrWAo_Jv7NI5TBSo 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: '0aa2f521-9ce8-4737-a044-8d4e26966a55-M-oiJv1cPI1Z-jy17NVrUflhLWMjrWAo-Jv7NI5TBSo'
  properties: {
    attributes: {
      enabled: true
      exp: 1777470043
    }
    contentType: 'application/vnd.ms-StorageAccountAccessKey'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_0aa2f521_9ce8_4737_a044_8d4e26966a55_vfFgp44p4eNnlPiuQKUQAbENCmROLVL2oqQeQ3pQOvk 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: '0aa2f521-9ce8-4737-a044-8d4e26966a55-vfFgp44p4eNnlPiuQKUQAbENCmROLVL2oqQeQ3pQOvk'
  properties: {
    attributes: {
      enabled: true
      exp: 1777470043
    }
    contentType: 'application/vnd.ms-StorageAccountAccessKey'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_0aa2f521_9ce8_4737_a044_8d4e26966a55_X4Pz9YC6Bg73_qHBSxamfycXrr4dT1jJL5JYEYWupPg 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: '0aa2f521-9ce8-4737-a044-8d4e26966a55-X4Pz9YC6Bg73-qHBSxamfycXrr4dT1jJL5JYEYWupPg'
  properties: {
    attributes: {
      enabled: true
      exp: 1777470043
    }
    contentType: 'application/vnd.ms-StorageAccountAccessKey'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_azureDBkey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'azureDBkey'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_azureOpenAIKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'azureOpenAIKey'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_azureSearchKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'azureSearchKey'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_formRecKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'formRecKey'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_host_checkuser 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-host--checkuser'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_host_conversations 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-host--conversations'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_host_feedback 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-host--feedback'
  properties: {
    attributes: {
      enabled: true
      nbf: 1713287063
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_host_functionKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-host--functionKey'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_host_settings 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-host--settings'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_orchestrator_settings_conversations 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'orchestrator-settings--conversations'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_speechKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'speechKey'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_storageConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'storageConnectionString'
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
  }
  tags: {
    'azd-env-name': 'develop-clew'
  }
}

resource vaults_kv0_vm2b2htvuuclm_name_vmUserInitialPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vaults_kv0_vm2b2htvuuclm_name_resource
  location: 'eastus'
  name: 'vmUserInitialPassword'
  properties: {
    attributes: {
      enabled: true
    }
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_azureml_globaldatasets 'Microsoft.MachineLearningServices/workspaces/datastores@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'azureml_globaldatasets'
  properties: {
    accountName: 'mmstorageeastus2'
    containerName: 'globaldatasets'
    credentials: {
      credentialsType: 'Sas'
      secrets: {
        secretsType: datastores_azureml_globaldatasets_secretsType
      }
    }
    datastoreType: 'AzureBlob'
    endpoint: 'core.windows.net'
    protocol: 'https'
    serviceDataAccessAuthIdentity: 'None'
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_workspaceartifactstore 'Microsoft.MachineLearningServices/workspaces/datastores@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'workspaceartifactstore'
  properties: {
    accountName: 'strag0vm2b2htvuuclm'
    containerName: 'azureml'
    credentials: {
      credentialsType: 'AccountKey'
      secrets: {
        secretsType: datastores_workspaceartifactstore_secretsType
      }
    }
    datastoreType: 'AzureBlob'
    endpoint: 'core.windows.net'
    protocol: 'https'
    serviceDataAccessAuthIdentity: 'None'
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_workspaceblobstore 'Microsoft.MachineLearningServices/workspaces/datastores@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'workspaceblobstore'
  properties: {
    accountName: 'strag0vm2b2htvuuclm'
    containerName: 'azureml-blobstore-0aa2f521-9ce8-4737-a044-8d4e26966a55'
    credentials: {
      credentialsType: 'AccountKey'
      secrets: {
        secretsType: datastores_workspaceblobstore_secretsType
      }
    }
    datastoreType: 'AzureBlob'
    endpoint: 'core.windows.net'
    protocol: 'https'
    resourceGroup: 'rg-develop-clew'
    serviceDataAccessAuthIdentity: 'WorkspaceSystemAssignedIdentity'
    subscriptionId: 'e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff'
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_workspacefilestore 'Microsoft.MachineLearningServices/workspaces/datastores@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'workspacefilestore'
  properties: {
    accountName: 'strag0vm2b2htvuuclm'
    credentials: {
      credentialsType: 'AccountKey'
      secrets: {
        secretsType: datastores_workspacefilestore_secretsType
      }
    }
    datastoreType: 'AzureFile'
    endpoint: 'core.windows.net'
    fileShareName: 'azureml-filestore-0aa2f521-9ce8-4737-a044-8d4e26966a55'
    protocol: 'https'
    serviceDataAccessAuthIdentity: 'None'
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_workspaceworkingdirectory 'Microsoft.MachineLearningServices/workspaces/datastores@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'workspaceworkingdirectory'
  properties: {
    accountName: 'strag0vm2b2htvuuclm'
    credentials: {
      credentialsType: 'AccountKey'
      secrets: {
        secretsType: datastores_workspaceworkingdirectory_secretsType
      }
    }
    datastoreType: 'AzureFile'
    endpoint: 'core.windows.net'
    fileShareName: 'code-391ff5ac-6576-460f-ba4d-7e03433c68b6'
    protocol: 'https'
    serviceDataAccessAuthIdentity: 'None'
  }
}

resource virtualNetworks_aivnet0_vm2b2htvuuclm_name_ai_subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: '${virtualNetworks_aivnet0_vm2b2htvuuclm_name}/ai-subnet'
  properties: {
    addressPrefix: '10.0.1.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_aivnet0_vm2b2htvuuclm_name_resource
  ]
}

resource virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: '${virtualNetworks_aivnet0_vm2b2htvuuclm_name}/app-int-subnet'
  properties: {
    addressPrefix: '10.0.3.0/24'
    delegations: [
      {
        id: '${virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id}/delegations/appplan0-vm2b2htvuuclm'
        name: 'appplan0-vm2b2htvuuclm'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_aivnet0_vm2b2htvuuclm_name_resource
  ]
}

resource virtualNetworks_aivnet0_vm2b2htvuuclm_name_AzureBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: '${virtualNetworks_aivnet0_vm2b2htvuuclm_name}/AzureBastionSubnet'
  properties: {
    addressPrefix: '10.0.2.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_aivnet0_vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_adb2auth_name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccounts_adb2auth_name_resource
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
    cors: {
      corsRules: [
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'OPTIONS'
          ]
          allowedOrigins: [
            'https://cors-test.codehappy.dev'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 200
        }
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'OPTIONS'
            'PUT'
          ]
          allowedOrigins: [
            'https://salesfactoryai2.b2clogin.com'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 200
        }
      ]
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'HEAD'
            'PUT'
            'DELETE'
            'OPTIONS'
            'POST'
            'PATCH'
          ]
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 1800
        }
      ]
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource storageAccounts_strag0vm2b2htvuuclming_name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource storageAccounts_strag0vm2b2htvuuclmorc_name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_adb2auth_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccounts_adb2auth_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    protocolSettings: {
      smb: {}
    }
    shareDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclm_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'HEAD'
            'PUT'
            'DELETE'
            'OPTIONS'
            'POST'
          ]
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 1800
        }
      ]
    }
    protocolSettings: {
      smb: {}
    }
    shareDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclming_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    protocolSettings: {
      smb: {}
    }
    shareDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclmorc_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    protocolSettings: {
      smb: {}
    }
    shareDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_adb2auth_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccounts_adb2auth_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_strag0vm2b2htvuuclm_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_strag0vm2b2htvuuclming_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_strag0vm2b2htvuuclmorc_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_adb2auth_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccounts_adb2auth_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_strag0vm2b2htvuuclm_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_strag0vm2b2htvuuclming_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_strag0vm2b2htvuuclmorc_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'ftp'
  properties: {
    allow: true
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'dataIngest'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'ftp'
  properties: {
    allow: true
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'orchestrator'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'ftp'
  properties: {
    allow: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'frontend'
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'scm'
  properties: {
    allow: true
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'dataIngest'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'scm'
  properties: {
    allow: true
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'orchestrator'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'scm'
  properties: {
    allow: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'frontend'
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'web'
  properties: {
    acrUseManagedIdentityCreds: false
    alwaysOn: true
    autoHealEnabled: false
    azureStorageAccounts: {}
    cors: {
      allowedOrigins: [
        'https://portal.azure.com'
        'https://ms.portal.azure.com'
        '*'
      ]
      supportCredentials: false
    }
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    detailedErrorLoggingEnabled: false
    experiments: {
      rampUpRules: []
    }
    ftpsState: 'FtpsOnly'
    functionAppScaleLimit: 1
    functionsRuntimeScaleMonitoringEnabled: false
    http20Enabled: false
    httpLoggingEnabled: false
    ipSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    linuxFxVersion: 'PYTHON|3.10'
    loadBalancing: 'LeastRequests'
    localMySqlEnabled: false
    logsDirectorySizeLimit: 35
    managedPipelineMode: 'Integrated'
    managedServiceIdentityId: 6019
    minTlsVersion: '1.2'
    minimumElasticInstanceCount: 1
    netFrameworkVersion: 'v4.0'
    numberOfWorkers: 1
    preWarmedInstanceCount: 0
    publishingUsername: '$fninges0-vm2b2htvuuclm'
    remoteDebuggingEnabled: false
    requestTracingEnabled: false
    scmIpSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    scmMinTlsVersion: '1.2'
    scmType: 'None'
    use32BitWorkerProcess: false
    virtualApplications: [
      {
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualPath: '/'
      }
    ]
    vnetName: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
    vnetPrivatePortsCount: 0
    vnetRouteAllEnabled: false
    webSocketsEnabled: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'dataIngest'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'web'
  properties: {
    acrUseManagedIdentityCreds: false
    alwaysOn: true
    autoHealEnabled: false
    azureStorageAccounts: {}
    cors: {
      allowedOrigins: [
        'https://portal.azure.com'
        'https://ms.portal.azure.com'
        '*'
      ]
      supportCredentials: false
    }
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    detailedErrorLoggingEnabled: false
    experiments: {
      rampUpRules: []
    }
    ftpsState: 'FtpsOnly'
    functionAppScaleLimit: 2
    functionsRuntimeScaleMonitoringEnabled: false
    http20Enabled: false
    httpLoggingEnabled: false
    ipSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    linuxFxVersion: 'PYTHON|3.10'
    loadBalancing: 'LeastRequests'
    localMySqlEnabled: false
    logsDirectorySizeLimit: 35
    managedPipelineMode: 'Integrated'
    managedServiceIdentityId: 6020
    minTlsVersion: '1.2'
    minimumElasticInstanceCount: 1
    netFrameworkVersion: 'v4.0'
    numberOfWorkers: 2
    preWarmedInstanceCount: 0
    publishingUsername: '$fnorch0-vm2b2htvuuclm'
    remoteDebuggingEnabled: false
    requestTracingEnabled: false
    scmIpSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    scmMinTlsVersion: '1.2'
    scmType: 'None'
    use32BitWorkerProcess: false
    virtualApplications: [
      {
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualPath: '/'
      }
    ]
    vnetName: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
    vnetPrivatePortsCount: 0
    vnetRouteAllEnabled: false
    webSocketsEnabled: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'orchestrator'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'web'
  properties: {
    acrUseManagedIdentityCreds: false
    alwaysOn: true
    appCommandLine: 'python ./app.py'
    autoHealEnabled: false
    azureStorageAccounts: {}
    cors: {
      allowedOrigins: [
        'https://portal.azure.com'
        'https://ms.portal.azure.com'
      ]
      supportCredentials: false
    }
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
      'hostingstart.html'
    ]
    detailedErrorLoggingEnabled: true
    elasticWebAppScaleLimit: 0
    experiments: {
      rampUpRules: []
    }
    ftpsState: 'FtpsOnly'
    functionsRuntimeScaleMonitoringEnabled: false
    http20Enabled: false
    httpLoggingEnabled: true
    ipSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    linuxFxVersion: 'PYTHON|3.10'
    loadBalancing: 'LeastRequests'
    localMySqlEnabled: false
    logsDirectorySizeLimit: 100
    managedPipelineMode: 'Integrated'
    managedServiceIdentityId: 6018
    minTlsVersion: '1.2'
    minimumElasticInstanceCount: 1
    netFrameworkVersion: 'v4.0'
    numberOfWorkers: 1
    preWarmedInstanceCount: 0
    publishingUsername: 'REDACTED'
    remoteDebuggingEnabled: false
    requestTracingEnabled: true
    requestTracingExpirationTime: '9999-12-31T23:59:00Z'
    scmIpSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    scmMinTlsVersion: '1.2'
    scmType: 'None'
    use32BitWorkerProcess: false
    virtualApplications: [
      {
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualPath: '/'
      }
    ]
    vnetName: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
    vnetPrivatePortsCount: 0
    vnetRouteAllEnabled: true
    webSocketsEnabled: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'frontend'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_03352d5a_f377_4045_bfad_8d28934493bf 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '03352d5a-f377-4045-bfad-8d28934493bf'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-07-03T03:16:49.3608253Z'
    message: 'OneDeploy'
    start_time: '2024-07-03T03:16:16.7586909Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_077623fd_2203_4842_ae4f_9061a544a277 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '077623fd-2203-4842-ae4f-9061a544a277'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-06-28T19:32:40.969055Z'
    message: 'OneDeploy'
    start_time: '2024-06-28T19:32:04.1222131Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_0b044b53_e016_4477_881f_a77ad14effec 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '0b044b53-e016-4477-881f-a77ad14effec'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-07-02T20:04:31.5464753Z'
    message: 'OneDeploy'
    start_time: '2024-07-02T20:03:23.05775Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_128f08d9_7ea7_4c2e_98b6_5f55e305842a 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '128f08d9-7ea7-4c2e-98b6-5f55e305842a'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-06-26T19:58:11.9584758Z'
    message: 'Created via a push deployment'
    start_time: '2024-06-26T19:56:56.1546357Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_13c979ae_fc6f_409c_8ceb_df58d6b0f084 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '13c979ae-fc6f-409c-8ceb-df58d6b0f084'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-03-22T13:18:09.1764477Z'
    message: 'Created via a push deployment'
    start_time: '2024-03-22T13:16:54.891272Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_1d603ccb_03b2_4cc4_bc2b_5bf034d3b6fc 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '1d603ccb-03b2-4cc4-bc2b-5bf034d3b6fc'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-06-27T21:25:25.9727949Z'
    message: 'OneDeploy'
    start_time: '2024-06-27T21:24:26.2102569Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_294c8c57_fb5d_4e5b_8494_a07793d6ed49 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '294c8c57-fb5d-4e5b-8494-a07793d6ed49'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-24T20:07:46.4897581Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-24T20:06:28.0998919Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_336f1bf5_51c4_4b90_84ae_c0105fb68af0 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '336f1bf5-51c4-4b90-84ae-c0105fb68af0'
  properties: {
    active: true
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-07-03T20:31:34.7295887Z'
    message: 'Created via a push deployment'
    start_time: '2024-07-03T20:30:35.8891735Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_4355021d_4019_447a_a3aa_6719fdf74b4c 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '4355021d-4019-447a-a3aa-6719fdf74b4c'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-06-20T13:50:41.7070152Z'
    message: 'Created via a push deployment'
    start_time: '2024-06-20T13:49:39.4469892Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_5b5a60cc_3d36_49ce_bb30_ef191df709bd 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '5b5a60cc-3d36-49ce-bb30-ef191df709bd'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-07-01T12:29:27.8182544Z'
    message: 'Created via a push deployment'
    start_time: '2024-07-01T12:28:25.6768138Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_61e054df_005c_468b_bba7_4a38b56f42ea 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '61e054df-005c-468b-bba7-4a38b56f42ea'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-24T01:09:15.8458625Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-24T01:08:00.2219735Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_6c5b44b3_ef99_4d19_9dd7_19e51547633c 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '6c5b44b3-ef99-4d19-9dd7-19e51547633c'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-06-21T16:25:23.2713505Z'
    message: 'Created via a push deployment'
    start_time: '2024-06-21T16:24:21.4061071Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_89a7baa5_94c3_4a7e_bd48_148cc18a728d 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '89a7baa5-94c3-4a7e-bd48-148cc18a728d'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-07-04T13:06:37.6808253Z'
    message: 'OneDeploy'
    start_time: '2024-07-04T13:05:33.1440688Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_8c0cd625_c645_4f31_b733_557e320d4d40 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '8c0cd625-c645-4f31-b733-557e320d4d40'
  properties: {
    active: true
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-07-04T13:12:46.169669Z'
    message: 'OneDeploy'
    start_time: '2024-07-04T13:11:39.5482841Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_96015092_cec3_403c_9703_d8c8509ed01e 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '96015092-cec3-403c-9703-d8c8509ed01e'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-07-03T15:07:40.6517211Z'
    message: 'OneDeploy'
    start_time: '2024-07-03T15:06:28.5145832Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_9659a57e_def6_4a65_ae4c_202028411566 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '9659a57e-def6-4a65-ae4c-202028411566'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-06-27T22:33:24.1836733Z'
    message: 'Created via a push deployment'
    start_time: '2024-06-27T22:32:19.9490839Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_9741437f_6ed8_4677_946e_ffcaeedc8be4 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '9741437f-6ed8-4677-946e-ffcaeedc8be4'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-24T17:48:18.9694468Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-24T17:46:56.9252945Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_9b6b87b2_6b41_4b02_977b_1dccd2b11881 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '9b6b87b2-6b41-4b02-977b-1dccd2b11881'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-07-02T19:10:08.7044036Z'
    message: 'Created via a push deployment'
    start_time: '2024-07-02T19:09:05.7478787Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_9f55888a_9316_4234_9e00_c2eeb3b2b8a4 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '9f55888a-9316-4234-9e00-c2eeb3b2b8a4'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-06-27T21:14:50.6739654Z'
    message: 'OneDeploy'
    start_time: '2024-06-27T21:13:47.5558332Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_a7ca6729_cb20_4524_a67f_e9e24414f63e 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'a7ca6729-cb20-4524-a67f-e9e24414f63e'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-07-01T23:20:15.0690431Z'
    message: 'Created via a push deployment'
    start_time: '2024-07-01T23:19:11.7054128Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_ac848594_38e0_48c1_9ceb_b43a236b12a4 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'ac848594-38e0-48c1-9ceb-b43a236b12a4'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-17T14:46:27.0735291Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-17T14:45:09.1859413Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_b3aaf851_20e4_4a92_973d_567d994a143e 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'b3aaf851-20e4-4a92-973d-567d994a143e'
  properties: {
    active: true
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-25T17:48:50.6936019Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-25T17:47:26.5104301Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_c23ef6ff_9011_48ae_9d51_d448b9139033 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'c23ef6ff-9011-48ae-9d51-d448b9139033'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-06-28T19:36:23.7309295Z'
    message: 'OneDeploy'
    start_time: '2024-06-28T19:35:50.6153039Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_cb8e0a0b_c436_4dc2_8b1b_aaf9ec6ebb2a 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'cb8e0a0b-c436-4dc2-8b1b-aaf9ec6ebb2a'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-24T17:05:45.7953701Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-24T17:04:28.6186942Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_d06466e5_e6b5_4238_af23_c1c48db2a243 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'd06466e5-e6b5-4238-af23-c1c48db2a243'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-06-26T20:20:44.9134967Z'
    message: 'Created via a push deployment'
    start_time: '2024-06-26T20:19:41.742897Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_d2640cbd_ae80_4923_a1bf_37dc9eb2507b 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'd2640cbd-ae80-4923-a1bf-37dc9eb2507b'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-07-02T02:18:43.5212184Z'
    message: 'Created via a push deployment'
    start_time: '2024-07-02T02:17:45.0436171Z'
    status: 4
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_f07958ed_7758_42f3_9913_374f1721611d 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'f07958ed-7758-42f3-9913-374f1721611d'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'OneDeploy'
    end_time: '2024-06-27T21:20:24.8027965Z'
    message: 'OneDeploy'
    start_time: '2024-06-27T21:19:23.7827911Z'
    status: 4
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_ffa07bba_91fd_4cc0_a928_e16c24f5710c 'Microsoft.Web/sites/deployments@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'ffa07bba-91fd-4cc0-a928-e16c24f5710c'
  properties: {
    active: false
    author: 'N/A'
    author_email: 'N/A'
    deployer: 'Push-Deployer'
    end_time: '2024-04-24T15:08:29.1947824Z'
    message: 'Created via a push deployment'
    start_time: '2024-04-24T15:07:13.496001Z'
    status: 4
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_checkuser 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'checkuser'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          direction: 'in'
          methods: [
            'get'
            'post'
          ]
          name: 'req'
          type: 'httpTrigger'
        }
        {
          direction: 'out'
          name: '$return'
          type: 'http'
        }
      ]
      scriptFile: '__init__.py'
    }
    config_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/checkuser/function.json'
    href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/functions/checkuser'
    invoke_url_template: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/api/checkuser'
    isDisabled: false
    language: 'python'
    script_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/checkuser/__init__.py'
    script_root_path_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/checkuser/'
    test_data_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/checkuser.dat'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_conversations 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'conversations'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          direction: 'in'
          methods: [
            'get'
            'delete'
          ]
          name: 'req'
          route: 'conversations/{id?}'
          type: 'httpTrigger'
        }
        {
          direction: 'out'
          name: '$return'
          type: 'http'
        }
      ]
      scriptFile: '__init__.py'
    }
    config_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/conversations/function.json'
    href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/functions/conversations'
    invoke_url_template: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/api/conversations/{id?}'
    isDisabled: false
    language: 'python'
    script_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/conversations/__init__.py'
    script_root_path_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/conversations/'
    test_data_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/conversations.dat'
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_document_chunking 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'document_chunking'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'FUNCTION'
          direction: 'IN'
          name: 'req'
          route: 'document-chunking'
          type: 'httpTrigger'
        }
        {
          direction: 'OUT'
          name: '$return'
          type: 'http'
        }
      ]
      entryPoint: 'document_chunking'
      functionDirectory: '/home/site/wwwroot'
      language: 'python'
      name: 'document_chunking'
      scriptFile: 'function_app.py'
    }
    href: 'https://fninges0-vm2b2htvuuclm.azurewebsites.net/admin/functions/document_chunking'
    invoke_url_template: 'https://fninges0-vm2b2htvuuclm.azurewebsites.net/api/document-chunking'
    isDisabled: false
    language: 'python'
    script_href: 'https://fninges0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/function_app.py'
    test_data_href: 'https://fninges0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/document_chunking.dat'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_feedback 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'feedback'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          direction: 'in'
          methods: [
            'get'
            'post'
          ]
          name: 'req'
          type: 'httpTrigger'
        }
        {
          direction: 'out'
          name: '$return'
          type: 'http'
        }
      ]
      scriptFile: '__init__.py'
    }
    config_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/feedback/function.json'
    href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/functions/feedback'
    invoke_url_template: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/api/feedback'
    isDisabled: false
    language: 'python'
    script_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/feedback/__init__.py'
    script_root_path_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/feedback/'
    test_data_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/feedback.dat'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_orc 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'orc'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          direction: 'in'
          methods: [
            'get'
            'post'
          ]
          name: 'req'
          type: 'httpTrigger'
        }
        {
          direction: 'out'
          name: '$return'
          type: 'http'
        }
      ]
      scriptFile: '__init__.py'
    }
    config_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/orc/function.json'
    href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/functions/orc'
    invoke_url_template: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/api/orc'
    isDisabled: false
    language: 'python'
    script_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/orc/__init__.py'
    script_root_path_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/orc/'
    test_data_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/orc.dat'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_settings 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: 'settings'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          direction: 'in'
          methods: [
            'get'
            'post'
          ]
          name: 'req'
          type: 'httpTrigger'
        }
        {
          direction: 'out'
          name: '$return'
          type: 'http'
        }
      ]
      scriptFile: '__init__.py'
    }
    config_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/settings/function.json'
    href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/functions/settings'
    invoke_url_template: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/api/settings'
    isDisabled: false
    language: 'python'
    script_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/settings/__init__.py'
    script_root_path_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/site/wwwroot/settings/'
    test_data_href: 'https://fnorch0-vm2b2htvuuclm.azurewebsites.net/admin/vfs/home/data/Functions/sampledata/settings.dat'
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_sites_fninges0_vm2b2htvuuclm_name_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '${sites_fninges0_vm2b2htvuuclm_name}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: 'fninges0-vm2b2htvuuclm'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_sites_fnorch0_vm2b2htvuuclm_name_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '${sites_fnorch0_vm2b2htvuuclm_name}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: 'fnorch0-vm2b2htvuuclm'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_sites_webgpt0_vm2b2htvuuclm_name_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '${sites_webgpt0_vm2b2htvuuclm_name}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: 'webgpt0-vm2b2htvuuclm'
  }
}

resource smartdetectoralertrules_failure_anomalies_appins0_vm2b2htvuuclm_name_resource 'microsoft.alertsmanagement/smartdetectoralertrules@2021-04-01' = {
  location: 'global'
  name: smartdetectoralertrules_failure_anomalies_appins0_vm2b2htvuuclm_name
  properties: {
    actionGroups: {
      groupIds: [
        actionGroups_Application_Insights_Smart_Detection_name_resource.id
      ]
    }
    description: 'Failure Anomalies notifies you of an unusual rise in the rate of failed HTTP requests or dependency calls.'
    detector: {
      id: 'FailureAnomaliesDetector'
    }
    frequency: 'PT1M'
    scope: [
      components_appins0_vm2b2htvuuclm_name_resource.id
    ]
    severity: 'Sev3'
    state: 'Enabled'
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_agentErrors 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'agentErrors'
  properties: {
    resource: {
      computedProperties: []
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      defaultTtl: 86400
      id: 'agentErrors'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_conversations 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'conversations'
  properties: {
    resource: {
      analyticalStorageTtl: -1
      computedProperties: []
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'conversations'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_feedback 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'feedback'
  properties: {
    resource: {
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'feedback'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/_partitionKey'
        ]
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_models 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'models'
  properties: {
    resource: {
      analyticalStorageTtl: -1
      computedProperties: []
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'models'
      indexingPolicy: {
        automatic: false
        excludedPaths: []
        includedPaths: []
        indexingMode: 'none'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_prompts 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'prompts'
  properties: {
    resource: {
      computedProperties: []
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      defaultTtl: 604800
      id: 'prompts'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_settings 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'settings'
  properties: {
    resource: {
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'settings'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/_partitionKey'
        ]
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_users 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'users'
  properties: {
    resource: {
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'users'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_userTokens 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
  name: 'userTokens'
  properties: {
    resource: {
      computedProperties: []
      conflictResolutionPolicy: {
        conflictResolutionPath: '/_ts'
        mode: 'LastWriterWins'
      }
      id: 'userTokens'
      indexingPolicy: {
        automatic: true
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        includedPaths: [
          {
            path: '/*'
          }
        ]
        indexingMode: 'consistent'
      }
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_11e31339_a6c7_404e_84d1_a8bf7308319b 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '11e31339-a6c7-404e-84d1-a8bf7308319b'
  properties: {
    principalId: 'ea6f1bbb-1568-4d26-a1cd-b4f6c713c457'
    roleDefinitionId: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000002.id
    scope: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_3f166f54_e18b_45e5_87ce_325b5e6caf26 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '3f166f54-e18b-45e5-87ce-325b5e6caf26'
  properties: {
    principalId: 'fe9a23dd-476e-415e-a7fe-543b1f1d12a5'
    roleDefinitionId: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000002.id
    scope: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_42cef116_eacb_54ee_94b2_60ae0750f909 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '42cef116-eacb-54ee-94b2-60ae0750f909'
  properties: {
    principalId: 'e6391111-19bc-4c51-ade6-0834b05f6ae6'
    roleDefinitionId: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000002.id
    scope: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_5b26153d_49ef_47b2_904a_8476705b9f32 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  name: '5b26153d-49ef-47b2-904a-8476705b9f32'
  properties: {
    principalId: '1b2f609f-e7c7-4a1b-8f4c-160cb07e2ee9'
    roleDefinitionId: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_00000000_0000_0000_0000_000000000002.id
    scope: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource.id
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_resource
  name: 'AzureOpenAIClew'
  properties: {
    authType: 'AAD'
    category: 'AzureOpenAI'
    isSharedToAll: false
    metadata: {
      ApiType: 'azure'
      ApiVersion: '2024-02-01'
      DeploymentApiVersion: '2023-10-01-preview'
      ResourceId: accounts_oai0_vm2b2htvuuclm_name_resource.id
      'azureml.flow.connection_type': 'AzureOpenAI'
      'azureml.flow.module': 'promptflow.connections'
    }
    sharedUserList: []
    target: 'https://oai0-vm2b2htvuuclm.openai.azure.com/'
  }
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew_Agent 'Microsoft.MachineLearningServices/workspaces/connections/deployments@2024-04-01-preview' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew
  name: 'Agent'
  properties: {}
  sku: {
    capacity: 10
    name: 'Standard'
  }
  dependsOn: [
    workspaces_MachineLearningPromptFlowTest_name_resource
  ]
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew_chat 'Microsoft.MachineLearningServices/workspaces/connections/deployments@2024-04-01-preview' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew
  name: 'chat'
  properties: {}
  sku: {
    capacity: 20
    name: 'Standard'
  }
  dependsOn: [
    workspaces_MachineLearningPromptFlowTest_name_resource
  ]
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew_text_embedding_3_small 'Microsoft.MachineLearningServices/workspaces/connections/deployments@2024-04-01-preview' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew
  name: 'text-embedding-3-small'
  properties: {}
  sku: {
    capacity: 150
    name: 'GlobalStandard'
  }
  dependsOn: [
    workspaces_MachineLearningPromptFlowTest_name_resource
  ]
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew_text_embedding_ada_002 'Microsoft.MachineLearningServices/workspaces/connections/deployments@2024-04-01-preview' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew
  name: 'text-embedding-ada-002'
  properties: {}
  sku: {
    capacity: 20
    name: 'Standard'
  }
  dependsOn: [
    workspaces_MachineLearningPromptFlowTest_name_resource
  ]
}

resource workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew_Microsoft_Default 'Microsoft.MachineLearningServices/workspaces/connections/raiPolicies@2024-04-01-preview' = {
  parent: workspaces_MachineLearningPromptFlowTest_name_AzureOpenAIClew
  name: 'Microsoft.Default'
  properties: {
    contentFilters: [
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Hate'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Hate'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Sexual'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Sexual'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Violence'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Violence'
        source: 'Completion'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Selfharm'
        source: 'Prompt'
      }
      {
        allowedContentLevel: 'Medium'
        blocking: true
        enabled: true
        name: 'Selfharm'
        source: 'Completion'
      }
    ]
    mode: 'Blocking'
    type: 'SystemManaged'
  }
  dependsOn: [
    workspaces_MachineLearningPromptFlowTest_name_resource
  ]
}

resource storageAccounts_adb2auth_name_default_auth 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_adb2auth_name_default
  name: 'auth'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'Container'
  }
  dependsOn: [
    storageAccounts_adb2auth_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_azureml 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'azureml'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_azureml_blobstore_0aa2f521_9ce8_4737_a044_8d4e26966a55 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'azureml-blobstore-0aa2f521-9ce8-4737-a044-8d4e26966a55'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclming_name_default_azure_webjobs_hosts 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_default
  name: 'azure-webjobs-hosts'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclming_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclmorc_name_default_azure_webjobs_hosts 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_default
  name: 'azure-webjobs-hosts'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclming_name_default_azure_webjobs_secrets 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclming_name_default
  name: 'azure-webjobs-secrets'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclming_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclmorc_name_default_azure_webjobs_secrets 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclmorc_name_default
  name: 'azure-webjobs-secrets'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_documents 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'documents'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_ms_az_cognitive_search_debugsession 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'ms-az-cognitive-search-debugsession'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_revisions 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'revisions'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_snapshots 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'snapshots'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_snapshotzips 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'snapshotzips'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_azureml_filestore_0aa2f521_9ce8_4737_a044_8d4e26966a55 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'azureml-filestore-0aa2f521-9ce8-4737-a044-8d4e26966a55'
  properties: {
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
    shareQuota: 102400
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclm_name_default_code_391ff5ac_6576_460f_ba4d_7e03433c68b6 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclm_name_default
  name: 'code-391ff5ac-6576-460f-ba4d-7e03433c68b6'
  properties: {
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
    shareQuota: 102400
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclm_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclming_name_default_fninges0_vm2b2htvuuclm 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclming_name_default
  name: 'fninges0-vm2b2htvuuclm'
  properties: {
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
    shareQuota: 102400
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclming_name_resource
  ]
}

resource storageAccounts_strag0vm2b2htvuuclmorc_name_default_fnorch0_vm2b2htvuuclm 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: Microsoft_Storage_storageAccounts_fileServices_storageAccounts_strag0vm2b2htvuuclmorc_name_default
  name: 'fnorch0-vm2b2htvuuclm'
  properties: {
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
    shareQuota: 102400
  }
  dependsOn: [
    storageAccounts_strag0vm2b2htvuuclmorc_name_resource
  ]
}

resource sites_fninges0_vm2b2htvuuclm_name_resource 'Microsoft.Web/sites@2023-12-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp,linux'
  location: 'East US'
  name: sites_fninges0_vm2b2htvuuclm_name
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    containerSize: 1536
    customDomainVerificationId: '5AEEF3403E4DA9CEBB1391C0D1E1AA623F3B4E45BA98BA883DFD0ABF1BB66526'
    dailyMemoryTimeQuota: 0
    dnsConfiguration: {}
    enabled: true
    hostNameSslStates: [
      {
        hostType: 'Standard'
        name: '${sites_fninges0_vm2b2htvuuclm_name}.azurewebsites.net'
        sslState: 'Disabled'
      }
      {
        hostType: 'Repository'
        name: '${sites_fninges0_vm2b2htvuuclm_name}.scm.azurewebsites.net'
        sslState: 'Disabled'
      }
    ]
    hostNamesDisabled: false
    httpsOnly: true
    hyperV: false
    isXenon: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    redundancyMode: 'None'
    reserved: true
    scmSiteAlsoStopped: false
    serverFarmId: serverfarms_appplan0_vm2b2htvuuclm_name_resource.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      functionAppScaleLimit: 1
      http20Enabled: false
      linuxFxVersion: 'PYTHON|3.10'
      minimumElasticInstanceCount: 1
      numberOfWorkers: 1
    }
    storageAccountRequired: false
    virtualNetworkSubnetId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
    vnetBackupRestoreEnabled: false
    vnetContentShareEnabled: false
    vnetImagePullEnabled: false
    vnetRouteAllEnabled: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'dataIngest'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_resource 'Microsoft.Web/sites@2023-12-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp,linux'
  location: 'East US'
  name: sites_fnorch0_vm2b2htvuuclm_name
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    containerSize: 1536
    customDomainVerificationId: '5AEEF3403E4DA9CEBB1391C0D1E1AA623F3B4E45BA98BA883DFD0ABF1BB66526'
    dailyMemoryTimeQuota: 0
    dnsConfiguration: {}
    enabled: true
    hostNameSslStates: [
      {
        hostType: 'Standard'
        name: '${sites_fnorch0_vm2b2htvuuclm_name}.azurewebsites.net'
        sslState: 'Disabled'
      }
      {
        hostType: 'Repository'
        name: '${sites_fnorch0_vm2b2htvuuclm_name}.scm.azurewebsites.net'
        sslState: 'Disabled'
      }
    ]
    hostNamesDisabled: false
    httpsOnly: true
    hyperV: false
    isXenon: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    redundancyMode: 'None'
    reserved: true
    scmSiteAlsoStopped: false
    serverFarmId: serverfarms_appplan0_vm2b2htvuuclm_name_resource.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      functionAppScaleLimit: 2
      http20Enabled: false
      linuxFxVersion: 'PYTHON|3.10'
      minimumElasticInstanceCount: 1
      numberOfWorkers: 2
    }
    storageAccountRequired: false
    virtualNetworkSubnetId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
    vnetBackupRestoreEnabled: false
    vnetContentShareEnabled: false
    vnetImagePullEnabled: false
    vnetRouteAllEnabled: false
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'orchestrator'
    'hidden-link: /app-insights-conn-string': 'InstrumentationKey=94e8c802-e65e-48b0-a002-57f7e3f02430;IngestionEndpoint=https://eastus-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=8e9fb018-3160-4b09-bd9a-e8ca0a5f21ef'
    'hidden-link: /app-insights-instrumentation-key': '94e8c802-e65e-48b0-a002-57f7e3f02430'
    'hidden-link: /app-insights-resource-id': '/subscriptions/e261fb0a-3d87-49c1-8d3c-32b2bc93b6ff/resourceGroups/rg-develop-clew/providers/microsoft.insights/components/appins0-vm2b2htvuuclm'
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_resource 'Microsoft.Web/sites@2023-12-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'app,linux'
  location: 'East US'
  name: sites_webgpt0_vm2b2htvuuclm_name
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    containerSize: 0
    customDomainVerificationId: '5AEEF3403E4DA9CEBB1391C0D1E1AA623F3B4E45BA98BA883DFD0ABF1BB66526'
    dailyMemoryTimeQuota: 0
    dnsConfiguration: {}
    enabled: true
    hostNameSslStates: [
      {
        hostType: 'Standard'
        name: '${sites_webgpt0_vm2b2htvuuclm_name}.azurewebsites.net'
        sslState: 'Disabled'
      }
      {
        hostType: 'Repository'
        name: '${sites_webgpt0_vm2b2htvuuclm_name}.scm.azurewebsites.net'
        sslState: 'Disabled'
      }
    ]
    hostNamesDisabled: false
    httpsOnly: true
    hyperV: false
    isXenon: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    redundancyMode: 'None'
    reserved: true
    scmSiteAlsoStopped: false
    serverFarmId: serverfarms_appplan0_vm2b2htvuuclm_name_resource.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      functionAppScaleLimit: 0
      http20Enabled: false
      linuxFxVersion: 'PYTHON|3.10'
      minimumElasticInstanceCount: 1
      numberOfWorkers: 1
    }
    storageAccountRequired: false
    virtualNetworkSubnetId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
    vnetBackupRestoreEnabled: false
    vnetContentShareEnabled: false
    vnetImagePullEnabled: false
    vnetRouteAllEnabled: true
  }
  tags: {
    'azd-env-name': 'develop-clew'
    'azd-service-name': 'frontend'
  }
}

resource sites_fninges0_vm2b2htvuuclm_name_0a8c8848_3baf_4429_8eab_cbef97a3162c_app_int_subnet 'Microsoft.Web/sites/virtualNetworkConnections@2023-12-01' = {
  parent: sites_fninges0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
  properties: {
    isSwift: true
    vnetResourceId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
  }
}

resource sites_fnorch0_vm2b2htvuuclm_name_0a8c8848_3baf_4429_8eab_cbef97a3162c_app_int_subnet 'Microsoft.Web/sites/virtualNetworkConnections@2023-12-01' = {
  parent: sites_fnorch0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
  properties: {
    isSwift: true
    vnetResourceId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
  }
}

resource sites_webgpt0_vm2b2htvuuclm_name_0a8c8848_3baf_4429_8eab_cbef97a3162c_app_int_subnet 'Microsoft.Web/sites/virtualNetworkConnections@2023-12-01' = {
  parent: sites_webgpt0_vm2b2htvuuclm_name_resource
  location: 'East US'
  name: '0a8c8848-3baf-4429-8eab-cbef97a3162c_app-int-subnet'
  properties: {
    isSwift: true
    vnetResourceId: virtualNetworks_aivnet0_vm2b2htvuuclm_name_app_int_subnet.id
  }
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_agentErrors_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_agentErrors
  name: 'default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_conversations_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_conversations
  name: 'default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: 1000
      }
      throughput: 100
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_feedback_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_feedback
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_models_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_models
  name: 'default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: 1000
      }
      throughput: 100
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_prompts_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_prompts
  name: 'default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_settings_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_settings
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_users_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_users
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_userTokens_default 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2024-05-15' = {
  parent: databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm_userTokens
  name: 'default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
      throughput: 400
    }
  }
  dependsOn: [
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_db0_vm2b2htvuuclm
    databaseAccounts_dbgpt0_vm2b2htvuuclm_name_resource
  ]
}

resource workspaces_MachineLearningPromptFlowTest_name_resource 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'Default'
  location: 'eastus2'
  name: workspaces_MachineLearningPromptFlowTest_name
  properties: {
    applicationInsights: components_appins0_vm2b2htvuuclm_name_resource.id
    discoveryUrl: 'https://eastus2.api.azureml.ms/discovery'
    enableDataIsolation: false
    friendlyName: workspaces_MachineLearningPromptFlowTest_name
    hbiWorkspace: false
    keyVault: vaults_kv0_vm2b2htvuuclm_name_resource.id
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    publicNetworkAccess: 'Enabled'
    storageAccount: storageAccounts_strag0vm2b2htvuuclm_name_resource.id
    v1LegacyMode: false
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}
