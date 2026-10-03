# Feature Specification: Rebrand and Consolidate GPT-RAG into Agent Landing Zone

**Feature Branch**: `feature/agent-landing-zone-rebrand`

**Created**: 2026-09-29

**Status**: Draft

**Input**: [Issue #695](https://github.com/Azure/GPT-RAG/issues/695) - "[Rebranding] Define and execute the GPT-RAG rebranding", plus decisions from the "AI Landing Zone - Bicep - Weekly Sync" meetings (2026-09-10, 2026-09-17, 2026-09-24) and the "GPT-RAG Positioning" discussion. Maintainer direction: "GPT-RAG will become Agent Landing Zone. A user will be able to deploy only the infrastructure or the application too. The application may vary over time, but we start with the current trio (UI, orchestrator, and ingestion), following the same approach, with or without the hosted agent option. All naming must be adapted so that GPT-RAG does not remain in the release we ship, including renaming the GitHub repositories."

## Context

The GPT-RAG name no longer describes the offering. "GPT" refers to a single
model family, while the solution is model-agnostic on Microsoft Foundry. "RAG"
refers to a single pattern, while the solution already supports agent
orchestration, tool calling, and MCP tools. At the same time, feedback on the
AI Landing Zone is that an infrastructure layer without a working AI
application on top feels incomplete.

On 2026-09-24 the maintainers agreed to the following direction:

- **Name**: GPT-RAG is renamed and matured into **Agent Landing Zone**. This is
  an architectural and capability evolution, not only a cosmetic rename.
- **Layers**: one offering with two layers that stay distinguishable. The
  **infrastructure layer** is the secure, governed foundation. The
  **application layer** is a deployable agent application on top of it.
  Operators can deploy the infrastructure layer only, or both layers.
- **Documentation**: centralized on the AI Landing Zones documentation site,
  in an Agent Landing Zone section next to AI Gateway Landing Zone. The
  repository itself becomes a short landing page that links to that site.
- **Infrastructure as code**: both Bicep and Terraform stay supported. Bicep
  changes are analyzed automatically and turned into Terraform pull requests,
  which always get a human review.

## Clarifications

### Session 2026-09-29

- Q: Which prefix replaces "gpt-rag" in internal identifiers? → A: `agentlz` (hyphenated form `agent-lz` where separators are required); `alz` is avoided because it is the established Azure Landing Zones acronym.
- Q: How are component repositories versioned after the rename? → A: Keep their numbering with a major bump (UI `v3.0.0`, orchestrator `v5.0.0`, ingestion `v3.0.0`); preview pins use `-preview.1`.
- Q: What visual identity must the UI show, and when? → A: A text wordmark "Agent Landing Zone" with an existing generic icon from the preview; a designed logo is optional from `v4.0.0` and never blocks a release.
- Q: Is the infrastructure's commit history imported when it is incorporated? → A: No. The files of the pinned tag are copied in one provenance commit; the history stays in `Azure/bicep-ptn-aiml-landing-zone`.
- Q: How does the operator choose infrastructure only versus infrastructure plus application? → A: With the native `azd` verbs, as the flow already works today. `azd provision` is infrastructure only: all Azure resources, including the Container Apps that the parameterized app list defines, running a placeholder image, plus the post-provision configuration. `azd deploy` publishes the application components from the release manifest. `azd up` does both. No new flag or entry point.
- Decision (post-clarify, approved): Are the application definition and the release manifest separate files? → A: Yes. `manifest.json` (Microsoft-maintained release pins) and `app-definition.json` (application contract). The bundled trio also has an `app-definition.json` that resolves its versions from `manifest.json`, so default and custom apps share one schema and one flow.

### Session 2026-10-01

- Q: When does an environment become bound to an application? → A: At the first `azd provision`. Without `AGENTLZ_APP_DEFINITION` it is bound to the bundled trio (placeholder Container Apps); a custom application must set the variable before the first provision.
- Q: How does deploy know the environment is still running the same application? → A: The application definition's `id` is saved in the azd environment (`.azure/<env>/.env`) at the first provision. A later provision or deploy with a different `id` is rejected with a message to create a new environment. No Azure-side copy, digest, or mode comparison.
- Q: What does "no partial deploy" guarantee if a run fails midway? → A: All prerequisite and definition checks run before any resource changes, so an invalid input changes nothing. A failure after changes begin is recovered by re-running the same command, which is idempotent and converges. No automatic rollback.
- Q: How many components can an application declare, and which ones get placeholders? → A: A list of one or more components, each either a Container App or a hosted agent (zero or more of each). `azd provision` creates placeholder Container Apps only for declared Container Apps; hosted agents have no placeholder and are created at `azd deploy`. A hosted-only application creates no Container Apps.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy the Full Agent Landing Zone Under the New Name (Priority: P1)

An operator discovers Agent Landing Zone, follows its landing page to the
central documentation, and deploys the infrastructure and application layers
together. The result is a working agent application (UI, orchestrator, and
ingestion) on a secure foundation. The operator can choose between the classic
orchestrator and the Foundry hosted-agent orchestrator, exactly as with
GPT-RAG today. No step, prompt, message, resource, or artifact the operator
sees presents the product as GPT-RAG.

**Why this priority**: This is the release's core promise. It delivers the
rebrand and keeps the full, working experience that current GPT-RAG users rely
on.

**Independent Test**: From a fresh clone of the renamed repository, deploy
both layers in each orchestrator mode (classic and hosted agent). Confirm that
the application answers a grounded question and that the deployment output,
created resources, application UI, and published release contain no "GPT-RAG"
or "gpt-rag" branding outside historical records.

**Acceptance Scenarios**:

1. **Given** a fresh clone of the Agent Landing Zone repository, **When** the
   operator deploys with default settings, **Then** both layers deploy, the
   application answers a grounded question, and the product is identified as
   Agent Landing Zone throughout.
2. **Given** an operator who selects the hosted-agent orchestrator, **When** the
   deployment completes, **Then** the application works as the GPT-RAG hosted
   mode does today, under the new names.
3. **Given** a completed deployment, **When** the operator lists the created
   Azure resources, names, tags, roles, and published configuration, **Then**
   none uses GPT-RAG naming.
4. **Given** the application UI, **When** an end user opens it, **Then** the
   title, logo, and visible text show the new branding.

**Phase applicability**: At the preview (`v4.0.0-preview.1`), scenarios 1, 2,
and 4 apply, and "identified as Agent Landing Zone throughout" is limited to
the surfaces listed in SC-008. Scenario 3 and the resource and configuration
part of the Independent Test apply from `v4.0.0`, because runtime identifiers
change in Phase 2 (FR-002, FR-003).

---

### User Story 2 - Deploy Only the Infrastructure Layer (Priority: P1)

A platform team wants a governed foundation for its own agents and does not
want the reference application. From the same repository, the team chooses an
infrastructure-only deployment. It gets the secure foundation without the UI,
orchestrator, or ingestion services and without application-specific
configuration. Later, the team can add the application layer to that same
foundation without redeploying it.

**Why this priority**: This is the new capability that makes the offering a
landing zone rather than a single application. It is the decision reached on
2026-09-24.

**Independent Test**: Run `azd provision` and confirm that the foundation
exists and that the Container Apps run only the placeholder image, with no
component image published. Then run `azd deploy` on the same environment and
confirm that the application works without re-creating the foundation.

**Acceptance Scenarios**:

1. **Given** an operator who runs `azd provision`, **When** it completes,
   **Then** the foundation (for example networking, identity, Foundry, data,
   monitoring, governance, and the Container Apps declared in the application
   definition) is ready and configured, the Container Apps run the placeholder
   image, no
   application component image has been published, and the environment is
   bound to the application whose definition was used (the bundled trio when
   `AGENTLZ_APP_DEFINITION` is not set).
2. **Given** an infrastructure-only deployment, **When** the operator later
   runs `azd deploy`, **Then** the application components from the release
   manifest deploy onto the existing foundation and work, and foundation
   resources are not destroyed or re-created.
3. **Given** an operator who runs `azd deploy` on an environment whose
   provisioning is missing or incomplete, **When** the command runs, **Then**
   it stops during validation with a clear message that says to run
   `azd provision` first, before any resource is changed.
4. **Given** an operator who wants the foundation without this repository,
   **When** they read the documentation, **Then** they find how to use the
   Bicep or Terraform infrastructure directly.

---

### User Story 3 - Find One Source of Truth for Documentation (Priority: P2)

A new user, architect, or partner looks up Agent Landing Zone. They land on a
short repository page that explains what it is, shows an architecture diagram,
states that it is the former GPT-RAG Solution Accelerator, and links to the
Agent Landing Zone section of the central AI Landing Zones documentation. The
detailed guidance lives only there.

**Why this priority**: One documentation location removes duplication and
confusion between the landing zone and the application. It is required for
the launch, but it can be delivered after the deployment experience works.

**Independent Test**: Open the repository landing page and the central
documentation site. Confirm that every deployment, configuration, and
operations topic is reachable from the central site and that the repository
page does not duplicate it.

**Acceptance Scenarios**:

1. **Given** the repository landing page, **When** a reader opens it, **Then**
   they see a short description, a diagram, the transition statement, and a
   link to the central documentation.
2. **Given** a link to a former GPT-RAG documentation page, **When** a reader
   follows it, **Then** they reach the equivalent Agent Landing Zone page or a
   page that tells them where the content moved.
3. **Given** the central documentation, **When** a reader browses the Agent
   Landing Zone section, **Then** it covers both deployment options, both
   orchestrator modes, configuration, and operations.

---

### User Story 4 - Keep Existing Links and Workflows Working After the Repository Rename (Priority: P2)

An existing user bookmarked the GPT-RAG repositories, cloned them, or
automated deployments against their URLs, short links, or template name. After
the rename, these references keep working or give clear guidance to the new
names.

**Why this priority**: Renaming repositories and short links is disruptive.
Existing users and partner pipelines must not break silently.

**Independent Test**: Use the former web URLs, clone URLs, and short links of
the umbrella repository and each component repository. Confirm that each one
reaches the renamed destination or clear guidance about it.

**Acceptance Scenarios**:

1. **Given** the former URL of any renamed repository, **When** a user opens or
   clones it, **Then** they reach the renamed repository with its full history,
   issues, pull requests, and releases.
2. **Given** a published GPT-RAG short link, **When** a user follows it after
   the rename, **Then** it never lands on a broken page. It resolves to the
   equivalent Agent Landing Zone destination or, while that retargeting is
   still pending, to the Agent Landing Zone documentation section or a
   moved-content notice.
3. **Given** a release of the renamed components, **When** the umbrella release
   pins them, **Then** every pin refers to the new names and resolves.

---

### User Story 5 - Deploy My Own Agent Application on the Landing Zone (Priority: P3)

A partner or customer developer has their own agent application, either as
Container Apps services or as a Foundry hosted agent. They want the Agent
Landing Zone foundation without the bundled UI, orchestrator, and ingestion.
They add an application definition to their app folder, point the landing
zone at it, and deploy everything with one command from the Agent Landing Zone
repository.

**Why this priority**: It turns the landing zone into a platform that others
can build on, which is the point of the rename. It comes after the rebrand,
the infrastructure-only option, and the documentation, and it has a documented
fallback (FR-015).

**Independent Test**: In a fresh environment, set `AGENTLZ_APP_DEFINITION` to
the sample custom application and run `azd up`. Confirm that the foundation is
created, the bundled trio is not deployed, and the sample's declared
components (Container Apps, hosted agents, or both) run and read the platform
outputs from App Configuration.

**Acceptance Scenarios**:

1. **Given** a fresh environment with `AGENTLZ_APP_DEFINITION` pointing to a
   valid definition of a classic application, **When** the operator runs
   `azd up`, **Then** the landing zone creates the declared Container Apps,
   grants only the declared capability profiles, builds and pushes the images,
   and the application runs.
2. **Given** a valid definition of a hosted-agent application, **When** the
   operator runs `azd up`, **Then** the agent is published to the landing
   zone's Foundry project with the same security and network-isolation posture
   as the bundled hosted orchestrator.
3. **Given** an invalid definition (schema error, unknown capability profile,
   remote URL, or hook), **When** the operator runs `azd up`, **Then** the
   deployment stops before any Azure change with a message that names the
   problem.
4. **Given** an environment that already runs an application, **When** the
   operator runs `azd deploy` with a different definition, **Then** the
   deployment is rejected and the message says to use a new environment.
   Redeploying the same definition succeeds.
5. **Given** an operator who does not set `AGENTLZ_APP_DEFINITION`, **When**
   they run `azd up`, **Then** the bundled trio is deployed exactly as in US1.

---

### Edge Cases

- The chosen repository or short-link name is already taken, or it collides
  with another internal "Agent Landing Zone" offering.
- An operator runs `azd provision` again on an environment that already runs
  the application. The published component images must keep running and must
  not be reset to the placeholder image.
- An operator mixes an old GPT-RAG clone with new component releases, or the
  reverse. The combination is rejected with a clear message.
- Runtime identifiers such as the configuration label, audit event names, the
  custom role name, and cryptographic domain separators change in new
  deployments. Values, dashboards, or alerts built on a GPT-RAG environment do
  not carry over. This is acceptable because only new deployments are
  supported.
- A project outside this repository still consumes the former standalone
  infrastructure repository as a submodule. It keeps working on its pinned
  tags and sees a notice that points to the new location.
- Third-party content (blog posts, samples, videos) keeps linking to the old
  names after the launch.
- The hosted-agent path depends on names such as the agent name or image name,
  which must stay consistent across the configuration, the image registry, and
  Foundry.
- GitHub redirects a renamed repository's web, clone, fetch, and push URLs,
  but not its GitHub Pages project site. When `Azure/GPT-RAG` is renamed, the
  former documentation site URL (`azure.github.io/GPT-RAG`) stops resolving.
  Creating a new repository with the old name to host a notice is not allowed,
  because it would break the repository redirects. Short links to the former
  site are therefore retargeted at the rename (FR-020, blocking level), the
  moved-content notice is published at the new site location, and direct links
  to the former site URL are a documented, accepted break.
- A custom application definition is invalid, requests an unknown capability
  profile, references a remote URL, or declares a hook. Validation rejects it
  before any Azure change.
- An operator points `AGENTLZ_APP_DEFINITION` at a different application on an
  environment that already runs one. Its `id` differs from the `id` saved in
    the environment, so the deployment is rejected; a new environment is
    required.
- A hosted-agent custom application is deployed where the Foundry hosted-agent
  prerequisites (region availability, `azd` extension version, or quota) are
  missing. It fails closed and does not fall back to classic hosting.
- A custom application's hosted-agent `azure.yaml` uses literal values (such
  as the agent name) that the `azd` agent extension does not interpolate. The
  sample and the documentation show the supported pattern.
- An operator runs `azd provision` with `AGENTLZ_APP_DEFINITION` set. Only the
  declared Container App components are created with the placeholder image, as
  in FR-012. A definition with only hosted-agent components creates no
  Container Apps; its agents are created at `azd deploy`.
- An operator sets `AGENTLZ_APP_DEFINITION` only after the first
  `azd provision`. The environment is already bound to the bundled trio, so
  the next provision or deploy is rejected by the application `id` check
    (FR-015g) with a message that says to create a new environment.

## Requirements *(mandatory)*

### Functional Requirements

**Naming and branding**

- **FR-001**: The product MUST be presented as "Agent Landing Zone", with the
  statement that it is the former GPT-RAG Solution Accelerator renamed and
  matured, on the repository landing page, the documentation, and the release
  notes. The README, migrated documentation, and release notes MUST use the
  exact statement "GPT-RAG is now Agent Landing Zone".
- **FR-002**: The shipped release MUST NOT use "GPT-RAG", "gpt-rag", "GptRag",
  "gptrag", or "GPT_RAG" in user-visible text, repository names, template
  metadata, release titles and notes, default resource names, tags, image
  names, agent names, role names, configuration labels, environment variable
  names, package names, container image names and tags, Foundry agent names,
  telemetry service names, resource names, configuration keys, event names, or
  logs. The only exceptions are historical records, such as prior changelog
  entries, ADRs, specs, release notes, and migration history kept for
  auditability, and the transition statement (FR-001).
- **FR-002a**: Renamed internal identifiers MUST use the `agentlz` prefix,
  adapted to each identifier's casing and separator rules: `agentlz` where
  separators are not allowed or not used, `agent-lz` for hyphenated names
  (such as the App Configuration label, index, and image names), `AGENTLZ_` for
  environment variables, `agentlz.` for event names, and "Agent Landing Zone"
  for human-readable names such as role names. The acronym `alz` MUST NOT be
  used, because it denotes Azure Landing Zones.
- **FR-003**: The maintainers MUST produce and keep an inventory of every
  GPT-RAG naming occurrence across the umbrella repository (including the
  incorporated infrastructure) and the three component repositories. Each
  occurrence is classified as rename or historical record.
- **FR-004**: The release supports new deployments only. The release notes and
  the documentation MUST state this in one short note: existing GPT-RAG
  environments are not upgraded and can keep running on their GPT-RAG release,
  whose tags stay available.
- **FR-005**: The application UI MUST show the new name and visual identity
  (title, logo, and product text). From the preview, the visual identity is a
  text wordmark "Agent Landing Zone" with an existing generic icon, with no
  GPT-RAG logo left. A designed logo is optional and may replace it in
  `v4.0.0` or later; it never blocks a release. Public material MUST identify
  the product as Agent Landing Zone (GPT-RAG solution accelerator) and avoid
  implying affiliation with the Copilot Studio offering of similar name.

**Repositories and releases**

- **FR-006**: The umbrella GPT-RAG repository and the UI, orchestrator, and
  ingestion component repositories MUST be renamed to their new names. The
  history, issues, pull requests, releases, and tags MUST be preserved, and the
  platform's automatic redirects from the former names MUST keep working. The
  target names keep the application independent of the landing zone so that
  other application patterns can be added later:

  | Current repository | New repository |
  | --- | --- |
  | `Azure/GPT-RAG` | `Azure/agent-landing-zone` |
  | `Azure/gpt-rag-ui` | `Azure/agent-app-ui` |
  | `Azure/gpt-rag-orchestrator` | `Azure/agent-app-orchestrator` |
  | `Azure/gpt-rag-ingestion` | `Azure/agent-app-ingestion` |

  On 2026-09-29, all four target names were unused in the `Azure` organization.
  Paulo MUST re-verify their availability immediately before the rename; if
  any target name is taken, the rename MUST stop until Paulo approves a
  fallback name. A documented reversal procedure to rename the repositories
  back and restore pins, URLs, and release metadata MUST be approved by Paulo
  before any rename.
- **FR-007**: The release manifest, component pins, deployment scripts, and
  release metadata MUST refer only to the new repository names and MUST still
  resolve to the correct validated versions. Published images, workflow
  references, badges, release links, and repository metadata that contain old
  names MUST be audited and updated; forks are out of scope because repository
  redirects cover them.
- **FR-008**: The first Agent Landing Zone release MUST be a new major version
  (`v4.0.0`), because it changes names that users and automation depend on.
  It is preceded by a preview (`v4.0.0-preview.1`) that is marked as a
  pre-release and not recommended for production (see Delivery Phases).
  Component repositories keep their version history and take a major bump:
  UI `v3.0.0`, orchestrator `v5.0.0`, and ingestion `v3.0.0`. Component
  releases pinned by the preview use the same `-preview.1` pre-release suffix
  (for example `v3.0.0-preview.1`).
- **FR-009**: The release notes MUST include the full component version table,
  the transition statement, and the new-deployments-only note (FR-004).
- **FR-010**: The deployment template's public metadata (template name,
  catalog title, and description) MUST use the new name.

**Infrastructure incorporation**

- **FR-010a**: The Bicep infrastructure currently consumed as a submodule from
  `Azure/bicep-ptn-aiml-landing-zone` MUST be incorporated into the Agent
  Landing Zone repository as regular, versioned source. It is then developed,
  reviewed, validated, and released there with a single release version.
  The incorporation copies the files of the last pinned tag (`v2.7.3`, or a
  later tag if one is pinned before the copy) in one provenance commit that
  names the source repository and tag. The earlier commit history stays in
  `Azure/bicep-ptn-aiml-landing-zone` and is not imported.
- **FR-010b**: The incorporation MUST preserve the functional behavior of the
  last pinned infrastructure version. Deploying the incorporated
  infrastructure with the same parameters MUST produce the same resources,
  apart from the renamed identifiers.
- **FR-010c**: The infrastructure's validation and Bicep-to-Terraform parity
  workflows MUST run from the Agent Landing Zone repository and keep targeting
  the Terraform module `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone`,
  with mandatory human review of the resulting changes.
- **FR-010d**: The `Azure/bicep-ptn-aiml-landing-zone` repository MUST stay
  available with its history and tags until it is frozen and archived. Before
  archival, all open issues and pull requests MUST be triaged by transferring,
  linking, or closing them with rationale. A notice at the top of its README
  MUST state exactly "This repository has moved to Azure/agent-landing-zone."
  and MUST link to `Azure/agent-landing-zone`. It receives no new development.
  Existing consumers keep working on their pinned tags.
- **FR-010e**: The release manifest MUST stop pinning a separate
  infrastructure version, because the infrastructure version is the release
  version.

**Deployment layers**

- **FR-011**: Operators MUST choose the deployment option with the native
  `azd` verbs in the same repository, without a new flag or entry point.
  `azd provision` is infrastructure only, `azd deploy` publishes the
  application, and `azd up` (the documented default) does both.
- **FR-012**: An infrastructure-only deployment (`azd provision`) MUST create
  and configure all Azure resources, including one Container App per
  Container App component in the application definition (FR-015a), running a
  placeholder image. Hosted-agent components get no placeholder; they are
  created at `azd deploy`. It MUST NOT publish any application component
  image. The result MUST be ready for
  `azd deploy` without further changes. The first `azd provision` binds the
  environment to the application definition in use (FR-015g); without
  `AGENTLZ_APP_DEFINITION`, that is the bundled trio. It MUST enforce the same
  network isolation, managed identity, Key Vault, and least-privilege security
  posture as the full deployment. Removing the application layer from an
  existing environment MUST require explicit operator confirmation, list the
  affected resources, and never happen implicitly during provision or deploy.
- **FR-013**: Operators MUST be able to add the application later with
  `azd deploy` on an existing infrastructure-only environment, without
  re-creating the foundation. Running `azd provision` again MUST NOT reset
  published component images to the placeholder.
- **FR-014**: The application layer MUST start with the current three
  components (UI, orchestrator, and ingestion). It MUST keep the choice between
  the classic orchestrator and the Foundry hosted-agent orchestrator, with the
  same capabilities, security posture, and network-isolation options as the
  last GPT-RAG release.
- **FR-015**: The application layer MUST be defined as a pluggable unit on
  top of the foundation, bound to an environment at its first
  `azd provision` (see FR-015g).
  Every application, including the default, MUST be described by an
  application definition (`app-definition.json`) and deployed through the same
  flow (FR-015a to FR-015h). The bundled trio (FR-014) is the default
  application: its `app-definition.json` ships in the Agent Landing Zone
  repository and resolves component versions from the release manifest
  (`manifest.json`) instead of duplicating them. The trio declares three
    components: in classic mode, UI, orchestrator, and ingestion are Container
    Apps; in hosted-agent mode, UI and ingestion are Container Apps and the
    orchestrator is a hosted agent. An operator MAY instead deploy a custom application with its own
  definition. Delivering a second Microsoft-maintained application pattern is
  out of scope.

**Application definitions and custom applications**

- **FR-015a**: An application definition (`app-definition.json`) declares what
  the application needs from the foundation: a stable `id` (lowercase slug;
  the bundled trio has a fixed `id`), a list of one or more components, its
  capability profiles, and its App Configuration keys. Each component is
  either a Container App (classic) or a Foundry hosted agent; a definition
  MAY declare zero or more of each. The format
  MUST be a versioned schema (v1) published in `contracts/`, shared by the
  bundled and custom definitions. A custom application MUST be a local folder
  that contains its `app-definition.json` and its own `azure.yaml`. The
  bundled trio is the exception: its `app-definition.json` and `azure.yaml`
  live at the Agent Landing Zone repository root.
- **FR-015b**: The operator MUST select a custom application with
  `azd env set AGENTLZ_APP_DEFINITION <local path>` before the environment's
  first `azd provision` (or `azd up`), and then run the same `azd up` or
  `azd deploy` from the Agent Landing Zone repository. The landing
  zone orchestrates the whole flow with one command: it creates the declared
  Container Apps, role assignments, and configuration keys, builds and pushes
  the images to the landing zone's container registry, and deploys the
  application. When the variable is not set, the bundled trio's
  `app-definition.json` is used.
- **FR-015c**: A custom application MUST be able to run as classic Container
  Apps services only, as Foundry hosted agents only (`azure.yaml` services
  with `host: azure.ai.agent`), or as a mix of both, as declared in its
  component list (FR-015a). The hosted-agent path MUST keep the
  same security posture and network-isolation options as the bundled hosted
  orchestrator.
- **FR-015d**: Every definition, bundled or custom, MUST be validated against
  the schema before any
  Azure resource is created or changed. An invalid definition, an unknown
  capability profile, or a missing hosting prerequisite MUST fail closed with
  an actionable message (FR-016).
- **FR-015e**: Permissions MUST be granted only through a fixed set of
  capability profiles maintained by the landing zone: `base`, `model-user`,
  `retrieval-reader`, `conversation-store`, `blob-delegator`, and
  `ingestion-writer`. This also
  applies to the bundled trio, so the profile set MUST cover its current
  permissions. A definition MUST NOT declare free-form role assignments, remote source URLs,
  or lifecycle hooks. Application sources MUST be pinned (commit or image
  digest).
- **FR-015f**: The landing zone MUST publish a machine-readable platform
  outputs contract (endpoints and identifiers of the Foundry project, container
  registry, App Configuration, Search, storage, and identities) in App
  Configuration, with a versioned schema in `contracts/`. A custom
  application reads it at run time through `APP_CONFIG_ENDPOINT`.
- **FR-015g**: An environment MUST host exactly one application. The binding
  happens at the environment's first `azd provision`, using
  `AGENTLZ_APP_DEFINITION` or, when it is not set, the bundled trio. The landing
    zone MUST save the application definition's `id` in the azd environment
    (`.azure/<env>/.env`) and MUST reject a provision or deploy whose
    definition has a different `id`, with a message to create a new
    environment. Redeploying the same application, including new versions of
    it, MUST be allowed.
  Migrating, switching, or combining applications in one environment is out of
  scope; a different application requires a new environment.
- **FR-015h**: The release MUST include a minimal sample custom application
  that deploys in both hosting modes (one Container App component with a
  health endpoint and one hosted-agent component, each reading the platform
  outputs contract of FR-015f), and a "Build your own application" page
  in the central documentation.
- **Fallback**: If FR-015b or FR-015c cannot be validated end to end by
  2026-10-09, `v4.0.0` ships FR-015a, FR-015d (as a standalone validation
  command), FR-015f, and FR-015h, documents custom application deployment as a
  manual procedure, and lists the one-command orchestration as pending in the
  release notes. The fallback never blocks the release.
- **FR-016**: Every deployment option MUST validate all prerequisites, the
  application definition, and the selected option before changing any
  resource, and MUST fail closed with an actionable message when any are
  invalid. A failure after changes begin MUST be recoverable by re-running the
  same command (idempotent; it converges to the intended state). No automatic
  rollback, and no silent fallback to another option.

**Documentation and discoverability**

- **FR-017**: The detailed documentation MUST move to an Agent Landing Zone
  section of the central AI Landing Zones documentation site. The former
  GPT-RAG documentation site MUST stop being maintained as a separate source,
  and readers who reach it through short links or repository links MUST be
  pointed to the central site (see Edge Cases for the GitHub Pages limit).
  The former docs branch MUST be frozen, moved notices MUST be published on
  the former site where technically possible, and the GitHub Pages redirect
  limitation MUST be documented. Preview documentation MUST include, at
  minimum, an overview, architecture, full-stack deploy guidance,
  infrastructure-only deploy guidance (marked as coming in `v4.0.0` if not
  yet shipped), and component/application-definition guidance.
- **FR-018**: The repository README MUST become a short landing page with a
  description, an architecture diagram, the transition statement, the
  deployment options available in that release, and links to the central
  documentation, without duplicating it. At the preview, the landing page
  lists infrastructure plus application as the available option and states
  that infrastructure only arrives in `v4.0.0`. From `v4.0.0`, it lists both
  options.
- **FR-019**: The central documentation MUST cover both deployment options,
  both orchestrator modes, custom applications ("Build your own
  application"), configuration, operations, the Bicep and Terraform
  infrastructure paths, and the new-deployments-only note.
- **FR-020**: Short links have two levels:
  - Blocking, at the repository rename: no existing GPT-RAG short link may
    land on a broken page. Each one reaches its equivalent destination, the
    Agent Landing Zone documentation section, or a moved-content notice.
  - Non-blocking: retargeting each short link to its exact equivalent page
    and securing new short links for the new name, where available. Anything
    not done by 2026-10-09 is listed as pending in the `v4.0.0` release notes.
  An inventory of every existing GPT-RAG short link MUST be maintained with
  its new destination or notice.
- **FR-021**: Repository-owned engineering guidance (agent instructions,
  skills, issue and pull request templates, and contribution guides) MUST use
  the new name and the new documentation location.

**Governance and quality**

- **FR-022**: The consolidation, the infrastructure incorporation, the
  deployment-layer boundary, the custom application extension mechanism, and
  the new-deployments-only policy MUST be recorded as architectural decisions
  before implementation. Paulo, as maintainer, MUST approve each ADR before
  implementation.
- **FR-023**: The project constitution and operating instructions MUST be
  amended before the corresponding change lands. The amendments cover two
  rules. Product documentation moves from this repository's `docs` branch to
  the central documentation site. The infrastructure becomes repository-owned
  source instead of a read-only submodule. Paulo, as maintainer, MUST approve
  the constitution amendment before implementation.
- **FR-024**: Each deployment option and each orchestrator mode MUST be
  validated end to end before release, and the validation evidence MUST
  identify the exact component combination.

### Key Entities

- **Agent Landing Zone**: The offering. It consists of an infrastructure layer
  and an optional application layer, one release version, and one
  documentation section.
- **Infrastructure layer**: The secure, governed foundation. The Bicep source
  lives in the Agent Landing Zone repository and ships with the release
  version. Terraform stays in its own module, kept in parity.
- **Application layer**: A pluggable agent application, bound to an
  environment at its first `azd provision` and deployed on the foundation. The default one consists of the UI, orchestrator, and ingestion
  components, with a classic or hosted-agent orchestrator mode. Exactly one
  application per environment.
- **Application definition**: The `app-definition.json` file that describes
  an application, used both by the bundled default trio (shipped in the
  repository) and by custom applications. It declares one or more components
  (each a Container App or a hosted agent), capability profiles, and
  configuration keys, and conforms to the v1 schema. Its stable `id` is saved per environment.
- **Capability profile**: A named, landing-zone-maintained bundle of
  permissions (for example `retrieval-reader`) that an application definition
  may request. The only way an application obtains access.
- **Platform outputs contract**: The versioned, machine-readable set of
  foundation endpoints and identifiers that the landing zone publishes in App
  Configuration for applications to consume.
- **Deployment option**: The operator's choice between infrastructure only and
  infrastructure plus application.
- **Release manifest**: `manifest.json`, maintained by Microsoft. The
  authoritative list of the validated combination of the release version and
  the component repositories and versions. The infrastructure is referenced
  by `infra.source` (repository, tag, commit) as the in-repo source, not as a
  separately versioned component (FR-010e).
  Operators do not edit it; it is distinct from the application definition,
  which only references it for the bundled trio's versions.
-  **Naming inventory**: The classified list of every GPT-RAG naming
  occurrence, used to prove FR-002.

### Delivery Phases

| Phase | Date | Release | Scope |
| --- | --- | --- | --- |
| 1 - Public rebrand | by 2026-10-02 | `v4.0.0-preview.1` (pre-release) | FR-001, FR-004, FR-005, FR-006, FR-007, FR-009, FR-010, FR-018, FR-021, FR-022, FR-023; a minimal Agent Landing Zone section on the central site, a moved-content notice at the renamed site location, and the blocking level of FR-020 (first part of FR-017) |
| 2 - Structure | by 2026-10-09 | `v4.0.0` | FR-002, FR-002a, FR-003, FR-010a to FR-010e, FR-011 to FR-016 (including FR-015a to FR-015h, or their fallback) |
| 3 - Finish | by 2026-10-09 | `v4.0.0` | FR-017 (complete migration), FR-019, FR-020, FR-024, and the final scan (SC-001) |

- The architectural decision and the constitution amendments (FR-022,
  FR-023) land first, because every other change depends on them.
- In every phase, component releases are published before the umbrella
  release that pins them.
- The repositories are renamed at the end of Phase 1, right before the
  preview is published, so that links do not break during the work.
- The blocking level of FR-020 (no broken short link) is part of the Phase 1
  rename. Only its non-blocking level (exact retargeting and new short links)
  may stay pending at `v4.0.0`.

**Acceptance by phase**

| Release | User story scenarios that apply | Success criteria that apply |
| --- | --- | --- |
| `v4.0.0-preview.1` | US1 scenarios 1, 2, and 4 (branding limited to SC-008 surfaces); US3 scenario 1; US4 scenarios 1, 2, and 3 | SC-002, SC-005, SC-007 (preview date), SC-008 |
| `v4.0.0` | All scenarios of US1 to US5 (US5 scenarios 1 and 2 are replaced by the manual procedure if the FR-015 fallback applies) | SC-001 to SC-007, SC-009 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An automated scan of the shipped release, including repositories,
  release notes, deployment output, created resource names and tags, and the
  application UI, finds zero GPT-RAG naming occurrences outside historical
  records and the transition statement. The scan MUST cover the umbrella
  repository and the three component repositories, plus deployed resource
  names, App Configuration keys, image names, and UI text.
- **SC-002**: A new operator can deploy each option (infrastructure only, and
  infrastructure plus application in each orchestrator mode) from a fresh
  clone by following only the central documentation, with no undocumented
  step. Deployment time stays within 10% of the baseline: the average of 3
  `azd up` runs of the last GPT-RAG release (`v2.7.x`) in the same region
  and topology, with the same parameters.
- **SC-003**: 100% of the former repository URLs, clone URLs, and published
  GPT-RAG short links reach the renamed destination or clear guidance.
- **SC-004**: 100% of the former GPT-RAG documentation pages reached through
  short links or repository links lead to an equivalent Agent Landing Zone
  page or a moved-content notice. Direct visits to the former site URL are
  excluded (see Edge Cases). A source-to-destination mapping of every former
  documentation page MUST be published, with each page classified as
  redirected, notice-only, or replaced.
- **SC-005**: After `azd provision`, zero application component images are
  published (all Container Apps run the placeholder image). A later
  `azd deploy` re-creates zero foundation resources, and a repeated
  `azd provision` resets zero published images.
- **SC-006**: Every functional capability documented for the last GPT-RAG
  release passes its validation in the first Agent Landing Zone release, with
  no functional regression. The capability inventory is the set of
  capabilities documented for the last GPT-RAG release, including deployment
  modes, hosted agents, networking, configuration, operations, and
  troubleshooting, and it MUST be recorded as a checklist artifact.
- **SC-007**: The preview (Phase 1) is published by 2026-10-02, and the
  `v4.0.0` release (Phases 2 and 3) is published by 2026-10-09.
- **SC-008**: At the preview, the repository names, landing page, application
  UI, template metadata, and release notes contain zero GPT-RAG naming
  occurrences outside historical records and the transition statement. SC-001
  applies in full from `v4.0.0`.
- **SC-009**: Starting from a fresh clone, the sample custom application
  deploys with one `azd up` in each hosting mode (classic and hosted agent),
  with zero changes to landing zone files. An invalid definition and a changed
  definition on an existing environment are both rejected before any Azure
  resource changes. Under the FR-015 fallback, the sample deploys by following
  only the documented manual procedure.

**Phase assignment**: SC-002 and SC-005 apply in both the preview and
`v4.0.0` phases; SC-003, SC-004, and SC-006 apply at `v4.0.0`.

## Assumptions

- The final name is "Agent Landing Zone", chosen on 2026-09-24. The
  possible confusion with an internal, non-public Copilot Studio delivery
  framework was accepted.
- The central documentation is the Agent Landing Zone section of the
  AI Landing Zones site (`Azure/AI-Landing-Zones`), maintained by Paulo Lacerda
  and Bilal Amjad. The AI Gateway Landing Zone section keeps its own owners.
  Before the documentation migration starts, maintainers confirm write access,
  required reviewers, and the publishing workflow for the
  `Azure/AI-Landing-Zones` site.
- A migration path from GPT-RAG (guide, tooling, or detection of existing
  environments) is out of scope for this release. It can be added later if
  customers need it.
- The Bicep infrastructure moves into the Agent Landing Zone repository. The
  Terraform module stays in its own repository, and its name is out of scope.
  The Bicep-to-Terraform synchronization keeps its current model (agentic pull
  requests with human review) and only changes its source repository.
- Other projects that consume `Azure/bicep-ptn-aiml-landing-zone` as a
  submodule (for example `Azure/live-voice-practice`) are not migrated by this
  feature. The README notice tells them where development continues.
- This repository's end-to-end deployment experience remains Bicep-based.
  Terraform users consume the infrastructure layer through the Terraform
  module, as documented.
- The hybrid, maturity-based use of AVM resource modules and publishing the
  solution as an AVM pattern module are separate efforts and out of scope.
- New Microsoft-maintained application patterns (for example document
  processing or customer service) and a portal-based deployment are out of
  scope. Third parties can bring their own application through the
  application definition (FR-015a to FR-015h).
- For custom applications, the following are out of scope: migrating or
  switching applications in an existing environment, more than one application
  per environment, an application catalog or marketplace, remote definition or
  source URLs, lifecycle hooks, and free-form role assignments. The
  application definition schema is preview-level in `v4.0.0` and may change in
  a later major version.
- The platform's repository-rename redirect covers web and clone URLs for as
  long as no new repository reuses a former name. The former names must
  therefore never be reused.
- Changes to the component repositories (UI, orchestrator, and ingestion) are
  coordinated in the same release and bound by the release manifest.
- Short-link ownership changes depend on the teams that own those links.
  Unavailable names are documented, not blocking.
- The delivery is split into two dates (see Delivery Phases): the public
  rebrand as a preview by Friday, 2026-10-02, and the complete `v4.0.0` by
  Friday, 2026-10-09. Ignite 2026 happens in November, but the final
  structure, branding, and name must be ready well before it (2026-09-23
  guidance). The issue's original target was the end of September 2026.
- Phase 2 and Phase 3 work (infrastructure incorporation, runtime identifier
  renames, and the documentation migration) starts during the week of
  2026-09-29, in parallel with Phase 1, and is published only with `v4.0.0`.
- Operators who deploy the preview must redeploy with `v4.0.0`, because the
  runtime identifiers change between them. The preview release notes say so.
- The issue's original "naming and surface only" scope is expanded by the
  2026-09-24 decision to include the infrastructure-only deployment option.
