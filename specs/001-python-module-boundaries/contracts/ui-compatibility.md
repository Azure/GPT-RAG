# Proposed Contract: UI Module Ownership and Compatibility

**Version**: design 1

**Baseline**: UI `c635bc6696714b543feec24b4a062a8a8f3ff6d0` (runtime equivalent
to manifest tag v2.6.2 in the researched comparison).

**Scope**: FR-009 through FR-015. API/schema payloads are not redefined here.

## U1. Ownership and allowed dependency direction

`bootstrap` owns application composition. `api` owns FastAPI routes, Chainlit
callbacks and framework data-layer registration. `services` owns user operations
and security-sensitive conversation/download policy. `auth` owns identity,
token and session primitives. `clients` owns service transport. `config` owns
the existing AppConfig adapter/cache and typed settings. `telemetry` owns
instrumentation. `util` owns pure constants/helpers only.

Allowed first-party area edges:

| Importer | Allowed lower areas |
| --- | --- |
| bootstrap | api, services, auth, clients, config, telemetry, util |
| api | services, auth, clients, config, telemetry, util |
| services | clients, auth, config, telemetry, util |
| clients | auth, config, telemetry, util |
| auth | config, telemetry, util |
| telemetry | config, util |
| config | util |
| util | none |

Within each area, the full module graph must remain acyclic. No package
implementation imports root legacy modules. Package `__init__` files are inert
or explicitly export lightweight public contracts; they do not create clients,
applications or callbacks. Each area declares public functions/types and private
implementations; exporting everything to avoid a violation is not acceptable.

The responsibility map covers every researched runtime root. It is not an
instruction to copy mixed files wholesale:

| Current module(s) | Canonical owner / necessary separation |
| --- | --- |
| `main` | `bootstrap` and `api`: ASGI construction, middleware, mount order; root retains only adapter/path handoff |
| `app` | `api` callbacks and `services` chat/citations: reusable logic separated from event registration |
| `dependencies`, `connectors.appconfig` | `config`: one AppConfig provider and cache; legacy exports point to it |
| `constants` | `util`: pure shared values |
| `auth_common`, `entra_token`, `embed_auth`, `embed_security` | `auth`: current identity/token/embed semantics |
| `auth_oauth` | `auth`: refresh/token logic; `api`: OAuth callback registration |
| `embed_config`, `panel_config`, `hosted_continuity_config`, `chat_backend` | `config`: existing settings/types and precedence |
| `orchestrator_client`, `ingestion_client`, `hosted_agent_client`, `connectors.blob` | `clients`: preserve request/response/error and credential behavior |
| `hosted_conversation_store`, `hosted_conversation_capability` | `clients`: authenticated managed-Conversations access and capability evidence |
| `conversation_security` | `services`: conversation ownership using lower auth/client APIs |
| `download_security` | `services`: ownership/token/URL decisions; `api`: route registration and response adaptation |
| `hosted_continuity` | `services`: coordinator and continuity state transitions |
| `datalayer` | `services`: history behavior; `api`: Chainlit data-layer adapter/decorator |
| `feedback` | `services`: feedback operations; `api` only for framework callbacks |
| `panel_auth` | `auth`: panel identity checks |
| `panel_cosmos` | `clients`: existing Cosmos transport/config consumption |
| `panel_cursor` | `services`: pagination/cursor contract |
| `panel_store` | `services`: panel persistence behavior over client transport |
| `panel_routes` | `api`: public HTTP routes and error translation |
| `telemetry` | `telemetry`: existing telemetry behavior, no new shared schema |
| `connectors.__init__` | Legacy facade for inventoried AppConfig/Blob public imports |

For each row, inventory individual public symbols and responsibility tests before
the first move. This is the review gate for ambiguous external imports, not
permission to classify them private after breaking them.

## U2. Startup and supported imports

Keep `uvicorn main:app --host 0.0.0.0 --port 8080`, root `app` handler loading,
and any additional startup command established by the compatibility inventory.
Root files are explicit adapters to canonical APIs, not duplicated implementation.
Do not introduce module-level `sys.modules` proxies or `sys.path` manipulation.

The ASGI application, config provider, telemetry initialization, backend
clients, continuity coordinator and callback registry each have one canonical
owner/lifecycle. Importing canonical modules and then legacy adapters, or the
reverse order, must not register callbacks twice, instantiate another store, or
fork a config cache. Keep a directly testable initialization/registration API.

Preserve auth/environment setup before Chainlit import and the mount order for
panel/download/Chainlit routes. Hosted-only imports and active panel validation
remain conditional. Classic backend startup must not create panel Cosmos or
managed-Conversations clients. Do not hide invalid active configuration.

Supported exported callables/classes forward to the canonical implementation.
Internal tests patch canonical ownership after migration, particularly cached
config and callback collaborators. Arbitrary external mutation of private
globals is not a new compatibility promise; any evidence of an existing
supported integration relying on it requires explicit review before changing it.

## U3. Installation and deployment resources

The UI distribution installs `gpt_rag_ui` plus explicitly inventoried legacy
modules/packages. Initially, `requirements.txt` remains the runtime dependency
source; the wheel contains project code, not a second drifting dependency list.
Install runtime requirements before installing the wheel; editable installation
is for local development only and is never the sole packaging acceptance test.

Retain deployment assets `public/`, `.chainlit/`, `chainlit.config.yaml`,
`chainlit.md`, and `VERSION` in the application asset root. Docker continues
staging them under `/app` and using the existing Uvicorn target. Do not require
operators to change their existing deployment/start command.

For a source adapter beside existing assets, pass that directory into bootstrap.
For installed-code operation, use the existing Chainlit `CHAINLIT_APP_ROOT`
setting pointing to the staged asset bundle, or the staged application working
directory. Resolve the root once and use it consistently for VERSION, config,
public content and temporary/writable directories **before importing Chainlit**.
Do not infer an asset directory by walking up from installed package `__file__`.

The supported installed artifact is code plus its staged deployment assets.
A standalone wheel without those assets is not claimed to be self-contained.
The new out-of-checkout acceptance test explicitly uses that bundle and a
non-repository working directory; it must not import root Python sources by
accident. No application writes occur in site-packages.

Preserve existing resource-missing outcomes: for example, optional VERSION
absence and warning behavior for absent Chainlit config are not changed into a
new fatal error merely by moving code. Conversely, a missing package/build file
is a packaging failure, not a reason to serve an apparently healthy substitute.

## U4. Compatibility inventory and acceptance matrix

Record all supported routes/imports/settings discovered from source, tests,
Docker/lifecycle scripts and docs. Freeze before/after observable results for
each row, including intentionally unsupported or disabled outcomes.

| Surface | Required unchanged behavior / representative existing coverage |
| --- | --- |
| Startup and health | Auth-before-Chainlit; disconnected AppConfig produces not-ready state; `test_main_policy.py`, `test_main_panel_wiring.py` |
| Auth and embedding | Normalized tenant/object identity, validated tokens, expiry/audience/issuer/allowlist/session policy; auth/entra/embed tests |
| Backend selection | Existing precedence and default (`hosted_agent`); explicit invalid backend raises; no implicit hosted/classic substitution |
| Conversations and history | Owner enforcement, existing managed/persisted conversation behavior; datalayer/security/hosted-conversation tests |
| Citations and downloads | Opaque tokens, allowed source URLs, conversation ownership and rendered links unchanged; citation/download tests |
| Continuity and panel gates | Existing opt-in flags and capability gates; classic panel path inert; invalid active settings visible; continuity/panel wiring tests |
| Panel API | Existing methods, routes, fields and 401/403/404/422/503 mappings retained; panel route/auth/store tests |
| Feedback | Existing authorization, payload and failure semantics; feedback-security and panel tests |
| Telemetry and audit | Existing contract/schema hashes and redaction unchanged; narrowly documented best-effort side effects remain such |
| Resources | `.chainlit`, public assets, VERSION footer and writable upload behavior use the staged root |
| Public imports and registration | Each inventoried legacy import and new canonical equivalent works in both import orders, with single initialization |
| Deployment | Existing image/startup, AppConfig endpoint precedence, credential selection, ACR and network-isolated deployment semantics |

The UI remains the authenticated BFF owner of managed Conversations. The hosted
container remains stateless with zero Conversations data-plane RBAC, per
[ADR-0004](../../../docs/adr/ADR-0004-hosted-panel-conversations-contract.md).
Do not move BFF calls into the orchestrator while reorganizing Python files.

Each migration PR proves the affected inventory entries and prior entrypoint
smoke checks; the final package PR proves the entire matrix, distribution file
inventory, non-editable installation and Docker parity. No row is satisfied by
importing only from an editable source tree.
