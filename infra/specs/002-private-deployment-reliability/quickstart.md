# Quickstart: Validate the two implementation slices

This guide describes validation scenarios, not blanket claims of executed
evidence. Both focused contract scripts are included in the implementation;
actual results and pending operational cases are recorded in [tasks.md](tasks.md).
Run from the repository root using PowerShell 7; command paths use Windows syntax.

## 1. Prerequisites and baseline

Complete the `main` -> `develop` synchronization in [the plan](plan.md), use the
reviewed implementation revision, and record its SHA. Have Azure CLI Bicep
0.42.1 available for the current graph fixture, with access to the public
Bicep registry for module restoration. A different compiler requires an
explicit fixture/tool decision, not automatic hash regeneration.

```powershell
git rev-parse HEAD
az bicep version
```

For offline contracts, no Azure deployment credentials are required. For live
work, separately obtain an approved tenant/subscription/RG/region, deployment
identity, budget and cleanup owner. Check current ACR pool availability/capacity
and required egress. Repository test-environment examples are not authorization
to use their subscription or shared hub.

## 2. Local deterministic checks after implementation

Run commands in order and stop on a nonzero exit. First require the new tests:

```powershell
if (!(Test-Path .\tests\contracts\Test-AcrTaskAgentPoolSubnetContract.ps1) -or
    !(Test-Path .\tests\contracts\Test-SolutionStorageAccessContract.ps1)) {
    throw 'Both private-deployment contract scripts are required; use the implementation revision.'
}
az bicep build --file .\main.bicep
az bicep lint --file .\main.bicep
pwsh .\scripts\Measure-MainJsonSize.ps1 -SkipBuild
pwsh .\tests\contracts\Test-AcrTaskAgentPoolSubnetContract.ps1
pwsh .\tests\contracts\Test-SolutionStorageAccessContract.ps1
pwsh .\tests\contracts\Test-HostedAgentContract.ps1
pwsh .\tests\contracts\Test-AcrTaskAgentPoolFirewallContract.ps1
pwsh .\tests\contracts\Test-ComponentDeploymentFlagsContract.ps1
pwsh .\tests\scripts\Invoke-PreflightChecks.Tests.ps1
```

The size check measures the file just built by Azure CLI. This avoids using
the older standalone compiler observed during planning. Keep script defaults;
do not raise the threshold to make the change pass.

Expected: both focused matrices pass; the graph differs only in reviewed
mutations; existing firewall/component/preflight contracts pass. New tests must
also demonstrate failure when their fix is removed or a forwarded value is
hardcoded/dropped. Record warnings rather than suppressing them. These tests
do not establish Azure deployment or scanning success.

## 3. Configure a live scenario and preview

Use a complete, operator-reviewed parameter overlay and authenticated azd
environment. The JSON fragments in the [Storage contract](contracts/solution-storage-inputs.md)
are only additions to a complete parameter file. Preserve secure password
resolution and required existing lists/identity inputs; do not commit live IDs
or credentials. Native parameter values must reach the actual deployment
file, not merely exist in an unused sidecar file.

For A1 choose isolation, BYO VNet, subnet creation, NSGs, registry and pool
enabled; S1 tier and count 1. Verify the build subnet is absent and snapshot
unrelated subnets. Preserve current firewall/DNS requirements.

For S3 use `None`, `false`, `[]`, isolation enabled, and empty `allowedIpRanges`.
For S4 start with already-enabled, approved Defender and supply its exact rule.
Do not enable Defender to make this scenario possible without separate approval.

Run the existing read-only preflight and preview on the selected environment:

```powershell
pwsh .\scripts\Invoke-PreflightChecks.ps1
azd provision --preview
```

Expected: correct resource scopes and conditions; no unexpected deletion,
replacement, broad public exposure, Defender enablement or unrelated subnet
mutation. Review Azure Policy effects. Do not bypass preflight findings.
What-If may not fully expand nested expressions; unknown results are not proof
of the expected effective account values.

## 4. Approved cold-start proof for #159

Only after explicit authorization for this exact environment:

```powershell
azd provision
```

In Azure deployment operations, capture the successful completion time of
`virtualNetworkSubnetsDeployment` and the pool's start time. Confirm pool
`provisioningState=Succeeded`, requested tier/count and observed count 1.
The acceptance condition is completion of subnet creation before pool start,
not simply that both resources eventually exist.

Compare unrelated subnet configuration before/after as defined in
[the ACR contract](contracts/acr-subnet-ordering.md). Repeat compatibility
scenarios A2/A3 in separately approved scopes and preview disabled paths A4-A6.
A8 must retain its existing rejection. A9 covers retained cross-scope behavior.
If the initial attempt fails, keep its evidence; a successful retry is not
cold-start success. Investigate egress/capacity/identity failures separately.

## 5. Repeated-deployment proof for #160

For each approved S3/S4 environment, deploy once, record solution Storage ARM
properties, and repeat `azd provision` with exactly the same reviewed inputs.
Compare after both runs:

| Property | Expected |
| --- | --- |
| `networkAcls.bypass` | `None` for the explicit profile. |
| `allowSharedKeyAccess` | `false`, distinguishing any Azure Policy effects. |
| `networkAcls.resourceAccessRules` | Exactly the supplied ID/tenant pairs, no missing or extra rules. Compare as a set if the provider reorders them. |
| PNA/default action/IP rules | Existing topology-derived values, not inferred from bypass. |
| Auxiliary Storage / roles / Defender resources | No changes introduced by these inputs. |

Also exercise omitted/default profiles and standard/IP-exception scenarios
S1/S2/S7; confirm S8 skips solution Storage and S9 is rejected by typed
validation. Exact rule retention is the acceptance test, not a manual repair
between deployments.

## 6. Authentication and optional scanner verification

Before migrating an existing account, inventory key-based connection strings,
service/account SAS and any file consumers. From an authorized network/client,
verify Entra access (and Blob user-delegation SAS if used); confirm key-based
requests are denied for the false profile. Reuse approved client tooling and
never capture keys in logs. Confirm the deployment identity can complete
the unchanged AVM, including retained secure-output `listKeys()` expressions.

For already-enabled Defender only, follow the
[official test guide](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-storage-test)
under separate operational approval. Observe scan results through configured
events/logs/alerts and, where applicable, scan tags. ACL equality does not prove
scanner health; editable tags alone are not strong integrity evidence.
Record scanning as pass/fail/not run separately from network-rule preservation.

## 7. Evidence handoff and cleanup

Attach sanitized commit/compiler/inputs, commands and exit codes, warnings,
preview review, deployment operation ordering, repeated Storage comparisons,
consumer results and optional scanning results. Mark unexecuted checks and
remaining issue acceptance explicitly; never describe the plan as passing them.

Cleanup, pool scale-down and deleting test resources are separate approved
operator actions. Never delete a shared BYO VNet or a scanner just because
the test has finished. Use the migration/rollback constraints in the ADR.
