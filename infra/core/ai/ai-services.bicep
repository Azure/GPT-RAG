import { roleAssignmentInfo } from '../security/managed-identity.bicep'
import { diagnosticSettingsInfo } from '../management_governance/log-analytics-workspace.bicep'

@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

param aiServicesDeploy bool = true
param aiServicesReuse bool
param existingAiServicesResourceGroupName string

@export()
@description('Information about a Responsible AI policy for AI Services.')
type raiPolicyInfo = {
  @description('Name for the Responsible AI policy. Must be unique within AI Services.')
  name: string
  @description('Mode for the Responsible AI policy.')
  mode: 'Blocking' | 'Default' | 'Deferred'
  prompt: {
    violence: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    hate: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    sexual: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    selfharm: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    jailbreak: {
      blocking: bool
      enabled: bool
    }?
    indirect_attack: {
      blocking: bool
      enabled: bool
    }?
  }?
  completion: {
    violence: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    hate: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    sexual: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    selfharm: {
      SeverityThreshold: 'Low' | 'Medium' | 'High'
      blocking: bool
      enabled: bool
    }?
    protected_material_text: {
      blocking: bool
      enabled: bool
    }?
    protected_material_code: {
      blocking: bool
      enabled: bool
    }?
  }?
}

@export()
@description('Information about a model deployment for AI Services.')
type modelDeploymentInfo = {
  @description('Name for the model deployment. Must be unique within AI Services.')
  name: string
  @description('Information about the model to deploy.')
  model: {
    @description('Format of the model. Expects "OpenAI".')
    format: string
    @description('ID of the model, e.g., gpt-35-turbo. For more information on model IDs: https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models')
    name: string
    @description('Version of the model, e.g., 0125. For more information on model versions: https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models')
    version: string
  }?
  @description('Name of the content filter policy to apply to the model deployment.')
  raiPolicyName: string?
  @description('Sizing for the model deployment.')
  sku: {
    @description('Name of the SKU. Expects "Standard".')
    name: string
    @description('TPM quota allocation for the model deployment. For more information on model quota limits per region: https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models')
    capacity: int
  }?
  @description('Option for upgrading the model deployment version.')
  versionUpgradeOption: 'NoAutoUpgrade' | 'OnceCurrentVersionExpired' | 'OnceNewDefaultVersionAvailable'
}

@description('ID for the Managed Identity associated with the AI Services instance. Defaults to the system-assigned identity.')
param identityId string?
@description('ID for the Managed Identity associated with the AI Services instance. Defaults to the system-assigned identity.')
param identityPrincipalId string?
@description('ID for the Managed Identity associated with the AI Services instance. Defaults to the system-assigned identity.')
param identityClientId string?
@description('List of model deployments.')
param deployments modelDeploymentInfo[] = []
@description('Whether to enable public network access. Defaults to Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
@description('Whether to disable local (key-based) authentication. Defaults to true.')
param disableLocalAuth bool = true
@description('List of Responsible AI policies to apply to the AI Services instance.')
param raiPolicies raiPolicyInfo[] = []
@description('Role assignments to create for the AI Services instance.')
param roleAssignments roleAssignmentInfo[] = []
@description('Name of the Log Analytics Workspace to use for diagnostic settings.')
param logAnalyticsWorkspaceName string?
@description('Diagnostic settings to configure for the AI Services instance. Defaults to all logs and metrics.')
param diagnosticSettings diagnosticSettingsInfo = {
  logs: [
    {
      categoryGroup: 'allLogs'
      enabled: true
    }
  ]
  metrics: [
    {
      category: 'AllMetrics'
      enabled: true
    }
  ]
}

resource existingAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing  = if (aiServicesReuse && aiServicesDeploy) {
  scope: resourceGroup(existingAiServicesResourceGroupName)
  name: name
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = if (!aiServicesReuse && aiServicesDeploy) {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  identity: {
    type: identityId == null ? 'SystemAssigned' : 'UserAssigned'
    userAssignedIdentities: identityId == null
      ? null
      : {
          '${identityId}': {
            //principalId: identityPrincipalId
            //clientId: identityClientId
          }
        }
  }
  properties: {
    customSubDomainName: toLower(name)
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  sku: {
    name: 'S0'
  }
}

@batchSize(1)
resource raiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01' = [
  for raiPolicy in raiPolicies: {
    parent: aiServices
    name: raiPolicy.name
    properties: {
      mode: raiPolicy.mode
      basePolicyName: 'Microsoft.DefaultV2'
      contentFilters: [
        {
          name: 'violence'
          SeverityThreshold: raiPolicy.?prompt.?violence.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?prompt.?violence.?blocking ?? true
          enabled: raiPolicy.?prompt.?violence.?enabled ?? true
          source: 'Prompt'
        }
        {
          name: 'violence'
          SeverityThreshold: raiPolicy.?completion.?violence.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?completion.?violence.?blocking ?? true
          enabled: raiPolicy.?completion.?violence.?enabled ?? true
          source: 'Completion'
        }
        {
          name: 'hate'
          SeverityThreshold: raiPolicy.?prompt.?hate.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?prompt.?hate.?blocking ?? true
          enabled: raiPolicy.?prompt.?hate.?enabled ?? true
          source: 'Prompt'
        }
        {
          name: 'hate'
          SeverityThreshold: raiPolicy.?completion.?hate.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?completion.?hate.?blocking ?? true
          enabled: raiPolicy.?completion.?hate.?enabled ?? true
          source: 'Completion'
        }
        {
          name: 'sexual'
          SeverityThreshold: raiPolicy.?prompt.?sexual.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?prompt.?sexual.?blocking ?? true
          enabled: raiPolicy.?prompt.?sexual.?enabled ?? true
          source: 'Prompt'
        }
        {
          name: 'sexual'
          SeverityThreshold: raiPolicy.?completion.?sexual.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?completion.?sexual.?blocking ?? true
          enabled: raiPolicy.?completion.?sexual.?enabled ?? true
          source: 'Completion'
        }
        {
          name: 'selfharm'
          SeverityThreshold: raiPolicy.?prompt.?selfharm.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?prompt.?selfharm.?blocking ?? true
          enabled: raiPolicy.?prompt.?selfharm.?enabled ?? true
          source: 'Prompt'
        }
        {
          name: 'selfharm'
          SeverityThreshold: raiPolicy.?completion.?selfharm.?SeverityThreshold ?? 'High'
          blocking: raiPolicy.?completion.?selfharm.?blocking ?? true
          enabled: raiPolicy.?completion.?selfharm.?enabled ?? true
          source: 'Completion'
        }
        {
          name: 'jailbreak'
          blocking: raiPolicy.?prompt.?jailbreak.?blocking ?? true
          enabled: raiPolicy.?prompt.?jailbreak.?enabled ?? true
          source: 'Prompt'
        }
        {
          name: 'indirect_attack'
          blocking: raiPolicy.?prompt.?indirect_attack.?blocking ?? false
          enabled: raiPolicy.?prompt.?indirect_attack.?enabled ?? false
          source: 'Prompt'
        }
        {
          name: 'protected_material_text'
          blocking: raiPolicy.?completion.?protected_material_text.?blocking ?? true
          enabled: raiPolicy.?completion.?protected_material_text.?enabled ?? true
          source: 'Completion'
        }
        {
          name: 'protected_material_code'
          blocking: raiPolicy.?completion.?protected_material_code.?blocking ?? false
          enabled: raiPolicy.?completion.?protected_material_code.?enabled ?? true
          source: 'Completion'
        }
      ]
    }
  }
]

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [
  for deployment in deployments: {
    parent: aiServices
    name: deployment.name
    properties: {
      model: deployment.?model ?? null
      raiPolicyName: deployment.?raiPolicyName ?? null
      versionUpgradeOption: deployment.?versionUpgradeOption ?? 'OnceCurrentVersionExpired'
    }
    sku: deployment.?sku ?? {
      name: 'Standard'
      capacity: 5
    }
    dependsOn: [
      raiPolicy
    ]
  }
]

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleAssignment in roleAssignments: {
    name: guid(aiServices.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    scope: aiServices
    properties: {
      principalId: roleAssignment.principalId
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalType: roleAssignment.principalType
    }
  }
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (logAnalyticsWorkspaceName != null) {
  name: logAnalyticsWorkspaceName!
}

resource aiServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceName != null) {
  name: '${aiServices.name}-diagnostic-settings'
  scope: aiServices
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: diagnosticSettings!.logs
    metrics: diagnosticSettings!.metrics
  }
}

@description('ID for the deployed AI Services resource.')
output id string = aiServicesReuse ? existingAccount.id: aiServices.id
@description('Name for the deployed AI Services resource.')
output name string = aiServicesReuse ? existingAccount.name: aiServices.name
@description('Endpoint for the deployed AI Services resource.')
output endpoint string = aiServicesReuse ? existingAccount.properties.endpoint: aiServices.properties.endpoint
@description('Host for the deployed AI Services resource.')
output host string = aiServicesReuse ? split(existingAccount.properties.endpoint, '/')[2] : split(aiServices.properties.endpoint, '/')[2]
@description('Endpoint for the Azure OpenAI API.')
output openAIEndpoint string = aiServicesReuse ? existingAccount.properties.endpoints['OpenAI Language Model Instance API'] : aiServices.properties.endpoints['OpenAI Language Model Instance API']
@description('Host for the Azure OpenAI API.')
output openAIHost string = aiServicesReuse ? split(existingAccount.properties.endpoints['OpenAI Language Model Instance API'], '/')[2] : split(aiServices.properties.endpoints['OpenAI Language Model Instance API'], '/')[2]
@description('Principal ID for the deployed AI Services resource.')
output principalId string = identityPrincipalId == null ? aiServices.identity.principalId : identityPrincipalId!
