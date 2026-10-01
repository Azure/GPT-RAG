// =============================================================================
// AI Landing Zone — test hub
// =============================================================================
//
// Minimal hub topology used to validate v2.0.0 hub-and-spoke / AI LZ integrated
// scenarios from issue #58. This is *not* a production-ready hub; it is a
// purpose-built test fixture.
//
// Deployed resources (in resource group `rg-ailz-hub`):
//   * Hub VNet               10.100.0.0/16
//       - AzureFirewallSubnet 10.100.0.0/26 (mandatory name, /26 minimum)
//       - AzureBastionSubnet  10.100.1.0/26 (mandatory name, /26 minimum)
//   * Azure Firewall (Standard) — empty policy by default (egress passes
//     through but isn't filtered). Issue #58 §4.6 Option A.
//   * Azure Bastion (Standard) — Standard SKU required for peered-VNet
//     access to spoke jumpboxes.
//   * Log Analytics Workspace — referenced by the spoke deployment to
//     exercise Gap 5 (existingPlatformServices.logAnalyticsWorkspaceResourceId).
//
// Outputs feed the spoke deployment via `tests/scripts/Deploy-Hub.ps1`.
//
// =============================================================================

targetScope = 'resourceGroup'

@description('Location for all hub resources. Default uses the resource group location.')
param location string = resourceGroup().location

@description('Prefix used to name hub resources. Keep short — combined with -<resourceToken>.')
param namePrefix string = 'ailzhub'

@description('Deterministic suffix appended to resource names. Defaults to a hash of the RG ID for idempotency.')
param resourceToken string = uniqueString(resourceGroup().id)

@description('Hub VNet address space. Must not overlap with any spoke address space.')
param hubVnetAddressPrefix string = '10.100.0.0/16'

@description('Azure Firewall subnet CIDR. Subnet name MUST be AzureFirewallSubnet and minimum /26.')
param firewallSubnetPrefix string = '10.100.0.0/26'

@description('Bastion subnet CIDR. Subnet name MUST be AzureBastionSubnet and minimum /26.')
param bastionSubnetPrefix string = '10.100.1.0/26'

@description('Deploy Azure Firewall in the hub. Default true.')
param deployFirewall bool = true

@description('Deploy Azure Bastion (Standard) in the hub. Default true.')
param deployBastion bool = true

@description('Deploy a Log Analytics Workspace in the hub for Gap 5 reuse testing. Default true.')
param deployLogAnalytics bool = true

@description('Tags applied to every hub resource.')
param tags object = {
  purpose: 'ailz-v2-test'
  scope: 'hub'
}

// -----------------------------------------------------------------------------
// VNet
// -----------------------------------------------------------------------------

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${namePrefix}-vnet-${resourceToken}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ hubVnetAddressPrefix ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Azure Firewall (Standard) — empty policy by default
// -----------------------------------------------------------------------------

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = if (deployFirewall) {
  name: '${namePrefix}-afwp-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployFirewall) {
  name: '${namePrefix}-afw-pip-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = if (deployFirewall) {
  name: '${namePrefix}-afw-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy!.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPublicIp!.id
          }
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Azure Bastion (Standard) — required SKU for peered-VNet access
// -----------------------------------------------------------------------------

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion) {
  name: '${namePrefix}-bas-pip-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = if (deployBastion) {
  name: '${namePrefix}-bas-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    // Native client tunneling — required so operators can run
    //   az network bastion ssh --name <bastion> --resource-group rg-ailz-hub \
    //     --target-resource-id <jumpbox-resource-id> --auth-type AAD
    // against a jumpbox in the peered spoke VNet from outside the portal.
    // Without this, only the in-browser RDP/SSH session works, which prevents
    // the post-provision automation flow from the operator workstation.
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPublicIp!.id
          }
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Log Analytics Workspace — referenced by the spoke for Gap 5 reuse test
// -----------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (deployLogAnalytics) {
  name: '${namePrefix}-law-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs — consumed by the spoke deployment
// -----------------------------------------------------------------------------

output hubVnetResourceId string = hubVnet.id
output hubVnetName string = hubVnet.name
output firewallSubnetResourceId string = '${hubVnet.id}/subnets/AzureFirewallSubnet'
output bastionSubnetResourceId string = '${hubVnet.id}/subnets/AzureBastionSubnet'

#disable-next-line BCP318
output firewallPrivateIp string = deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
#disable-next-line BCP318
output firewallResourceId string = deployFirewall ? firewall.id : ''

#disable-next-line BCP318
output bastionResourceId string = deployBastion ? bastion.id : ''
#disable-next-line BCP318
output bastionFqdn string = deployBastion ? bastion.properties.dnsName : ''

#disable-next-line BCP318
output logAnalyticsWorkspaceResourceId string = deployLogAnalytics ? logAnalytics.id : ''
