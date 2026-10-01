# ADR-0001: Separate hosted-agent preparation from deployment intent

- Status: proposed
- Date: 2026-08-05
- Owners: AI Landing Zone maintainers
- Related issue or pull request: Azure/GPT-RAG downstream ADR-0001 and this implementation pull request

## Context

The AI Landing Zone exposes an accelerator-neutral Microsoft Foundry hosted-agent
handoff. In v2.4.1, `deployHostedAgent=true` enables the prerequisite RBAC and
outputs, but preflight also requires an immutable image digest. A fresh
deployment cannot obtain the private registry and Foundry outputs needed to build
that image until provisioning succeeds, which creates a circular dependency.

Setting `deployHostedAgent=false` avoids the digest requirement but also removes
the executor's Azure AI Project Manager assignment, the Foundry project
identity's registry pull assignment, and the Foundry/registry/private-build
outputs needed by a later build and deployment.

The affected contracts are `main.bicep`, `main.parameters.json`, hosted-agent
preflight, the two centralized RBAC payloads, output names and shapes, and the
standard and network-isolated registry build topology. The Bicep template does
not create a hosted-agent version. The downstream `azure.ai.agent` service
creates the version, dedicated agent identity, and endpoint during `azd deploy`.

## Prioritized characteristics

| Characteristic | Priority | Measure |
| --- | --- | --- |
| Backward compatibility | 1 | Existing parameter files compile and both omitted flags preserve the prior resource graph and outputs. |
| Two-phase operability | 2 | Preparation succeeds before an image exists and exports the values required to build it. |
| Fail-closed deployment | 3 | Deployment still rejects missing, mutable, or malformed image digests. |
| Least privilege | 4 | Preparation adds only the existing project-manager and registry-pull assignments at their existing scopes. |
| Network topology stability | 5 | Private ACR, agent-pool, firewall, subnet, endpoint, and DNS gates remain unchanged. |

## Alternatives considered

### Add `prepareHostedAgent` beside `deployHostedAgent`

An additive Boolean preserves all current callers. The effective prerequisite
condition is `prepareHostedAgent || deployHostedAgent`, while image and agent
payload validation remain gated only by `deployHostedAgent`. This is easy to
adopt and reverse, and it does not introduce new resources or identities.

### Replace the flags with a mode enum

A `disabled`, `prepare`, or `deploy` enum would make invalid states
unrepresentable, but replacing the existing flag is breaking. Keeping both an
enum and the legacy Boolean would require precedence rules and make the public
contract harder to operate. This option is suitable only for a future major
version.

### Treat an empty digest as preparation

Overloading `deployHostedAgent=true` would weaken the immutable deployment
contract, make `HOSTED_AGENT_DEPLOYMENT.enabled` ambiguous, and allow an
accidental mutable or incomplete deployment path. This option is rejected.

### Do not change

Fresh deployments retain the provisioning/build cycle and must use a manual
bootstrap or temporary unrelated configuration to obtain the prerequisite
outputs.

## Decision

Add `prepareHostedAgent bool = false` and the matching
`PREPARE_HOSTED_AGENT=false` azd parameter substitution.

Define `_hostedAgentPrerequisitesEnabled` as
`prepareHostedAgent || deployHostedAgent`. Use it for:

- Azure AI Project Manager on the Foundry project for the deployment principal;
- the registry-mode-compatible pull role on the selected registry for the
  Foundry project identity;
- the Foundry, registry, network, and private-build handoff outputs.

Continue to use only `deployHostedAgent` for hosted-agent name, image, digest,
runtime, and protocol validation and for `HOSTED_AGENT_DEPLOYMENT.enabled` and
`.agent`. Add `HOSTED_AGENT_PREPARED` as the effective prerequisite signal
without changing the meaning of `DEPLOY_HOSTED_AGENT`.

## Consequences

Preparation can complete before a registry image exists, after which a separate
pipeline or VNet-connected builder can push an image and resolve its digest.
Deployment remains a second explicit step.

No new Azure resource type, identity, private endpoint, DNS zone, subnet, or
hourly-cost resource is introduced. An operator who independently enables the
existing ACR Task agent pool continues to incur that pool's existing cost.

The two public flags can both be true. This is intentional because deployment is
a prerequisite superset. A future major version may consolidate them into a mode
enum if operational evidence justifies the migration.

## Compatibility and migration

Both flags default to `false`. Existing callers that set only
`deployHostedAgent=true` keep the previous RBAC, output, and digest-validation
behavior because deployment implies preparation. Existing callers that omit the
feature retain the disabled graph and output fallbacks.

New callers use this sequence:

1. Set `prepareHostedAgent=true` and provision.
2. Consume the Foundry, registry, network, and private-build outputs.
3. Build, scan, sign, and push the image, then capture its SHA-256 digest.
4. Set `deployHostedAgent=true` and the typed hosted-agent values.
5. Provision the handoff and run the downstream accelerator's `azd deploy`.

This is an additive minor-version contract. The Portal and Terraform landing
zones require parity review before release.

## Security and identity

Preparation reuses the Foundry project system-assigned identity and the existing
deployment principal. It does not create or predict the dedicated per-agent
identity. RBAC remains centralized and scoped to the Foundry project and selected
registry. Registry role selection remains `AcrPull` for RBAC-only registries and
Container Registry Repository Reader for ABAC-enabled registries.

No credential, mutable image tag, malformed value, or placeholder digest is
accepted. Deployment preflight requires exactly `sha256:` followed by 64
lowercase hexadecimal characters, without surrounding whitespace. This
deterministic check does not query the registry for manifest existence or
signature authenticity; those checks remain the responsibility of the image
build, promotion, and downstream deployment pipeline.

Network-isolated deployments retain Premium ACR, disabled public access, private
endpoint and DNS behavior, and the existing VNet-injected ACR Task agent-pool
topology. Existing registries retain consumer-owned endpoint, DNS, and
reachability responsibilities.

## Adoption and rollback

Adopt preparation first, then build and deploy from the immutable digest.
`prepareHostedAgent` may remain true after deployment or be reset because
`deployHostedAgent` implies it.

Setting both flags to `false` stops emitting the handoff; disabling only
`deployHostedAgent` leaves preparation RBAC and outputs enabled while
`prepareHostedAgent` remains true. Disabling the contract does not guarantee
deletion of role assignments under incremental ARM deployment. Operators must
explicitly remove no-longer-required assignments. A downstream hosted-agent
version is outside this template and requires downstream cleanup. When pinning
to v2.4.1, remove `prepareHostedAgent` from caller parameter files.

## Compliance verification

- Compile and lint `main.bicep`.
- Enforce the compiled-template size gate.
- Prove both flags default to false and the default resource graph is stable.
- Prove prerequisite RBAC and outputs use the effective OR condition.
- Prove the agent payload remains deployment-only and no hosted resource exists.
- Exercise prepare-only, immutable, mutable, missing-digest, and missing-
  prerequisite preflight behavior.
- Re-run the private ACR Task agent-pool firewall contract.
- Use What-If and a live disposable deployment only with explicit approval.

## Documentation impact

Update the repository README, test harness documentation, and Unreleased
changelog. No hosted-agent content currently exists in the public
`Azure/AI-Landing-Zones` documentation repository, so no companion public-doc
change is required for this decision.

## Review trigger

Review this decision when Microsoft Foundry exposes a stable ARM hosted-agent
resource, changes private ACR identity or networking requirements, graduates the
hosted-agent service from preview, or when a future major release can replace the
two flags with a single mode without breaking consumers.
