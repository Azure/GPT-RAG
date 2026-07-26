# ADR-0002: Use OIDC managed identity for Copilot Azure access

**Status:** Accepted<br>
**Date:** 2026-07-26<br>
**Owners:** GPT-RAG maintainers

## Context

GitHub Copilot cloud coding agents working in `Azure/GPT-RAG` need Azure
control-plane discovery for repository tasks. The previous integration stored a
client secret in the GitHub `copilot` environment and reused an application
whose service principal had subscription Owner. That combination creates a
long-lived credential and grants substantially more authority than discovery
requires.

This decision affects this repository's Copilot setup workflow, its GitHub
`copilot` environment, and subscription
`9788a92c-2f71-4629-8173-7ad449cb50e1`. It does not change the GPT-RAG runtime,
customer identities, data plane, deployment topology, or component repositories.
The agent reaches Azure public control-plane endpoints; it receives no private
network or workload data-plane access through this decision.

Prioritized characteristics and measures are:

1. **Credential security:** no stored Azure client secret or password
   credential; every token is issued from an exact GitHub OIDC trust.
2. **Least privilege:** the agent identity has only Reader at the named
   subscription scope and cannot create resources or role assignments.
3. **Repository isolation:** the federated subject is exactly
   `repo:Azure/GPT-RAG:environment:copilot`.
4. **Reproducibility:** the setup job and Azure login actions, plus the `azd`
   version, are pinned and the required job remains machine-verifiable.
5. **Operability and recovery:** authentication is observable in Actions, has no
   rotating secret, and can be disabled by removing one federation or role.

## Alternatives considered

### Option A: Static client secret

- Benefits: broadly supported and simple to bootstrap.
- Costs and risks: requires secret issuance, storage, expiry monitoring,
  rotation, and incident response; a copied credential remains usable outside
  GitHub until revoked.
- Security and identity: ties access to a reusable application credential and
  does not bind token issuance to this repository and environment.
- Operational consequences: periodic rotation can interrupt cloud-agent tasks.
- Component compatibility: works with Azure CLI and Azure MCP, but adds no
  capability over workload identity federation.
- Cost and network: no material Azure cost or network advantage.
- Reversibility: easy to recreate, but revocation must cover every stored copy.

### Option B: GitHub OIDC federated user-assigned managed identity

- Benefits: secretless, short-lived tokens, exact repository/environment trust,
  and independent lifecycle and audit records for the coding agent.
- Costs and risks: depends on GitHub's OIDC issuer and correct environment
  configuration; an overly broad federated subject or RBAC assignment would
  weaken the boundary.
- Security and identity: a dedicated user-assigned managed identity trusts only
  `repo:Azure/GPT-RAG:environment:copilot` with audience
  `api://AzureADTokenExchange`.
- Authorization: Reader at the subscription is sufficient for inventory and
  discovery and provides no write or role-assignment permission.
- Operational consequences: no secret rotation; maintainers manage the
  federation, role assignment, and pinned setup workflow.
- Component compatibility: supported by `azure/login`, Azure CLI, `azd`, and
  the Azure MCP server used by Copilot.
- Cost and network: user-assigned managed identity has no material incremental
  cost; Azure public control-plane availability remains a dependency.
- Reversibility: remove the federated credential or Reader assignment to stop
  access immediately without deleting the retained legacy applications.

### Do not grant Azure access

- Benefits: smallest Azure attack surface and no cloud identity to operate.
- Costs and risks: Copilot cannot verify Azure inventory, configuration, or
  deployment state, so discovery tasks require a maintainer to relay evidence.
- Security and identity: no Azure token or RBAC assignment.
- Operational consequences: safer for repositories whose agents never need
  Azure context, but incompatible with the requested read-only discovery use.
- Reversibility: Azure access can be introduced later with this same OIDC
  design.

## Decision

Use Option B. Host `mi-gpt-rag-copilot-agent` in the dedicated
`rg-gpt-rag-copilot-agent` resource group. Trust GitHub's token issuer only for
the `copilot` environment subject stated above and assign the identity only the
Reader role at
`/subscriptions/9788a92c-2f71-4629-8173-7ad449cb50e1`.

The setup workflow uses environment variables for the non-secret client,
tenant, and subscription identifiers. No client secret is created or retained.
The legacy applications are retained without subscription authorization because
deletion is less reversible and exclusive ownership has not been established.

## Consequences

### Positive

- Azure access uses short-lived, repository-bound tokens instead of a stored
  credential.
- A compromised agent token cannot write Azure resources or change RBAC.
- The identity, federation, and authorization can be audited independently from
  GPT-RAG runtime identities.
- Authentication setup is deterministic and visible in the required
  `copilot-setup-steps` job.

### Negative or accepted

- Subscription Reader exposes control-plane metadata for every resource the
  role can enumerate in this subscription.
- GitHub environment and OIDC availability become dependencies for Azure-aware
  Copilot tasks.
- Any future write operation requires a separate review and must not be added to
  this identity by convenience.

## Adoption and migration

1. Create the dedicated resource group and managed identity.
2. Add the exact GitHub environment federation and subscription Reader role.
3. Publish the pinned setup workflow and non-secret environment variables.
4. Prove OIDC login and an Azure read operation from GitHub Actions.
5. Remove `AZURE_CLIENT_SECRET` from the GitHub environment and remove the
   legacy service principal's Owner assignment.
6. Merge the workflow and this ADR to `main`, because Copilot reads setup steps
   from the default branch.

Rollback removes the new federated credential and Reader assignment, which
immediately disables the path. The workflow can then be reverted. The old
applications remain available but unprivileged; restoring privileged static
credentials is not an automatic rollback and requires a new security decision.
Roll-forward for an integration defect is to correct the exact federation or
workflow pin while keeping the identity read-only.

## Compliance verification

- `.github/workflows/copilot-setup-steps.yml` parses as YAML, contains exactly
  one job named `copilot-setup-steps`, and grants only `contents: read` and
  `id-token: write`.
- The managed identity has exactly one GitHub federation with the required
  issuer, subject, and audience.
- Its effective assignment for this integration is Reader at the exact
  subscription scope, with no Contributor, Owner, or role-assignment role.
- A GitHub Actions smoke test authenticates through OIDC and completes
  `az account show` and a resource-group list without credentials in logs.
- The GitHub `copilot` environment has no `AZURE_CLIENT_SECRET` secret metadata.
- The legacy `sp-gpt-rag` service principal has no Owner assignment at the
  subscription.

## Documentation impact

No product documentation changes are required. The published documentation
does not describe repository-maintainer Copilot credentials, and runtime or
operator behavior is unchanged. This ADR is the maintainer-facing record.

## Review trigger

Reassess this decision before granting any write permission, changing the
federated subject or GitHub environment, adding data-plane access, or adopting a
new Azure MCP authentication contract. Otherwise review the identity,
federation, and role assignment by 2026-10-26.
