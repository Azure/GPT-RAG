# ADR-0013: Bootstrap hosted runtime access before the first smoke request

**Status:** Accepted for scoped implementation; release and live evidence gates remain<br>
**Date:** 2026-09-21<br>
**Owners:** GPT-RAG maintainers

## Context

A hosted agent version can be active and pass readiness before its application
loads runtime configuration or calls a model. The validated development
deployment required three manual role assignments to the actual agent instance
identity before a greeting completed:

- App Configuration Data Reader on the solution configuration store.
- Key Vault Secrets User on the individual audit HMAC secret referenced by the
  configuration store.
- Cognitive Services OpenAI User on the selected solution model account.

The agent instance identity is not the operator, the Foundry account or project
identity, or a Container App identity. It becomes available after agent
creation. The existing root deployment hook performs a smoke request before a
focused bootstrap of these dependencies. Child-project deployments also need
this bootstrap; fixing only the root orchestration would leave a second
unsupported path.

Separate, explicitly approved Search and container-scoped Blob reader grants
enabled a synthetic service-identity retrieval test. Those grants do not
establish delegated user authorization and must not become default bootstrap
permissions. This decision does not alter document authorization or publish a
service-only test as end-user access-control evidence.

Prioritized characteristics and measures:

1. Least privilege: an exact allowlist of three role types and resource scopes;
   zero automatic Search, Blob, Conversation or subscription-wide grants.
2. Correct identity: resolve the deployed agent and validate its principal
   before any write; missing or conflicting identity fails closed.
3. Repeatability: exact existing assignments are reused without duplicate
   grants; a second invocation produces no new assignments.
4. Explicit failure: bootstrap failure prevents smoke/cutover; no successful
   deployment result is claimed from missing permissions.
5. Compatibility: classic deployment is unaffected and both shell variants use
   the same implementation.

## Alternatives considered

### Option A: Focused post-deployment bootstrap

- Resolve the real hosted agent identity and grant only its declared runtime
  dependencies before invoking the agent.
- The deployment operator needs the corresponding role-assignment permission;
  no credential, account key or broad runtime role is introduced.
- An inspectable read-only plan separates discovery from explicit application.
- Selected because agent creation supplies the identity required for correct
  assignments, and the existing resource provisioning phase occurs too early.

### Option B: Grant permissions to the Foundry project during provisioning

- Fits the existing infrastructure lifecycle.
- Does not establish permissions for the distinct agent instance principal.
  Broader project or subscription grants would not fix the identity contract.
- Rejected as a substitute for resolving the actual runtime identity.

### Option C: Keep manual commands

- Preserves current behavior and allows environment-specific review.
- Leaves fresh deployments failing after a successful image build and active
  agent creation; recovery depends on operator knowledge.
- Retained only as documented recovery, not the default product flow.

## Decision

Implement a focused GPT-RAG deployment module with a read-only planning mode
and explicit apply mode. It resolves existing azd/Foundry deployment metadata,
validates all inputs, then applies idempotent assignments to the deployed agent
instance identity. Wire it into the hosted child deployment completion path
so direct child deployment and root-orchestrated deployment run it before the
first root smoke request. Do not add network writes to the Search adapter or
change the AI Landing Zone source.

Only the following dependency grants are in scope:

| Dependency | Role | Scope |
| --- | --- | --- |
| Solution App Configuration | App Configuration Data Reader | Exact store |
| Solution Azure OpenAI model account | Cognitive Services OpenAI User | Exact account |
| Configured audit HMAC Key Vault reference | Key Vault Secrets User | Exact unversioned secret resource |

Discover the configured audit reference without retrieving secret contents.
Validate HTTPS, the expected Key Vault and resource mapping, and a well-formed
secret path. Do not grant all secrets, import arbitrary references, or construct
a principal from a resource name. If an audit reference is absent, do not
invent one. Incompatible or unverifiable metadata fails before creating grants.

Plan all assignments before applying any. Reuse exact existing unconditional
assignments. Do not replace conditional assignments, conceal a permission
failure, retry ambiguous writes indefinitely, or log tokens/reference values.
Bound transient identity/role visibility checks; ARM visibility alone is not
proof that permissions have propagated to the data plane.

Do not automatically add `Search Index Data Reader`, `Storage Blob Data
Reader`, elevated read, content permissions, managed Conversation roles,
Owner or Contributor. Do not disable ACL filters or change OBO behavior.
Synthetic retrieval permissions remain an explicit environment-specific
decision with their own cleanup and authorization tests.

## Consequences

The operator needs permission to create the exact assignments or must have a
privileged operator pre-create them. The hosted runtime gains only read access
to configuration and the configured audit secret plus model inference.
No new resource, image build, identity, secret, service plan or network access
is created by this module.

If an assignment succeeds and a later operation fails, report the failure and
retain the valid assignments for idempotent recovery. Do not delete existing
grants during automatic rollback.

## Adoption and migration

1. Implement the shared module, hosted child hooks, parity tests and docs.
2. Preserve the current homologation checkout and its explicit synthetic grants.
   A read-only plan may compare existing assignments; this implementation task
   does not authorize additional Azure writes or redeployment.
3. Existing environments can run the documented bootstrap apply command after
   review, without rebuilding the image or provisioning infrastructure.
4. Prepare a release from `develop` only with a compatible, immutable component
   matrix and passing required checks. Do not merge unrelated work or replace
   validated development commits with untested release tags merely to publish.
5. Publish under the user's explicit release request only after the release
   gates pass. Missing compatible tags, branch-policy requirements or live
   evidence must be disclosed, not bypassed.

Rollback the implementation without automatically deleting role assignments.
Review their actual consumer identities before any separate revocation.

## Compliance verification

- Mocked discovery proves exact deployed principal and scoped role selection.
- Missing/invalid identity, endpoint, reference, role scope and permission
  errors cause a nonzero result without permissive defaults.
- Missing optional audit reference creates no secret grant; unexpected vaults
  and malformed reference paths are rejected.
- A second application creates no duplicates, and partial failure preserves
  explicit recovery evidence.
- Both PowerShell and shell paths invoke the same bootstrap before smoke or
  cutover; direct hosted child deployment is covered.
- Negative tests prove no default Search, Blob, Conversation, administrator or
  data-write assignments are produced.
- No unit test accesses Azure, retrieves a secret or invokes a model.
- Operator live evidence remains separate: the existing manually granted
  environment passed greeting and synthetic native retrieval through both
  protocols, but that does not prove automatic fresh-install bootstrap or
  delegated user authorization.

### Implementation evidence (2026-09-21)

The focused module/smoke, PowerShell/shell hook, and installed Azure CLI
parser/serialization suites passed 63, 7 and 3 tests respectively. CLI tests
blocked network access and command handlers, except an explicitly mocked
App Configuration handler used to exercise the real output formatter.

The CLI boundary was corrected using observed behavior, not permissive
fallbacks: Cognitive Services metadata uses an explicit raw ARM GET at
`2025-06-01` because the installed typed CLI deserializer failed; App
Configuration reference metadata uses the CLI's `contentType` JSON field.
The raw ARM response still has its resource identity, type and endpoint
bindings validated. No alternate identity or broader role was introduced.

A live `--plan` run guarded against all write, secret-read and model-invocation
commands completed the environment, project ARM and account ARM reads. Its
Foundry data-plane read was blocked by the operator host resolving the private
service hostname to a public address. Full live planning and automatic fresh
deployment are therefore not claimed. Restore the authorized private network
path before completing that independent gate; do not open public access.

## Documentation impact

Update hosted deployment, troubleshooting, authentication and release-matrix
guidance on the GPT-RAG docs branch. Describe required operator permissions,
read-only planning, apply/recovery, propagation limits and the explicit
separation between application bootstrap and document authorization.

## Review trigger

Reassess on a change to Foundry instance identity, supported model authentication,
audit-secret placement, deployment hooks, document authorization, or a request
to add another runtime role.
