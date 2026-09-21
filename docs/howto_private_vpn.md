# How-to: Set up private GPT-RAG access from your local Windows machine

## Why use a VPN?

A network-isolated GPT-RAG deployment exposes its services through private
endpoints. Your local machine needs a private network connection to configure
those services and test the application.

The deployment guide normally uses an administration VM, also called a jumpbox,
for this work. If you cannot sign in to that VM, or your organization requires
you to work from a managed local machine, a **Point-to-Site (P2S) VPN** provides
a connection from that machine to the Azure virtual network.

This guide explains how to set up that connection, configure private DNS, and
prepare the latest stable GPT-RAG release to use the same network. You continue
to sign in with your own Azure account. The VPN does not bypass Conditional
Access, grant Azure permissions, or give the agent access to documents.

> **Scope.** This guide covers private connectivity
> and deployment preparation. Check the [deployment-host requirement](#8-continue-the-gpt-rag-installation)
> before creating resources: VPN connectivity alone does not remove restrictions
> imposed by the deployment scripts.

!!! warning "Unpublished v3.8.5 companion draft"
    `v3.8.4` is still the latest published release. Its network-isolated
    pre-deploy hook requires `RUN_FROM_JUMPBOX=true`; do not set that flag on a
    local machine to pretend it is a jumpbox. The candidate host-check workflow
    in steps 7-8 is for the planned `v3.8.5` change, not a feature available in
    `v3.8.4`. Wait for the published release before using that workflow; do not
    replace release pins with a development branch or personal commit.

## 1. Before you start

This procedure assumes **Windows 11, Azure public cloud, and a dedicated VNet**
for the installation. If your organization already provides private connectivity
and DNS, use that approved setup instead of creating duplicate infrastructure.
Shared VNets and hub-and-spoke integration need a separate network review.

### Where each resource goes

To keep this example simple, use **one new, dedicated Azure resource group**
for both the VPN network and GPT-RAG. You choose its name; this guide uses
`rg-gpt-rag-private`. A resource group is an Azure container for related
resources in your subscription. It is not an existing corporate network group,
a folder on your local machine, or the name of your `azd` environment.

Create the network first, in steps 4 and 5. In step 6, tell `azd` to provision
GPT-RAG into **that same group** with
`azd env set AZURE_RESOURCE_GROUP $resourceGroup`. Do not create a second group
for GPT-RAG or move the VPN resources between steps.

| Resource or setting | Where it goes in this example | When it is created or selected |
| --- | --- | --- |
| Resource group, `$resourceGroup` | Your chosen subscription; example `rg-gpt-rag-private` | Step 4, once |
| VNet and its subnets | Inside `$resourceGroup` | VPN/DNS subnets in steps 4-5; workload subnets in step 7 |
| VPN Gateway and its public IP | Inside the same `$resourceGroup`; gateway uses `GatewaySubnet` in the VNet | Step 4 |
| DNS Private Resolver and inbound endpoint | Inside the same `$resourceGroup`; inbound endpoint uses the dedicated DNS subnet | Step 5 |
| GPT-RAG services and private endpoints | Inside the same `$resourceGroup`, using the existing VNet | Step 7 and the hosted deployment phases in step 8 |
| `$environment`, for example `gpt-rag-vpn-dev` | Local `azd` configuration under `.azure\<environment-name>\` in your checkout | Step 2; this is not an Azure resource group |

Using one group is a simplification, not an enterprise requirement. Separately
owned network groups, shared VNets, and hub-and-spoke networking are outside
this walkthrough. Use a platform-reviewed design for those scenarios.

Prepare:

- A managed local Windows machine that meets your organization's access policies.
- Azure VPN Client, Azure CLI, Azure Developer CLI (`azd`), Git, PowerShell 7.4+,
  and the Python version required by the GPT-RAG release.
- An approved subscription, tenant, region, and sufficient service/model quotas.
- Deployment permissions and the service data-plane permissions required by
  the [deployment guide](deploy.md).
  Creating runtime role assignments also requires an authorized deployment
  identity; a VPN connection does not provide that permission.
- Approval for VPN Gateway, DNS Private Resolver, and GPT-RAG resource costs.
  These resources can continue incurring charges after you disconnect.

The local machine and the Azure build environment both need their respective
approved outbound access to dependencies. Do not bypass corporate package,
proxy, or VPN policies.

### Run the examples one section at a time

Use the same **PowerShell 7.4+ session** so variables remain available. Replace
placeholders and review each block before running it. Commands marked **Write**
create or change resources; **Read** commands inspect them. Do not paste the
whole guide into a terminal or repeat a creation command after a timeout without
checking the resource state.

Start with:

```powershell
if ($PSVersionTable.PSVersion -lt [version]'7.4') {
    throw 'Use PowerShell 7.4 or later for this guide.'
}
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
```

These process-local settings stop a block when a PowerShell command fails or
`az`, `azd`, or `git` returns a nonzero exit code. They do not change persistent
machine settings. If you reopen the terminal, restore these settings and the
variables before continuing.

## 2. Get the latest stable GPT-RAG release

Open the [latest stable release](https://github.com/Azure/GPT-RAG/releases/latest)
and copy its tag. Use that release as a complete package; do not select component
versions individually or replace its manifest entries with development branches.

In a new working directory:

```powershell
$release = '<latest-stable-release-tag>'
git clone --branch $release --recurse-submodules https://github.com/Azure/GPT-RAG.git gpt-rag
if ($LASTEXITCODE -ne 0) { throw 'Could not download the GPT-RAG release.' }
Set-Location .\gpt-rag
$repoRoot = (Get-Location).Path
```

### Find your subscription, tenant, and region

Open the [Azure Portal](https://portal.azure.com/) with your own account. In
**Subscriptions**, select the approved subscription and copy its
**Subscription ID**. In **Microsoft Entra ID > Overview**, copy the
**Tenant ID** for the directory that owns that subscription. If you belong to
multiple directories, check **Directories + subscriptions** before copying.
See Microsoft's [subscription and tenant ID instructions](https://learn.microsoft.com/azure/azure-portal/get-subscription-tenant-id).

Choose the region with your administrator before creating anything. The
Portal's resource creation **Region** selector shows display names, such as
**East US 2**; the command variable uses the corresponding Azure location name,
such as `eastus2`. This example is not a capacity or quota guarantee.

| Variable | What to enter | Illustrative value, not your account |
| --- | --- | --- |
| `$tenant` | Directory's Tenant ID from the Portal | `00000000-0000-0000-0000-000000000000` |
| `$subscription` | Approved Subscription ID from the Portal | `11111111-1111-1111-1111-111111111111` |
| `$region` | Approved Azure location name | `eastus2` |
| `$environment` | A new local `azd` environment name you choose | `gpt-rag-vpn-dev` |

For example, a populated variable block has the following form. **The two
GUIDs are fictitious: replace them with your Portal values before running it.**
Also replace `eastus2` if your approved region differs.

```powershell
$tenant = '00000000-0000-0000-0000-000000000000'
$subscription = '11111111-1111-1111-1111-111111111111'
$region = 'eastus2'
$environment = 'gpt-rag-vpn-dev'
```

Use your actual values in the block below, then sign in and create the local
environment. Run each command separately and stop if it fails.

```powershell
$tenant = '<tenant-id>'
$subscription = '<subscription-id>'
$region = '<approved-region>'
$environment = '<new-environment-name>'

az login --tenant $tenant
az account set --subscription $subscription
az account show --query '{Subscription:name,Tenant:tenantId}' --output table
azd auth login --tenant-id $tenant
azd env new $environment
```

Azure CLI and `azd` have separate authentication contexts. Do not use the VM
managed-identity login commands on your local machine.

The account table must show the intended subscription and tenant.
`azd env new` selects `$environment` and creates local configuration under
`.azure\$environment`; it does **not** create the resource group or the VPN.
Keep that directory out of source control. If resuming the same installation,
select its existing local environment instead of creating a new one:
`azd env select $environment`.

**Release boundary:** cloning the current latest stable release does not add
the planned VPN-host deployment support. Until `v3.8.5` is published, you can
review and prepare the network, but must not treat the candidate steps below
as a complete local deployment path for `v3.8.4`.

## 3. Plan non-overlapping network ranges

Check your local routes, including Wi-Fi, virtual adapters, and other VPNs:

```powershell
Get-NetRoute -AddressFamily IPv4 |
    Select-Object DestinationPrefix, NextHop, InterfaceAlias |
    Sort-Object DestinationPrefix -Unique
```

Review the address plan with your network team as well. The local route table
does not show every corporate or disconnected network.

The following ranges are **examples**, not required values. Use them only if
they are available and approved:

| Purpose | Example range |
| --- | --- |
| GPT-RAG VNet | `10.80.0.0/20` |
| VPN gateway subnet, named exactly `GatewaySubnet` | `10.80.15.0/27` |
| DNS inbound subnet, for example `snet-dns-inbound` | `10.80.15.32/28` |
| P2S client address pool | `10.81.0.0/24` |

The client pool is separate from the VNet: it is not a VNet subnet and must not
overlap the VNet or other connected networks. Reserve enough space for the
GPT-RAG workload subnets listed in step 6.

Set the names and approved ranges once. Names below are examples for a **new,
dedicated resource group shared by the VPN/DNS network and GPT-RAG**. Keep
`$resourceGroup` unchanged throughout this walkthrough; `$environment` remains
the separate local configuration name from step 2:

```powershell
$resourceGroup = 'rg-gpt-rag-private'
$vnetName = 'vnet-gpt-rag-private'
$publicIpName = 'pip-gpt-rag-vpn'
$gatewayName = 'vpngw-gpt-rag'
$resolverName = 'dnspr-gpt-rag'
$dnsSubnetName = 'snet-dns-inbound'
$inboundName = 'dns-inbound'

$vnetPrefix = '10.80.0.0/20'
$gatewaySubnetPrefix = '10.80.15.0/27'
$dnsSubnetPrefix = '10.80.15.32/28'
$dnsInboundIp = '10.80.15.36'
$p2sPool = '10.81.0.0/24'
```

If you choose different ranges, update both these variables and the workload
subnet parameters in step 6. Keep the VNet, VPN gateway, and resolver in the
same approved region for this example.

## 4. Create the VNet and P2S VPN

These steps create billable Azure resources. Obtain the required approval first.
If completing the installation entirely from your local machine is essential,
read step 8 before creating the gateway.

### Create the resource group and network

**First run only; Read, then Write if missing:** this block checks the
`$resourceGroup` name from step 3 in `$subscription` from step 2. It creates
that group in `$region` only when absent, then requires it to be empty before
starting a fresh network. An existing empty group reserved for this installation
is also acceptable; an existing corporate or unrelated group is not.

```powershell
$groupExists = az group exists --subscription $subscription --name $resourceGroup --output tsv
if ($groupExists -eq 'false') {
    az group create --subscription $subscription --name $resourceGroup --location $region --output table
} elseif ($groupExists -ne 'true') {
    throw 'Could not determine whether the resource group exists.'
}

$existingResources = @(az resource list --subscription $subscription --resource-group $resourceGroup --output json | ConvertFrom-Json)
if ($existingResources.Count -gt 0) {
    $existingResources | Select-Object name, type
    throw 'The resource group is not empty. Review it instead of rerunning fresh resource creation.'
}
```

For a new group, expect the creation command to return its name and location,
then an empty resource list. Once the VPN or DNS resources exist, the group
is **expected to be nonempty**. The check above is a first-run safeguard,
not a recurring prerequisite. Do not delete resources to make it pass, and do
not choose a new group merely because you are resuming.

### Resume an interrupted setup safely

Restore the same variables and select the same local `azd` environment from
step 2. **Read only:** inventory the existing group before retrying a step:

```powershell
az resource list --subscription $subscription --resource-group $resourceGroup `
    --query '[].{name:name,type:type,location:location}' --output table
```

Identify the VNet, gateway, public IP, and DNS resources by the names you chose.
Use the corresponding **Read** commands in steps 4 and 5 to verify their
settings and provisioning state. A resource still provisioning after a
timeout may only need its existing wait/status check, not another create.
Resume from the failed or incomplete step once its prerequisites are verified.
Do not blindly rerun all creation blocks, overwrite a differing resource,
delete the group, or restart in a second group. Stop for owner review when the
existing names, settings, or ownership do not match your intended installation.

### Create the VNet

**Write:** create the VNet with its reserved `GatewaySubnet`:

```powershell
az network vnet create --subscription $subscription `
    --resource-group $resourceGroup --name $vnetName --location $region `
    --address-prefixes $vnetPrefix `
    --subnet-name GatewaySubnet --subnet-prefixes $gatewaySubnetPrefix `
    --output none

$vnetId = az network vnet show --subscription $subscription `
    --resource-group $resourceGroup --name $vnetName --query id --output tsv
if (-not $vnetId) { throw 'The VNet resource ID was not returned.' }
```

**Read:** confirm the range, `Succeeded` state, and no NSG or route table on
`GatewaySubnet`:

```powershell
az network vnet show --subscription $subscription --resource-group $resourceGroup `
    --name $vnetName --query '{name:name,state:provisioningState,ranges:addressSpace.addressPrefixes}' --output json
az network vnet subnet show --subscription $subscription --resource-group $resourceGroup `
    --vnet-name $vnetName --name GatewaySubnet `
    --query '{prefix:addressPrefix,nsg:networkSecurityGroup.id,routeTable:routeTable.id}' --output json
```

### Create the VPN gateway

**Write:** the example uses an availability-zone-capable region, a zone-redundant
Standard public IP, and `VpnGw1AZ`. Confirm SKU/zone availability and costs for
your region before running it; do not substitute Basic for Entra P2S.

```powershell
az network public-ip create --subscription $subscription `
    --resource-group $resourceGroup --name $publicIpName --location $region `
    --sku Standard --allocation-method Static --version IPv4 --zone 1 2 3 `
    --output none

az network vnet-gateway create --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName --location $region `
    --vnet $vnetId --public-ip-addresses $publicIpName `
    --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1AZ --no-wait
```

**Read:** wait up to one hour, then inspect the result. Gateway creation can
take tens of minutes. A timeout does not mean the creation was cancelled;
inspect the existing gateway rather than creating another one.

```powershell
az network vnet-gateway wait --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName `
    --created --interval 30 --timeout 3600
az network vnet-gateway show --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName `
    --query '{name:name,state:provisioningState,type:gatewayType,vpnType:vpnType,sku:sku.name}' --output json
```

Continue only when the state is `Succeeded`.

### Enable Entra-authenticated P2S

For the Microsoft-registered Azure VPN Client application in Azure public cloud:

| Field | Value |
| --- | --- |
| Tenant | `https://login.microsoftonline.com/<tenant-id>` |
| Audience | `c632b3df-fb67-4d84-bdcf-b95ad541b5c8` |
| Issuer | `https://sts.windows.net/<tenant-id>/` |

The Audience value is a public Microsoft application identifier, not a secret.
If your organization uses a custom audience or restricts VPN access to selected
users/groups, follow that approved configuration. Do not assume that every
tenant user should be allowed to connect.

**Write:** configure P2S on the gateway you just created:

```powershell
az network vnet-gateway update --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName `
    --address-prefixes $p2sPool --client-protocol OpenVPN --vpn-auth-type AAD `
    --aad-tenant "https://login.microsoftonline.com/$tenant" `
    --aad-audience 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8' `
    --aad-issuer "https://sts.windows.net/$tenant/" --no-wait

az network vnet-gateway wait --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName `
    --updated --interval 30 --timeout 1800
```

**Read:** check `Succeeded`, the intended client pool, `OpenVPN`, `AAD`, and
your tenant/audience/issuer:

```powershell
az network vnet-gateway show --subscription $subscription `
    --resource-group $resourceGroup --name $gatewayName `
    --query '{state:provisioningState,pool:vpnClientConfiguration.vpnClientAddressPool.addressPrefixes,protocols:vpnClientConfiguration.vpnClientProtocols,auth:vpnClientConfiguration.vpnAuthenticationTypes,tenant:vpnClientConfiguration.aadTenant,audience:vpnClientConfiguration.aadAudience,issuer:vpnClientConfiguration.aadIssuer}' `
    --output json
```

The gateway's public IP accepts VPN connections. It does not require exposing
Storage, Search, Foundry, or the other GPT-RAG services publicly.

See [Configure P2S with Microsoft Entra ID](https://learn.microsoft.com/azure/vpn-gateway/point-to-site-entra-gateway)
for the complete gateway and authentication instructions.

## 5. Configure private DNS and connect

### Create the DNS inbound subnet and resolver

The DNS resolver commands require the `dns-resolver` Azure CLI extension.
**Read:** check whether it is installed:

```powershell
az extension list --query "[?name=='dns-resolver'].{name:name,version:version}" --output table
```

If it is missing, and installation is approved on your machine, install it:

```powershell
az extension add --name dns-resolver
```

**Write:** create a dedicated delegated subnet. Do not place other resources
in it or attach the workload route table:

```powershell
az network vnet subnet create --subscription $subscription `
    --resource-group $resourceGroup --vnet-name $vnetName --name $dnsSubnetName `
    --address-prefixes $dnsSubnetPrefix --delegations Microsoft.Network/dnsResolvers `
    --output none

$dnsSubnetId = az network vnet subnet show --subscription $subscription `
    --resource-group $resourceGroup --vnet-name $vnetName --name $dnsSubnetName `
    --query id --output tsv
if (-not $dnsSubnetId) { throw 'The DNS subnet resource ID was not returned.' }

az dns-resolver create --subscription $subscription `
    --resource-group $resourceGroup --name $resolverName --location $region `
    --id $vnetId --if-none-match '*' --output none

az dns-resolver inbound-endpoint create --subscription $subscription `
    --resource-group $resourceGroup --dns-resolver-name $resolverName `
    --name $inboundName --location $region --if-none-match '*' `
    --ip-configurations "[{private-ip-address:$dnsInboundIp,private-ip-allocation-method:Static,id:$dnsSubnetId}]" `
    --output none
```

The CLI shorthand above uses a subnet `id` and a static inbound IP. The example
`10.80.15.36` is a usable address in `10.80.15.32/28`; choose an available,
non-reserved address if you change that subnet.

**Read:** verify both resources show `Succeeded` and the returned IP matches
the one you selected:

```powershell
az dns-resolver show --subscription $subscription --resource-group $resourceGroup `
    --name $resolverName --query '{state:provisioningState,vnet:virtualNetwork.id}' --output json
az dns-resolver inbound-endpoint show --subscription $subscription `
    --resource-group $resourceGroup --dns-resolver-name $resolverName `
    --name $inboundName --query '{state:provisioningState,ip:ipConfigurations[0].privateIpAddress,subnet:ipConfigurations[0].subnet.id}' --output json
```

For this simple client-to-Azure DNS flow, you do not need an outbound endpoint
or forwarding ruleset. An existing corporate DNS design may differ.

### Download and edit the VPN profile

Use the gateway's **Point-to-site configuration > Download VPN client** in
Azure Portal to obtain the Entra/OpenVPN profile. This is one of the remaining
interactive steps; do not select a certificate/RADIUS authentication option
just to generate a different profile with the CLI.

**Local files only:** extract the downloaded ZIP into a new directory:

```powershell
$vpnZip = '<full-path-to-downloaded-vpn-profile.zip>'
$vpnProfileFolder = Join-Path $HOME "Downloads\gpt-rag-vpn-$([guid]::NewGuid().ToString('N'))"
Expand-Archive -LiteralPath $vpnZip -DestinationPath $vpnProfileFolder
Get-ChildItem -LiteralPath $vpnProfileFolder -Recurse -Filter '*.xml' |
    Select-Object FullName
```

Select the Entra profile: normally `AzureVPN\azurevpnconfig.xml`, or
`azurevpnconfig_aad.xml` if the package includes multiple authentication
types. Copy the actual path from the listing:

```powershell
$profilePath = '<full-path-to-the-entra-profile.xml>'
if (Test-Path -LiteralPath "$profilePath.original") {
    throw 'A profile backup already exists. Preserve it and review before editing again.'
}
Copy-Item -LiteralPath $profilePath -Destination "$profilePath.original"
notepad.exe $profilePath
```

The backup deliberately does not overwrite an existing `.original` file.
Keep this profile and its backup outside the repository.

The following is a **profile fragment**, not a complete VPN profile. Replace
the placeholder IP, preserve the authentication settings, and do not add a
second `clientconfig` element. Remove `i:nil="true"` from that element when
populating it.

```xml
<clientconfig>
  <dnsservers>
    <dnsserver>YOUR-DNS-INBOUND-PRIVATE-IP</dnsserver>
  </dnsservers>
  <dnssuffixes>
    <dnssuffix>.services.ai.azure.com</dnssuffix>
    <dnssuffix>.openai.azure.com</dnssuffix>
    <dnssuffix>.cognitiveservices.azure.com</dnssuffix>
    <dnssuffix>.azconfig.io</dnssuffix>
    <dnssuffix>.vault.azure.net</dnssuffix>
    <dnssuffix>.search.windows.net</dnssuffix>
    <dnssuffix>.blob.core.windows.net</dnssuffix>
    <dnssuffix>.azurecr.io</dnssuffix>
    <dnssuffix>.azurecontainerapps.io</dnssuffix>
  </dnssuffixes>
</clientconfig>
```

Treat these namespaces as a starting list. Add those actually used by your
topology, such as Cosmos DB, Azure Monitor, or a custom application domain.
Review the DNS impact on other corporate resources using those namespaces;
do not add a broad suffix such as `.azure.com`.

With this guide's dedicated-VNet defaults, GPT-RAG provisions its private DNS
zones and links them to the VNet in step 7. Do not pre-create duplicate service
zones or links. If your platform team or Azure Policy manages DNS, use the
[existing-platform integration settings](deploy.md#existing-platform-ai-landing-zone-integrated)
with that team instead of mixing the two ownership models.

The VPN client profile does not create DNS records. After provisioning, check
the records needed for ACR data endpoints and the application, not just one
hostname per service.

After saving the XML, **validate the file locally** before importing:

```powershell
$profileXml = [xml](Get-Content -LiteralPath $profilePath -Raw)
$clientConfig = @($profileXml.SelectNodes("/*/*[local-name()='clientconfig']"))
if ($clientConfig.Count -ne 1) { throw 'Expected exactly one clientconfig element.' }
$profileDns = @($clientConfig[0].SelectNodes("*[local-name()='dnsservers']/*[local-name()='dnsserver']"))
if ($profileDns.Count -ne 1 -or $profileDns[0].InnerText -ne $dnsInboundIp) {
    throw 'The VPN profile must contain the selected DNS inbound IP.'
}
```

In **Azure VPN Client**, select **+ > Import**, import the edited profile,
and connect with your Entra account. After any subsequent profile change,
disconnect, reimport that profile, and reconnect. Do not replace the corporate
VPN profile or change your Wi-Fi adapter's DNS.

Complete Entra sign-in interactively. Confirm **Connected**, then **Read**
the local routes and effective DNS policy:

```powershell
Get-NetRoute -AddressFamily IPv4 |
    Where-Object DestinationPrefix -eq $vnetPrefix |
    Format-Table DestinationPrefix, NextHop, InterfaceAlias
Get-DnsClientNrptPolicy -Effective
Resolve-DnsName www.microsoft.com -Server $dnsInboundIp -DnsOnly
Resolve-DnsName www.microsoft.com -Server $dnsInboundIp -DnsOnly -TcpOnly
```

Expect the route to use your VPN interface, NRPT rules to reference the selected
resolver, and both resolver queries to return DNS responses. These public-name
queries test resolver reachability, not private endpoint access.

With Entra authentication, Azure VPN Client uses NRPT. Its DNS settings may
not appear in `ipconfig /all`. Use the resolver's inbound IP, not the
Azure-only DNS address `168.63.129.16`, as the client DNS server.

Before step 7 creates the services and private endpoint records, their names
may be unresolved or resolve publicly. Perform the private service DNS checks
in step 7, after provisioning, rather than treating that earlier result as a
VPN failure.

## 6. Point GPT-RAG at the existing VNet

The VPN and DNS resources now occupy `$resourceGroup`. GPT-RAG must use
**the same group**, not a new group named after `$environment`. The command
`azd env set AZURE_RESOURCE_GROUP $resourceGroup` below saves this selection
in the local environment; `azd provision` later creates the GPT-RAG resources
there. It does not move or recreate the network.

Return to the GPT-RAG root and retrieve the actual VNet ID again rather than
typing one. Run each command separately and stop on failure:

```powershell
Set-Location $repoRoot
$vnetId = az network vnet show --subscription $subscription `
    --resource-group $resourceGroup --name $vnetName --query id --output tsv
if (-not $vnetId) { throw 'The VNet resource ID was not returned.' }
azd env set AZURE_SUBSCRIPTION_ID $subscription
azd env set AZURE_RESOURCE_GROUP $resourceGroup
azd env set AZURE_LOCATION $region
azd env set NETWORK_ISOLATION true
azd env set USE_EXISTING_VNET true
azd env set EXISTING_VNET_RESOURCE_ID $vnetId
azd env set DEPLOY_SUBNETS true
azd env set SIDE_BY_SIDE false
azd env set DEPLOYMENT_TOPOLOGY hosted-no-panel
azd env set DEPLOY_ACR_TASK_AGENT_POOL true
```

Confirm the saved group before proceeding:
`azd env get-value AZURE_RESOURCE_GROUP` must return your `$resourceGroup`
value (for example, `rg-gpt-rag-private`). `EXISTING_VNET_RESOURCE_ID` must
identify the VNet you just inspected in that group, not another corporate VNet.

`DEPLOY_SUBNETS=true` assumes a dedicated VNet with room for the GPT-RAG subnets.
Do not apply this setting to a shared VNet without reviewing the affected
resources. Explicit `hosted-no-panel` selection avoids depending on how an
environment with pre-existing resources is classified.

### Keep the host setting unset for the candidate VPN workflow

For the planned `v3.8.5` workflow, leave `RUN_FROM_JUMPBOX` **unset**, not
`false`. **On a fresh installation, simply never set this key and skip the
removal instructions below.** Existing `true` remains compatible with the
candidate checks, but is unnecessary and never bypasses them.

**Migration/resume only:** if you reused a jumpbox configuration and want the
VPN workflow below, remove the entire `RUN_FROM_JUMPBOX=...` line from the
selected **root checkout's** `.azure\$environment\.env`. Do not replace `false`
with an empty value. Preserve every unrelated key and secret; do not remove
the environment directory or edit child, registry, user, or machine settings.
Open only that local file:

```powershell
$azdEnvFile = Join-Path $repoRoot ".azure\$environment\.env"
if (-not (Test-Path -LiteralPath $azdEnvFile)) {
    throw 'Select the intended local azd environment before editing its settings.'
}
notepad.exe $azdEnvFile
```

After removing that key if present, **save and close the editor**, then check
without displaying the rest of the file, which can contain sensitive values.
Clear the same key from this PowerShell process if an earlier session step set it:

```powershell
if (Select-String -LiteralPath $azdEnvFile -Pattern '^\s*RUN_FROM_JUMPBOX\s*=' -Quiet) {
    throw 'Remove only RUN_FROM_JUMPBOX from the selected .env file, then save it.'
}
if (Test-Path Env:RUN_FROM_JUMPBOX) {
    Remove-Item Env:RUN_FROM_JUMPBOX
}
```

No output and no error means the selected root file check passed and this
process key is absent. These commands change no global settings.
`azd env remove` removes an environment, not one key; do not use it here.

Use `AZURE_SKIP_NETWORK_ISOLATION_WARNING` to control the infrastructure-only
phases below. In the candidate implementation, `RUN_FROM_JUMPBOX=false`, `0`,
`no`, or `skip` explicitly defers post-provision configuration; it does not
mean "run from my local machine." A truthy jumpbox value takes precedence over
the warning/deferral setting, but never bypasses the actual network checks.
Leaving it unset avoids both ambiguities.

Provisioning supplies `ACR_TASK_AGENT_POOL` with the created pool's name.
Do not pre-fill that output to make a missing pool appear configured.

**Local file change only:** the following block backs up the root
`main.parameters.json` inside the ignored `azd` environment directory, then
updates only its network parameter values. Adapt every workload prefix if you
changed the example VNet range. It preserves the other parameters and does not
edit `infra` or `manifest.json`.

```powershell
$networkParameters = @{
    vnetAddressPrefixes = @($vnetPrefix)
    agentSubnetPrefix = '10.80.0.0/24'
    acaEnvironmentSubnetPrefix = '10.80.1.0/24'
    peSubnetPrefix = '10.80.2.0/26'
    azureBastionSubnetPrefix = '10.80.2.64/26'
    azureFirewallSubnetPrefix = '10.80.2.128/26'
    gatewaySubnetPrefix = '10.80.2.192/26'
    azureAppGatewaySubnetPrefix = '10.80.3.0/27'
    jumpboxSubnetPrefix = '10.80.3.64/27'
    devopsBuildAgentsSubnetPrefix = '10.80.3.96/27'
}
$parameterPath = Join-Path $repoRoot 'main.parameters.json'
$backupPath = Join-Path $repoRoot ".azure\$environment\main.parameters.before-vpn.json"
if (Test-Path -LiteralPath $backupPath) {
    throw 'A parameter backup already exists. Review it before editing again.'
}
$parameters = Get-Content -LiteralPath $parameterPath -Raw | ConvertFrom-Json -AsHashtable
if ($parameters.parameters -isnot [System.Collections.IDictionary]) {
    throw 'The root file does not contain a parameters object.'
}
Copy-Item -LiteralPath $parameterPath -Destination $backupPath
foreach ($name in $networkParameters.Keys) {
    $parameters.parameters[$name] = @{ value = $networkParameters[$name] }
}
$parameters | ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $parameterPath -Encoding utf8NoBOM
git diff -- main.parameters.json
```

Review the diff before provisioning. JSON formatting may change, but parameter
values outside this network list must remain unchanged.

The infrastructure's `gateway-subnet` is **not** the VPN's `GatewaySubnet`.
Keep their names and address ranges separate.

These are deployment settings, not component-version changes. Do not edit the
managed `infra` source or change the release manifest. Avoiding VM login also
does not automatically remove VM/Bastion resources from the selected topology.
Review their supported deployment options and cost separately.

## 7. Provision infrastructure and verify connectivity

**Candidate `v3.8.5` workflow:** follow this sequence only with a published
release containing the host checks described in step 8.

Proceed only after reviewing the deployment-host requirement in step 8, the
proposed resource costs, and the network plan.

Separate infrastructure provisioning from data-plane configuration:

```powershell
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING true
azd provision --preview
```

Here, `AZURE_SKIP_NETWORK_ISOLATION_WARNING=true` deliberately defers local
data-plane post-provisioning. It does **not** skip security requirements or
prove connectivity. With `RUN_FROM_JUMPBOX` unset as above, the candidate hook
reports the explicit deferral instead of trying private service configuration.
Preview can run hooks and prepare local files.

Review subnet changes, private endpoints, DNS, NSGs, Firewall, quotas, the
private ACR build pool, and preservation of the VPN and resolver subnets.
Stop on unexpected changes or preflight errors; do not bypass them.

After approval, provision the resources:

```powershell
azd provision
```

Wait for its final result. An ARM provisioning failure is not the same as
successfully provisioning infrastructure with data-plane setup deferred.
Use the separate phases rather than `azd up`, so you can check connectivity
between them.

**Read:** inspect only the relevant output values; do not dump all environment
values into a shared log:

```powershell
azd env get-value AZURE_RESOURCE_GROUP
azd env get-value APP_CONFIG_ENDPOINT
azd env get-value ACR_TASK_AGENT_POOL
az network vnet subnet list --subscription $subscription `
    --resource-group $resourceGroup --vnet-name $vnetName `
    --query '[].{name:name,prefix:addressPrefix,routeTable:routeTable.id}' --output table
```

Expect your selected resource group, a nonempty configuration endpoint, and
the provisioned private build-pool name. A missing output is a stop condition,
not a reason to invent its value.

### Check the return route to VPN clients

The local machine must reach the services, and those services must have a
return path to the P2S client pool.

Inspect the actual route tables associated with the GPT-RAG workload subnets.
Record their routes, subnet associations, and gateway route
propagation settings. With this guide's default Firewall configuration, the
deployment creates a workload route table with gateway route propagation
disabled and a default route through Azure Firewall. Expect to need an explicit
P2S return route; confirm the actual route table and have the network owner
review any existing return path before adding one.

For the single-VNet, route-based VPN scenario in this guide, an approved
missing return route can be added as follows:

| Field | Value |
| --- | --- |
| Name | An unused name, for example `return-to-p2s` |
| Destination prefix | Your actual P2S client pool; `10.81.0.0/24` in this example |
| Next hop type | **Virtual network gateway** |
| Next hop address | Not applicable |

Do not overwrite conflicting routes, replace the default Firewall route, or
attach the workload route table to `GatewaySubnet` or the DNS inbound subnet.
The next hop is not the gateway's public IP.

**Read:** pick the relevant workload subnet from the preceding list, then
retrieve its actual table. Repeat this review if workloads use different
tables; do not select the first route table in the resource group.

```powershell
$workloadSubnet = '<workload-subnet-name-from-the-list>'
$routeTableId = az network vnet subnet show --subscription $subscription `
    --resource-group $resourceGroup --vnet-name $vnetName --name $workloadSubnet `
    --query routeTable.id --output tsv
if (-not $routeTableId) { throw 'No route table is attached. Review the network design.' }

$routeTable = az network route-table show --ids $routeTableId --output json | ConvertFrom-Json
$routeTable | Select-Object name, disableBgpRoutePropagation
$routeTable.subnets | Select-Object id
$routeTable.routes | Select-Object name, addressPrefix, nextHopType, nextHopIpAddress
```

**Write, only for an approved missing route:** the block below refuses to
replace a conflicting prefix or name and leaves an existing correct route
unchanged. It never changes propagation, subnet associations, or other routes.

```powershell
$routeName = 'return-to-p2s'
if (@($routeTable.subnets | Where-Object {
    $_.id -like '*/subnets/GatewaySubnet' -or $_.id -like "*/subnets/$dnsSubnetName"
}).Count -gt 0) {
    throw 'This table is attached to a VPN or DNS subnet. Stop for network review.'
}
$poolRoutes = @($routeTable.routes | Where-Object addressPrefix -eq $p2sPool)
$nameRoutes = @($routeTable.routes | Where-Object name -eq $routeName)
if ($poolRoutes.Count -eq 1 -and $poolRoutes[0].nextHopType -eq 'VirtualNetworkGateway') {
    Write-Host 'The P2S return route already exists; no change needed.'
} elseif ($poolRoutes.Count -gt 0 -or $nameRoutes.Count -gt 0) {
    throw 'A conflicting route exists. Do not overwrite it.'
} else {
    $routeIdParts = $routeTableId -split '/'
    $routeSubscription = $routeIdParts[2]
    $routeGroup = $routeIdParts[4]
    az network route-table route create --subscription $routeSubscription `
        --resource-group $routeGroup --route-table-name $routeTable.name `
        --name $routeName --address-prefix $p2sPool `
        --next-hop-type VirtualNetworkGateway --output none
}

az network route-table show --ids $routeTableId `
    --query '{propagationDisabled:disableBgpRoutePropagation,subnets:subnets[].id,routes:routes[].{name:name,prefix:addressPrefix,nextHop:nextHopType,ip:nextHopIpAddress}}' `
    --output json
```

Compare the final read with the preceding inventory. Expect the client-pool
route through `VirtualNetworkGateway`, with the Firewall default route and
subnet associations unchanged.

Test the application and build-pool paths separately from service private
endpoints. A successful private endpoint connection alone does not prove that
all workload return paths are correct.

**Recheck this route after every provision**, including the second hosted
provisioning phase. A manually added route is outside the release's
infrastructure definition and may not survive reprovisioning.

### Test DNS and private service access

Use each service's original endpoint hostname, obtained from its Azure resource
or deployment outputs. Do not replace it with an IP address or a `privatelink`
hostname in application URLs.

```powershell
$serviceFqdn = '<actual-service-hostname>'

Resolve-DnsName $serviceFqdn -Server $dnsInboundIp -DnsOnly
Resolve-DnsName $serviceFqdn -Server $dnsInboundIp -DnsOnly -TcpOnly
Resolve-DnsName $serviceFqdn
Test-NetConnection -ComputerName $serviceFqdn -Port 443
```

Compare the DNS result with the expected private address. The test **without
`-Server`** is essential: it checks the DNS path applications normally use.
Repeat for the services your topology needs, including Foundry, App
Configuration, Key Vault, Search, Blob, ACR, and the application endpoint when
available.

TCP success is not a TLS or authorization test. Also perform an appropriate
authenticated, read-only HTTPS operation against each required service using
an authorized identity. Do not disable certificate validation or print tokens
and secret values. Investigate a 401/403 against both the service's network
restrictions and its authentication/authorization requirements.

For example, after infrastructure provisioning, these **Read** commands test
authenticated App Configuration and Blob access without reading secret values
or downloading documents:

```powershell
$appConfigEndpoint = azd env get-value APP_CONFIG_ENDPOINT
az appconfig kv list --subscription $subscription --endpoint $appConfigEndpoint `
    --auth-mode login --key SUBSCRIPTION_ID --label gpt-rag `
    --query '[].{key:key,label:label}' --output json

$storageAccount = '<actual-storage-account-name>'
$documentsContainer = '<approved-source-container-name>'
az storage container exists --account-name $storageAccount `
    --name $documentsContainer --auth-mode login --query exists --output tsv
```

Before post-provision configuration, the App Configuration key may not exist:
an authorized empty list is not a configuration failure, but it does not prove
that setup is complete. The container check must return `true` for the expected
container. Both commands use **your user identity**, not the hosted agent's;
they do not prove the agent has its own permissions.

## 8. Continue the GPT-RAG installation

### Configure services over the VPN

**Candidate `v3.8.5` behavior:** the post-provision script checks actual private
connectivity instead of asking whether you are on the VPN. An unset
`RUN_FROM_JUMPBOX` no longer causes an interactive prompt or an automatic skip
in a noninteractive session. After checking the return route and services in
step 7, clear the explicit deferral and run from the repository root:

```powershell
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
if ($LASTEXITCODE -ne 0) { throw 'Could not enable data-plane configuration.' }
.\scripts\postProvision.ps1
```

Expect the App Configuration host check to succeed before data-plane
configuration starts, then wait for the script's successful completion.
This script configures Azure services; it is not a read-only diagnostic.
If it reports deferral, configuration has **not** run: check both the saved
and process settings above. If a host check fails, fix DNS/routing/TLS before
retrying; do not disable validation.

### Check the deployment host before building or deploying

The planned `v3.8.5` host checks apply when `NETWORK_ISOLATION=true`. They use
the operating system's normal DNS resolution, require only RFC1918 private
IPv4 destinations (`10.0.0.0/8`, `172.16.0.0/12`, or `192.168.0.0/16`), then
check TCP 443 and normal TLS certificate/hostname validation with SNI for the
original service hostname. The checks do not send Azure credentials or an
authenticated application request.

| Candidate phase | Endpoint checked before that phase's protected operation |
| --- | --- |
| Post-provision configuration | `APP_CONFIG_ENDPOINT` |
| Pre-deploy | App Configuration; also the configured Foundry endpoint for hosted deployment |
| Hosted image build | The actual ACR endpoint selected for the build |

Public mode (`NETWORK_ISOLATION=false`) does not run these private-host probes.
Reusing an existing image digest or supplying a prebuilt digest avoids an
unnecessary hosted-build ACR probe; it does not bypass checks needed by later
deployment phases. A missing/invalid endpoint, public or mixed DNS result,
certificate failure, or timeout stops the guarded phase before its writes.
`RUN_FROM_JUMPBOX=true` is not proof of connectivity and never bypasses these
checks. There is no instruction to skip TLS validation, use a proxy bypass,
or fall back to public service endpoints.

These checks establish only the tested host-to-endpoint DNS/TCP/TLS path.
They do not establish RBAC, API health, ownership of the Azure VNet, connectivity
for every service, the remote build pool's outbound access, or success of a
fresh GPT-RAG installation. Keep the separate authorized service checks in
step 7 and the runtime/document authorization checks below.

**Historical `v3.8.4`:** its pre-deploy hook still requires
`RUN_FROM_JUMPBOX=true`. Do not use that flag locally as a workaround. Wait
for the published host-check release before following this candidate local
build/deploy sequence.

### Prepare the hosted image, then provision again

Follow the [hosted deployment lifecycle](deploy.md#two-phase-hosted-deployment).
The following are **Write/build operations**, not read-only connectivity tests.
Stay connected to the VPN, keep `RUN_FROM_JUMPBOX` unset, and use the same
released source, local environment, and resource group throughout:

```powershell
Set-Location $repoRoot
azd env get-value ACR_TASK_AGENT_POOL
.\scripts\prepareHostedDeployment.ps1
if ($LASTEXITCODE -ne 0) { throw 'Hosted image preparation failed.' }
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING true
azd provision
```

The deferral is restored **before the second `azd provision`** because that
provision can replace a manually added P2S return route. It prevents automatic
data-plane configuration before you have rechecked the network; it does not
undo the image preparation or move resources to another group.

Stop and repeat the route and connectivity checks in step 7 after that
provision. Once the expected return path and private service access are
confirmed, clear deferral and rerun configuration before deployment:

```powershell
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
if ($LASTEXITCODE -ne 0) { throw 'Could not re-enable data-plane configuration.' }
.\scripts\postProvision.ps1
if ($LASTEXITCODE -ne 0) { throw 'Post-provision configuration did not complete.' }
```

Continue only when configuration completes successfully:

```powershell
azd deploy
```

Expected outcome: the pre-deploy checks pass and the deployment proceeds to
its normal service operations. A passed host check alone is not a successful
deployment. A fresh automated live installation/bootstrap/smoke run has not
been performed for this candidate; that acceptance remains separate.

Use the VNet-connected ACR build pool for private builds. Your local VPN
connection does not make shared ACR Tasks able to reach private resources.
Do not switch to public endpoints to make a failed private build succeed.

## 9. Understand which permissions GPT-RAG grants automatically

**The hosted runtime permission fix is included starting with GPT-RAG
`v3.8.4`.** You do not normally need to add these runtime grants manually
before deploying. After creating the hosted agent, its post-deploy hook
discovers the actual **agent instance identity** and applies the following
minimum roles:

| Purpose | Automatically assigned role | Scope |
| --- | --- | --- |
| Read application configuration | App Configuration Data Reader | The configured App Configuration store |
| Call the configured Azure OpenAI models | Cognitive Services OpenAI User | The configured model account |
| Read the audit-signing secret, when its Key Vault reference is configured | Key Vault Secrets User | That individual referenced secret, not the entire vault |

The last grant is conditional: no audit-secret reference means no secret grant
and no secret creation. Bootstrap inspects reference metadata; it does not
retrieve or log the secret value.

These grants belong to `instance_identity.principal_id` on the deployed agent,
not to your user account, the Foundry project identity, or a Container App
identity. The deployment operator needs discovery access and permission to
create role assignments at those scopes. The VPN provides neither.

The hook reuses matching unconditional grants on repeat runs. Conflicting
conditional grants cause a failure instead of being bypassed. Root deployment
waits for bootstrap and a completed `Hello!` response before UI cutover.
Direct child deployment applies the roles but does not run the greeting.
Role visibility in Azure Resource Manager does not prove data-plane
propagation; use the documented recovery flow if the greeting fails.

See [Plan and recover hosted access](deploy.md#plan-and-recover-hosted-access)
for the read-only `--plan` command and explicit recovery procedure.
A successful plan can still report missing grants; inspect
`exact_unconditional_assignment`. Its `data_plane_readiness=not-tested` result
is not an application health check.

**Read, after the hosted agent exists:** from the repository root, select
the environment and inspect its runtime permission plan. The module reads the
hosted child project's saved `azd` environment; it cannot inspect an agent
that has not been deployed yet.

```powershell
Set-Location $repoRoot
$savedPythonPath = $env:PYTHONPATH
$savedAzureEnvName = $env:AZURE_ENV_NAME
try {
    $env:PYTHONPATH = $repoRoot
    $env:AZURE_ENV_NAME = $environment
    Push-Location (Join-Path $repoRoot 'hosted-agent')
    try {
        $accessPlan = python -m config.deployment.hosted_access --azd-env --plan |
            ConvertFrom-Json
    } finally {
        Pop-Location
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:AZURE_ENV_NAME = $savedAzureEnvName
}
$accessPlan | Select-Object agent_name, agent_version, audit, data_plane_readiness
$accessPlan.grants | Select-Object role, scope, exact_unconditional_assignment
```

Expect two runtime grants, or three when the audit-secret reference is
configured. Missing grants require investigation of the deployment hook or
the documented recovery procedure, not broader access. Keep the output private:
it contains deployment resource identifiers. Do not run manual `--apply` before
testing whether a fresh deployment applies these roles automatically.

### Search and Blob permissions are separate

**Search and Blob document-access grants are not added by this bootstrap.**
They authorize access to content, rather than just starting the application.
Choose and approve the retrieval authorization model before uploading real data.

For an explicitly approved **service-identity test against a Blob knowledge
source**, the hosted agent may need:

| Purpose | Role | Reviewed scope |
| --- | --- | --- |
| Query the configured Search service | Search Index Data Reader | The actual Search service used for retrieval |
| Read the approved source documents | Storage Blob Data Reader | Only the approved source container |

This is a scoped test pattern, not a universal grant recipe for every grounding
source. Confirm the consuming identity for your retrieval configuration and
follow the [application/document identity guidance](howto_authentication.md#hosted-application-identity-versus-document-identity).
Do not substitute the Foundry project identity or grant broad roles to fix an
unexplained 403.

A Search-service grant is not restricted to one test index, and a container
grant covers future documents placed in that container. In a service-identity
retrieval flow, application callers can receive content the agent is allowed
to retrieve; this does **not** prove per-user document authorization or OBO.
Test allowed and denied users separately before enabling protected content.

#### Optional commands for an approved synthetic-content test

**Skip this subsection unless document access has been explicitly approved.**
It is separate from installation and from the automatic-bootstrap test. Use
the actual agent principal returned by the preceding read-only plan. These
examples assume the reviewed Search service and Storage account are in the
dedicated resource group used by this guide.

**Read:** resolve the exact resource scopes and inspect existing assignments.
Replace the names with the resources actually used for retrieval, not another
Search service associated with the Foundry project.

```powershell
if (-not $accessPlan.principal_id -or $accessPlan.classic) {
    throw 'A valid hosted access plan is required.'
}
$agentPrincipalId = $accessPlan.principal_id
$searchService = '<actual-search-service-used-for-retrieval>'
$storageAccount = '<actual-storage-account-name>'
$documentsContainer = '<approved-synthetic-source-container>'
$searchScope = az search service show --subscription $subscription `
    --resource-group $resourceGroup --name $searchService --query id --output tsv
$containerScope = az storage container-rm show --subscription $subscription `
    --resource-group $resourceGroup --storage-account $storageAccount `
    --name $documentsContainer --query id --output tsv
if (-not $searchScope -or -not $containerScope) {
    throw 'Could not resolve the reviewed Search or container scope.'
}

$documentGrants = @(
    @{ scope = $searchScope; role = '1407120a-92aa-4202-b7e9-c0e197c71c8f' }
    @{ scope = $containerScope; role = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' }
)
foreach ($grant in $documentGrants) {
    az role assignment list --subscription $subscription `
        --assignee-object-id $agentPrincipalId --scope $grant.scope --include-inherited `
        --fill-principal-name false --fill-role-definition-name false `
        --query '[].{principal:principalId,role:roleDefinitionId,scope:scope,condition:condition,conditionVersion:conditionVersion}' `
        --output json
}
```

The role IDs identify **Search Index Data Reader** and **Storage Blob Data
Reader**, respectively. Review inherited and conditional access as well as
direct grants. Do not create another assignment to bypass a condition, or add
a redundant grant where approved existing access already suffices.

**Write:** only an authorized access administrator should run the next block
after reviewing the identity, scopes, existing access, and test content. It
defaults to refusing the operation. Change the approval switch only for this
explicitly approved test; do not include this block in unattended installation.

```powershell
$documentAccessApproved = $false
if (-not $documentAccessApproved) {
    throw 'Document access has not been approved. No role assignments were created.'
}
# Run only the command for a reviewed, missing grant.
az role assignment create --subscription $subscription `
    --assignee-object-id $agentPrincipalId --assignee-principal-type ServicePrincipal `
    --role '1407120a-92aa-4202-b7e9-c0e197c71c8f' --scope $searchScope --output none

az role assignment create --subscription $subscription `
    --assignee-object-id $agentPrincipalId --assignee-principal-type ServicePrincipal `
    --role '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' --scope $containerScope --output none
```

Repeat the preceding **Read** loop to confirm the assignments. Then allow for
RBAC propagation and test only synthetic content. Do not broaden the scopes
if access still fails. Track test grants separately for later authorized
cleanup; do not remove the runtime grants maintained by bootstrap.

## 10. Check the result and operate safely

Keep the checks distinct:

| Check | What it establishes |
| --- | --- |
| VPN connected | The tunnel is established. |
| Original service name resolves to the expected private IP | DNS selects the intended private destination. |
| TCP/TLS and an authenticated service read succeed | The tested path and authorized operation work. |
| Agent greeting completes | The tested configuration/model path works. |
| A synthetic document query returns a grounded answer | That retrieval path works for the tested identity. |
| Allowed users succeed and denied users are refused | The tested document-authorization boundary is enforced. |

Troubleshoot the failing layer rather than granting broader permissions:

| Symptom | Check next |
| --- | --- |
| VPN connection fails | Gateway state, profile, Entra audience, user access, and Conditional Access |
| DNS works only with explicit `-Server` | Client profile, effective NRPT policy, DNS cache, and other VPN clients |
| A private service resolves publicly | DNS suffixes, zone links, and private endpoint records |
| Private DNS is correct but TCP fails | Forward/return routes, P2S pool, NSGs, and Firewall |
| Access breaks after provisioning | Return route, subnet associations, DNS, and private endpoint state |
| Authenticated requests return 403 | Service network restrictions, token audience, identity, and operation-specific RBAC |
| Remote image build fails | Build-pool connectivity, DNS, and approved outbound dependencies |
| Deploy requests `RUN_FROM_JUMPBOX` | Check the selected release: `v3.8.4` has the old gate; planned `v3.8.5` uses actual host checks. Do not fake the flag or mix development files into a release. |
| Candidate host check rejects public/mixed DNS, TLS, or a timeout | Correct the original endpoint, OS DNS/NRPT, private routes, and certificate trust. A TCP-only test is insufficient; do not disable TLS validation. |
| Candidate post-provision reports deferral | Keep `RUN_FROM_JUMPBOX` unset and clear `AZURE_SKIP_NETWORK_ISOLATION_WARNING` only after route/service checks. `RUN_FROM_JUMPBOX=false` is also an explicit defer, not a local-host selector. |

Disconnect the VPN when it is no longer needed. This does not delete resources
or stop their charges. Plan cleanup separately with the resource owners; do
not run an indiscriminate teardown against a shared network.

## References

- [GPT-RAG deployment guide](deploy.md)
- [Latest stable GPT-RAG release](https://github.com/Azure/GPT-RAG/releases/latest)
- [Configure P2S with Microsoft Entra ID](https://learn.microsoft.com/azure/vpn-gateway/point-to-site-entra-gateway)
- [Azure VPN Client: optional DNS and routing settings](https://learn.microsoft.com/azure/vpn-gateway/azure-vpn-client-optional-configurations)
- [Azure DNS Private Resolver endpoints](https://learn.microsoft.com/azure/dns/private-resolver-endpoints-rulesets)
- [Azure virtual network traffic routing](https://learn.microsoft.com/azure/virtual-network/virtual-networks-udr-overview)
