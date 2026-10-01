# Contract: ACR Task agent-pool subnet ordering

Proposed change for [#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159).

## Invariant

An enabled `acrTaskAgentPool` cannot start before successful completion of an
enabled `virtualNetworkSubnets` deployment. Add the module symbol to the pool's
explicit dependencies. ARM discards it when the conditional module is skipped;
compiled JSON can still contain the symbolic edge.

Do not dereference disabled-module outputs. Retain the existing pool condition,
parent registry, VNet-derived implicit dependency, subnet ID, tier/count/OS,
output fallback and firewall contract.

## Scenario matrix

Other inputs must remain valid under existing component/preflight contracts.

| ID | Configuration | Required outcome |
| --- | --- | --- |
| A1 | Isolation, BYO VNet, subnet/NSG creation, registry and pool enabled | Compiled BYO edge; live fresh subnet completes before pool start; S1 / 1 succeeds without retry. |
| A2 | Same, but `deploySubnets=false` and build subnet exists | Subnet module skipped; existing subnet used; no unavailable-output evaluation. |
| A3 | Isolation with template-created VNet and pool enabled | Existing implicit VNet completion dependency preserved. |
| A4 | `deployAcrTaskAgentPool=false` | No pool; empty pool output/handoff preserved. |
| A5 | `deployContainerRegistry=false`, pool requested | Effective pool gate remains false. |
| A6 | `networkIsolation=false`, pool requested | Effective pool gate false; standard resources valid. |
| A7 | A1/A2 with requested count 0 | Count remains 0; no forced scale-up. |
| A8 | Isolation + BYO subnet creation + `deployNsgs=false` | Existing invalid-combination protection remains effective. |
| A9 | Authorized BYO VNet in another RG/subscription | Dependency targets the orchestrating module; existing child deployment scopes unchanged. |

## Deterministic evidence

The proposed `Test-AcrTaskAgentPoolSubnetContract.ps1` compiles real
`main.bicep`, inspects symbolic resources and exact dependency entries, and
checks relevant gate expressions against the table. It must fail against the
pre-fix template and when the new edge is removed.

Protect registry/new-VNet dependencies, unchanged subnet ID, count/tier
forwarding and disabled outputs. Verify subnet creation continues to use
serialized child operations; do not replace a VNet's complete subnet collection
to establish ordering.

Allow only `acrTaskAgentPool` as this slice's extra graph-fixture mutation.
Keep the firewall contract active. A fixture exemption alone proves nothing
about correctness or Azure deployment success.

## Live evidence and ownership

Use an approved disposable BYO VNet with an initially absent build subnet.
Capture operation timestamps, subnet state, pool provisioning state and
requested/observed workers. A retry after subnet creation is A2, not A1 evidence.

Compare unrelated subnets before/after: prefixes, NSGs, delegation, routes,
NAT and service endpoints unchanged. Exclude only provider-maintained metadata
such as etags. No recovery deletion or broad VNet update is authorized.

Capacity, region, egress and identity failures remain distinct causes; passing
the ordering test must not mask them.
