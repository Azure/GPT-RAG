# ADR-0010: Check private deployment connectivity instead of host declarations

**Status:** Accepted; source adoption subject to normal feature review<br>
**Date:** 2026-09-21<br>
**Owners:** GPT-RAG maintainers

## Context

The operator approved VPN-connected deployment-host support. Previously,
`preDeploy` required `RUN_FROM_JUMPBOX=true`; `postProvision` accepted an
interactive VPN declaration but deferred without a terminal. Neither
declaration established network reachability. Managed laptops connected through
an approved VPN and connected CI runners need the same entry checks as jumpboxes.

Priorities, in order: preserve private access by rejecting non-RFC1918 DNS;
verify server identity through normal TLS certificate/hostname validation;
support unattended connected hosts; preserve explicit post-provision deferral;
bound failures with actionable errors. Scope is umbrella lifecycle code and
coordinated operator documentation on the `docs` branch. No Azure settings,
identities, runtime contracts, source pins or infrastructure change.

## Alternatives considered

### Option A: Add a VPN flag or broaden the jumpbox flag

- Small, reversible change that preserves existing automation.
- Still trusts an operator declaration without checking DNS or routing.
- Adds another toggle or requires a managed laptop to claim it is a jumpbox.
- Does not establish certificate identity, authorization or component health.

### Option B: Shared, credential-free DNS and TLS checks

- Selected: the same evidence applies to VPN, jumpbox and connected CI runners.
- Uses OS DNS; validates all answers before connecting directly to the checked
  IPv4 addresses on TCP 443 with the original hostname as TLS SNI.
- No proxy, redirect, token acquisition or HTTP request is part of the probe.
- Costs one bounded DNS/TLS check per required hostname and needs Python's
  normal trust store. It does not replace authentication or application tests.
- Shares logic between PowerShell and Bash and is reversible without changing
  runtime components, stored data, RBAC or network infrastructure.

### Do not change

- Retains established deployment behavior without new code.
- Blocks legitimate VPN-connected hosts and encourages inaccurate flags.
- Noninteractive post-provision can report success with unfinished setup.

## Decision

Add a standard-library-only deployment helper with explicit stage boundaries:

| Stage | Required network boundary |
| --- | --- |
| Post-provision entry | `APP_CONFIG_ENDPOINT`, before configuration publication |
| Pre-deploy | `APP_CONFIG_ENDPOINT`; additionally `AZURE_AI_PROJECT_ENDPOINT` for hosted topologies, before deployment/invocation |
| Actual hosted image build | `AZURE_CONTAINER_REGISTRY_ENDPOINT`, before ACR build/manifest access |

Read the provisioned endpoints from the selected materialized `azd`
environment. Hooks fail on unsuccessful, empty or malformed environment reads
rather than choosing an arbitrary `.azure` directory. Root pre-deploy uses a
single snapshot for both the gate and deployment. Explicit empty values clear
their inherited process values; absent keys retain existing process inheritance.
No new setting or environment persistence is introduced.

These are entry prerequisites, not an inventory-wide network certification.
Search, Key Vault, Blob, Cosmos, ACA application health, ACR regional data and
task-log endpoints, build-pool egress, authorization and runtime-to-service
connectivity require their own acceptance evidence. No guessed resource names
or private endpoint NIC addresses are used. RFC1918 plus TLS does not prove
that an IP belongs to the intended VNet; effective routes and endpoint mapping
remain operator verification gates.

Public deployments do not probe. An invalid explicit `NETWORK_ISOLATION`
boolean fails rather than falling back to public behavior. For private
post-provision only, preserve explicit `RUN_FROM_JUMPBOX=false|0|no|skip` and
`AZURE_SKIP_NETWORK_ISOLATION_WARNING=true` deferral, including the existing
truthy jumpbox precedence over the warning setting. Report deferral prominently
and return internal code `20`; only post-provision hooks map it to their
explicit-skip exit `0`, before any configuration work.

A truthy jumpbox value never bypasses connectivity checks. An unset or empty
jumpbox flag probes unless the warning setting explicitly defers. There is no
implicit noninteractive deferral or confirmation prompt. Pre-deploy and actual
hosted-build gates ignore both deferral flags. Missing endpoints, invalid HTTPS
hosts, public/mixed DNS, timeout or certificate failure stop the operation with
a nonzero exit; the shared CLI uses `4` for prerequisite errors. Hooks propagate
gate failures without proceeding. Immutable prebuilt/reused digests are
validated through existing early-return paths, with no registry probe or build.

Endpoint allowlists cover public Azure App Configuration (`.azconfig.io`),
native Foundry (`.services.ai.azure.com`) and ACR (`.azurecr.io`). Bare ACR login
servers are supported. URLs must use HTTPS and port 443, without credentials,
query or fragment; IP substitutes and arbitrary probe targets are rejected.
Other clouds/custom endpoints need a reviewed extension.

Probes use system DNS, including Windows NRPT, with a 10-second resolver timeout
and a 20-second overall per-hostname budget. Resolve once, require 1-16 answers
all within RFC1918 IPv4 ranges, and connect using numeric IPv4 sockets without
resolving again. Preserve normal CA/certificate/hostname verification and
original-hostname SNI. No public fallback, proxy tunneling or disabled TLS
verification. No retry or hosted build restart is introduced.

## Consequences

Connected private hosts no longer need a jumpbox declaration. An unconnected
workstation now fails post-provision rather than reporting implicit success
with unfinished configuration, unless the operator explicitly deferred. An ARM
deployment can succeed while its post-provision hook fails; reconnect and rerun
post-provision, not provision blindly.

A successful probe establishes DNS/TCP/TLS at that instant only, not RBAC,
Azure resource mapping, API health, identity, future access or app readiness.
Authorization, DLA and OBO behavior remain unchanged. No roles are added by
this gate and it has no resource-cost or data-migration impact.

## Adoption and migration

Adopt the focused helper, hook integration, offline regression tests and this
decision through a normal feature PR to `develop`. Keep the current hosted
bootstrap and immutable release pins unchanged. Coordinate deployment and
troubleshooting guidance on `feature/docs-v3.8.5-vpn` targeting `docs`; release
coordination binds the reviewed implementation to its eventual release.

Existing true jumpbox flags remain compatible but unnecessary. To resume after
explicit deferral, remove its cause from both the selected `azd` environment
and the invoking process, then rerun post-provision from a connected host.
Clearing the jumpbox setting alone does not clear an inherited warning setting.
Every deferred post-provision phase still needs configuration completion before
deployment. No CLI argument syntax changes are required.

Roll back this feature and use a real jumpbox with the previous hooks; do not
spoof that flag on a laptop. No infrastructure rollback or data migration is
required. Publish updated operator guidance with the release, not as already
shipped behavior while implementation review is pending.

## Compliance verification

Use only mocked networking and Azure command boundaries. Reproduce the old
flag-unset hook failure, then cover public/connected/disconnected hosts, explicit
deferral precedence, missing/malformed endpoints, strict DNS, 16-answer limits,
timeouts, certificates, fixed-address connections, SNI and build short-circuits.

Execute both hook variants with fake CLIs and the shared helper's mocked
network boundary. Prove a failed prerequisite precedes configuration,
deployment and image builds, and explicit deferral performs no configuration.
Cover selected-environment read failures, CRLF outputs and empty-value
propagation. Parse PowerShell, check Bash syntax and run the existing hosted
bootstrap, smoke, image, preparation, deployment and release-contract tests,
then the full offline suite with the unchanged infrastructure pin.

Live VPN/NRPT resolution, endpoint ownership, routes, RBAC and end-to-end
deployment remain operator acceptance gates; offline evidence does not certify
them. No live probes or Azure resource operations are part of implementation.

## Documentation impact

Coordinate the VPN guide, private deployment flow, configuration reference,
deployment overview and troubleshooting pages on the `docs` branch. Explain
the phase-specific endpoints, explicit deferral and resumption, retained process
inheritance, certificate requirements, failure behavior and scope of evidence.
Keep unreleased behavior clearly identified until the release is published.

## Review trigger

Revisit when enabling another cloud/custom endpoint, changing lifecycle network
dependencies, or after the first VPN end-to-end acceptance run. Require
endpoint mapping, routing and runtime evidence before expanding claims beyond
the DNS/TCP/TLS prerequisites.
