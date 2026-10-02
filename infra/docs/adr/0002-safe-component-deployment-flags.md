# ADR-0002: Fail fast on unsafe component deployment flags

- Status: proposed
- Date: 2026-08-20
- Owners: AI Landing Zone maintainers
- Related issue or pull request: pull request #126

## Context

The landing zone exposes `deployCosmosDb`, `deployContainerApps`,
`deployContainerRegistry`, `deployContainerEnv`, and `deployNsgs` through azd
environment variables. Operators need to omit components without editing
`main.parameters.json`, while preserving the existing all-enabled defaults.

The flags are not independent. Container Apps dereference the Container Apps
Environment. An environment-only isolated deployment still needs the Container
Apps private DNS zone. Container App API-key publication requires deployed apps,
Key Vault, App Configuration, and `appConfig` runtime mode. Updating subnets in
an existing VNet with `deployNsgs=false` sends a null NSG association and can
detach an existing control.

ARM resource-group deployments are incremental. A resource omitted after a flag
changes to `false` is not deleted, and previously published App Configuration
keys may remain. The affected contracts are `main.bicep`,
`main.parameters.json`, deterministic preflight, Container Apps private DNS,
Key Vault secrets, App Configuration references, and operator documentation.

## Prioritized characteristics

| Characteristic | Priority | Measure |
| --- | --- | --- |
| Network safety | 1 | Existing subnet NSG associations cannot be detached by an accepted flag combination. |
| Deterministic failure | 2 | Invalid dependencies fail in offline preflight and at ARM deployment start. |
| Backward compatibility | 3 | Omitted flags retain the existing all-enabled graph and secure Foundry local-auth default. |
| Explicit operator intent | 4 | Valid explicit values are not silently overridden or derived. |
| Operational clarity | 5 | Documentation distinguishes creation selection from deletion and cleanup. |

## Alternatives considered

### Reject invalid combinations and defensively gate dependent artifacts

Keep the public Boolean flags and defaults. Add a parameter-only Bicep
validation module and matching preflight failures for unsafe combinations.
Preserve environment-only Container Apps deployment and gate its private DNS
zone on the environment. Gate API-key artifacts on their complete prerequisite
set.

This option is additive, reversible, and preserves explicit choices. It adds no
Azure resources, identities, RBAC assignments, or recurring cost.

### Silently derive effective flags

Automatically enable the Container Apps Environment when apps are enabled and
automatically retain NSGs for existing subnets. This avoids failures but makes
the deployed graph differ from the operator's explicit values, complicates
automation, and can hide configuration mistakes.

### Replace the Booleans with a deployment mode

A mode object or enum could make combinations unrepresentable, but replacing
existing parameters is a breaking contract. Supporting both forms would require
precedence rules and make operation less predictable. This remains a possible
major-version migration.

### Do not change

Container Apps can reach an invalid reference, isolated environment-only
deployments can miss private DNS, API-key artifacts can outlive their apps, and
existing subnet NSGs can be detached.

## Decision

Keep the exposed flags and existing defaults. Accept only trimmed,
case-insensitive `true` and `false` values for the newly exposed azd Boolean
inputs.

Reject these combinations in both the Bicep validation module and deterministic
preflight:

- `deployContainerApps=true` with `deployContainerEnv=false`;
- `useCAppAPIKey=true` without Container Apps, Key Vault, App Configuration,
  and `appRuntimeConfigurationMode=appConfig`;
- `networkIsolation=true`, `useExistingVNet=true`, `deploySubnets=true`, and
  `deployNsgs=false`.

Permit environment-only Container Apps deployments and create the Container
Apps private DNS zone whenever the environment is selected. Defensively omit
Container App API-key secrets and App Configuration references unless all
prerequisites are selected.

Treat `false` as "omit from this incremental deployment," not "delete."

## Consequences

Unsafe combinations fail before resource mutation. Operators can still deploy a
Container Apps Environment without apps and can use externally managed BYO
subnets with `deploySubnets=false`.

Pipelines that used `yes`, `no`, `1`, or `0` for the six newly exposed azd
values must change to `true` or `false`. Disabling NSG deployment emits a warning,
and enabling Foundry local authentication emits a security warning.

No new resource, private endpoint, identity, role assignment, Azure limit, or
recurring cost is introduced. Operators retain ownership of explicit deletion
and stale App Configuration cleanup.

## Compatibility and migration

Parameter names, defaults, outputs, resource names, and manifest fields remain
unchanged. Existing callers that omit the variables keep the prior graph.

Before setting a component flag to `false`, operators must determine whether the
component already exists. If it does, omitting it leaves that resource in place.
Decommissioning requires a separately reviewed cleanup operation. Consumers
using noncanonical Boolean strings must normalize them before preflight.

## Security and identity

Managed identities and RBAC scopes are unchanged. The NSG constraint prevents
the template from removing an existing network control from a BYO subnet.
Environment-only isolated deployments retain private DNS for the Container Apps
private endpoint.

`AI_FOUNDRY_DISABLE_LOCAL_AUTH=true` remains the default. Setting it to `false`
does not add a credential to the template, but enables an API-key authentication
surface and therefore produces a warning. Container App API-key artifacts are
not emitted without their app and configuration dependencies.

## Adoption and rollback

Adopt strict lexical validation first, then dependency checks, defensive Bicep
gating, and documentation. Run preflight before provisioning.

Rollback by reverting this decision and the related assertions, checks, and
gates. Do not roll back by force-pushing a contributor branch. If an earlier
incremental deployment left resources or configuration keys behind, roll
forward with an explicitly reviewed cleanup; reverting template gates will not
delete them.

## Compliance verification

- Compile and lint `main.bicep`.
- Prove the three Bicep validation expressions and dependent resource
  conditions in an offline contract test.
- Exercise strict Boolean parsing and the Container Apps, API-key, BYO NSG,
  local-auth, and environment-only matrices in deterministic preflight tests.
- Enforce the compiled-template size gate.
- Run `azd provision --preview` only in an approved environment.
- Use a disposable live deployment only with explicit approval.

## Documentation impact

Update the repository README, standalone and hub/spoke runbooks, test harness,
and Unreleased changelog. Public Portal documentation requires review when these
environment controls are surfaced there.

## Review trigger

Review this decision when ARM complete-mode or deployment-stack deletion becomes
the supported deployment model, when subnet ownership moves outside this
template by default, or when a major release can replace the Boolean matrix with
a typed component mode.
