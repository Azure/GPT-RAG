# Tasks: Enforce Module Boundaries and Modularize the UI

## Authorized initial adoption - 2026-09-09

The maintainer explicitly approved the 189 justified existing exceptions,
initial administrative adoption, adoption merges and activation of required
checks, excluding production deployment. The authorization is recorded at
https://github.com/Azure/GPT-RAG/issues/681#issuecomment-5601804634.
It supersedes the unanswered authorization requests recorded below. It is
administrative approval, not an independent GitHub review or a fabricated
green bootstrap result.

Activation and adoption have completed in the three components: 92 orchestrator,
67 ingestion and 30 UI exceptions are active under the recorded authorization.
Each adopted head preserves the justified handlers and behavioral evidence;
functional checks passed and the initial bootstrap exception is recorded below.
Real reference PRs against the adopted base passed before additive required-check
rules were enabled. Negative controls and restoration are recorded separately.
Existing protections remain intact. Live acceptance evidence is not inferred
from administrative permission or unit tests.

At the maintainer's request, all review requests to `gxjorge` were removed,
and automated waiting for that review was disabled. No further requests to
other reviewers are authorized by this adoption.

Verified initial adoption merges:

| Component | Activation head | Develop merge | Initial CI |
| --- | --- | --- | --- |
| Orchestrator | `360065cb194f33e631fdf34c0e1c1eeb11935da3` | `c6339ee5738c0a0bb890b43f204f2d4ba1025157` | `34352193611`: tests/frontend/lint/typing/architecture/exceptions pass; bootstrap policy and aggregate fail |
| Ingestion | `54397563c51b8fbfad138a3c4763a3c7e12ac6ce` | `18c18431fa8a83d4bcc1362f60bf1c6092ed865a` | `34351954943`: functional/frontend/lint/typing/architecture/exceptions pass; bootstrap policy and aggregate fail |
| UI | `bbf65dea49bd188cf40bfdc718fe002b240e6a40` | `151c0b2d3d783e835e9565fde8dcc818c8f9f4b1` | `34352005742`: unit/container/typing/architecture pass; initial protected-base-dependent gates fail |

These bootstrap failures were explicitly accepted under the initial
administrative authorization, not reported as green. The following genuine
reference runs use those adopted merge commits as their protected bases, not HEAD:

| Component | Reference PR | Clean head | Successful reference run | Active ruleset |
| --- | --- | --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#359 | `6a7ad2c5127875666403279a31874fac670374d0` | `34353356772` | `22663326` |
| Ingestion | Azure/gpt-rag-ingestion#308 | `c41527204ef876ae4410c77045df2e7085e11b1d` | `34352952858` | `22640997` |
| UI | Azure/gpt-rag-ui#112 | `f4cf2d21209ebf69b0cf7f53e5e84313e34303e7` | `34352974880` | `22641145` |

All three rulesets are active on `develop` and `main`, have no bypass actors,
and require strict GitHub Actions app `15368` checks. Required contexts are
`quality-gate` / `tests` / `frontend build` for orchestrator;
`quality-gate` / `unit-tests` / `frontend-checks` for ingestion; and
`quality-gate` / `unit-tests` / `container-tests` for UI. Each adds deletion and
non-fast-forward protection, one approving review, code-owner review, stale
approval dismissal, last-push approval and resolved review threads. Previously
existing rules are retained. No feature was merged to `main`; future release
PRs must include the adopted policy through the normal release flow.

### Controlled negative checks and restoration

| Component | Negative head / failing run | Observed failure | Restored head / passing run |
| --- | --- | --- | --- |
| Orchestrator | `e9a8c1584032c3381a72cbfa1a96aba270832fb9` / `34380617414` | RUF100 unused noqa, policy suppression and quality-gate fail; functional checks pass | `707231a228f9c3b1cd281e4b7e16169fb1149147` / `34381235501` |
| Ingestion | `c11e995e69a7c579308da48ae964d4e342af5ef6` / `34353567295` | RUF100 unused noqa, policy new-suppression and quality-gate fail; functional checks pass | `03cb8a218e47a3e3cee3f6621e3a186bf9cf596e` / `34354094883` |
| UI | `344ee17da79c52df38204928021d2da16373afd0` / `34353672894` | RUF100 unused noqa, policy suppression-growth and quality-gate fail; functional checks pass | `69492e4a965263362e6d17b7c3b7a8779047dd7e` / `34354232272` |

All three PRs were BLOCKED with the required gate failing. Review requirements
also independently block merges, so BLOCKED alone is not attributed solely to
the negative fixture. Only each fixture was reverted; restored trees match
the original clean reference trees. All three reference PRs are closed unmerged.
Ingestion's proof exercises RUF100 and suppression growth, not F401 (which is
not selected). Orchestrator's completed
[receipt](https://github.com/Azure/gpt-rag-orchestrator/pull/359#issuecomment-5605868380)
records all eight restored jobs passing, the actual adopted base with
`bootstrap=false`, and identical reference/restored tree
`a938d1105f03a758e15e2f4ab1875a3b458a9d98`. Required checks are active;
no knowingly failing fixture was merged.

### Remaining acceptance

Parent #689 and canonical documentation #688 still require final evidence
updates and disposition. Live ACL, coordinated-component and recovery
acceptance have not been performed: no authorized nonproduction target and
test-principal setup has been supplied. The unanswered environment question
does not waive these criteria. No production deployment, release, tag or
manifest change was performed. #681 remains open; historical pending-approval
and inactive-policy statements below describe earlier checkpoints only.

## Adoption preparation - 2026-09-09

Parallel readiness reviews examined all 189 current proposals; none was
activated. Orchestrator `cb6e2f3a34f0123aeb39ceaaf0c0063078318ac6` corrects
two obsolete H5 rationales and 28 display locators, retaining all 92 exact
handler identities and evidence selectors. Ingestion
`0ae3759356935830c532ce3f2c48d3753b01da73` corrects only obsolete feedback-test
prose; all 67 proposals and runtime remain unchanged.

UI `57d054cb889be99d3faa48713d13dfc1f5ddca94` fixes an adoption defect:
Ruff BLE001 now honors only exact protected-base active handler records with
verified behavioral evidence. It does not allow candidate self-approval,
other diagnostics or unmatched handlers. The 53 policy tests include 13 new
regression cases. All 30 runtime proposals remain unchanged.

The authenticated account has administrator permission. Q5 permits a recorded
administrative exception for initial adoption, but the focused requests for
exact exception activation and bootstrap-red acceptance received an unavailable
user response, not approval. No activation, merge or settings change occurred.
Independent review and administrative acceptance must not be fabricated.

A policy-file-only extraction is not a coherent bootstrap: the inventories,
typing scope and evidence reference runtime modules absent from develop.
The initial coherent adoption therefore requires explicit approval of its
runtime/policy combination and bootstrap-red state. After adoption, a clean
reference PR against the actual adopted base must pass before additive required
checks and negative merge-eligibility controls establish enforcement. Existing
protections must be retained. Live acceptance requires separately authorized
environment access and distinct owner/non-owner principals.

Final-head runs are complete: orchestrator `34343153421`, ingestion
`34342868354`, UI `34343550332`. Each passes functional tests/builds, typing
and architecture; each fails lint, exceptions, policy and quality-gate.
The UI fix does not waive proposed records or bootstrap restrictions.
This preparation supersedes earlier candidate heads but does not establish
issue acceptance. Runtime and source-pinned product documentation are unchanged.

## Reconciliation receipt — 2026-09-09 (final functional reconciliation)

**All original functional implementation dispositions are done; #681 is not
complete. 191 = 143 keep recommendations + 48 functional closures + 0
technical open.** All **189 proposals (92/67/30) remain unapproved and inactive**.
This final receipt supersedes the snapshot below; prior receipts are history.

Verified clean component worktrees and matching OPEN draft PR heads to develop:
- Orchestrator: `ea61bc7cd7b2ac21c957bee5db959337fedd8760`.
- Ingestion: `876c4272374868c15c4f4c3d67f93e1f3dd84e85`
  (runtime `eb42bbb155613ba570f891b67366967387735e32`).
- UI: `aef9546879333c8615b7adb3917f299a665f4ecc`.
- Canonical docs: `bc75d12584ef967d6a38a6f0dcbc176428b00a25` on #688;
  final UI source pins and retry guidance are included. Strict MkDocs passed.

The last original functional finding, `ui-boundary-23`, closes on committed
new-ID rollback and real two-attempt tests: all reattached files are ingested
before the retry question, for false/exception failures and fresh/existing
conversations; existing ownership remains enforced. Independent agent review
reported no significant issues (handoff evidence, not maintainer approval).
H1–H7 are delegated agent selections, not separate human approvals; H0 unchanged.

Final CI is **completed, FAIL overall in all three repositories**:
orchestrator run `34300904165` tests/frontend/typing/architecture pass;
ingestion run `34299688281` unit/frontend/typing/architecture pass;
UI run `34307187745` unit/container/typing/architecture pass.
Each fails lint, exceptions, policy and aggregate quality-gate.
Local handoff: orchestrator 2332 passed/4 skipped; ingestion 956 passed.
Earlier UI local run: 536 tests, 2 failures/1 error; repairs and focused tests
followed, and final CI test success supersedes that result without erasing it.

Actual develop audit: **no effective required status checks in any of the four
repos**, classic protection disabled/check contexts empty. Parent/UI have
one-review PR rules plus deletion/non-fast-forward protection; ingestion only
deletion protection; orchestrator has no effective branch rules. No settings
were enabled. Required quality gates, independent maintainer/exact proposal
approval, protected-base bootstrap, effective required checks, live ACL,
cross-component/recovery acceptance and final review/merge remain blocked.

`fleet-ui-retry`, `fleet-ingestion-final` and `stage-two-remaining` are
**done for functional implementation ONLY**, not quality/adoption/acceptance.
All 191 original IDs/categories/review hashes and 46 task IDs are preserved.
Session JSON contains final ledger hashes and evidence. ADR-0006 records the
selected retrieval/profile/history decisions and their acceptance limits.
No exception approval, protection change, merge, deployment or release occurred.

### Prior reconciliation snapshot — UI retry pending (superseded)

Pinned receipts: orchestrator `ea61bc7` (`25f1986..ea61bc7`), ingestion
runtime `eb42bbb` / README `876c427`, UI **snapshot, not final** `e993c89`,
canonical docs `9fbb827`. **191 = 143 keep recommendations + 47 functional
dispositions closed + 1 partial (`ui-boundary-23`).** Of the previous 20 open,
19 close: required retrieval policy fails closed while intentional service-only
remains; automatic profiles are suspended without deleting data; classic history
is explicitly best effort; configuration, feedback and two UI decisions have
bounded outcomes. These are agent-selected under explicit user delegation,
not separate human selections or independent approvals.

Current ledgers: **189 proposals (92/67/30), zero active**. Nine original
orchestrator handlers retired, not missing evidence; all 191 originals,
categories, immutable review hashes and 46 task IDs remain. UI stops a failed
upload's question, but a newly allocated conversation ID survives the first
failure and can drop attachments on retry. Keep that finding partial until
the coordinator pins the fix, verifies complete retry payloads and obtains review.

Focused validation: **351 orchestrator + 43 ingestion passed**. Full reconciliation and command
receipts: session `files/exception-review-reconciled.json` (`current_delivery`)
and `files/issue-681-stage-1.md`. Live acceptance/integration/recovery, policy
bootstrapping, independent exact approvals and protected adoption remain missing.
Coordinator must refresh UI head/hashes/tests/review/totals and finalize ADR.
No parent commit/push, deployment or release. Earlier sections are history,
superseded by this receipt where they describe the prior 20-open snapshot.

## Current delivery - bounded profile and request-context corrections (2026-09-09)

**This bounded batch is delivered; #681 is not complete.** Orchestrator
Azure/gpt-rag-orchestrator#346 contains runtime
`80d8fb212088dfea2249d53593b9e1dca2f37967` and test-only follow-up
`25f1986bfcf3a2b5f6057942a17fe7763e41c934`, targeting develop.
Documentation Azure/GPT-RAG#688 contains
`ec0e911ed527916117aa6e0b156fa40687ed4c42`, targeting docs.
Both remain draft and unmerged.

The single-agent bound Search tool now propagates failed request-context
application instead of searching with stale/unapplied context. Four regression
cases failed before the rethrow correction. Actual agent-tool/turn/HTTP cases
cover failure after partial output and cancellation; existing successful
conversation scoping and disabled retrieval remain unchanged. Token selection,
anonymous mode, OBO/service fallback and broader request isolation are not
changed or newly approved.

The three profile-capable strategies reject absent, non-string, blank and
shared `default_user` keys (including padded placeholders), skip optional
profile processing and continue ordinary chat without cached profile context
or welcome. Existing other keys remain verbatim. Hosted memory stays disabled;
multimodal does not become hosted-eligible. Two unconditional save timing logs
were removed; actual callers preserve confirmed/None/failed write distinctions.

This guard does **not** authenticate legacy keys. Maintained classic
orchestration supplies `principal_id`, not `conversation.user_id`; no identity
substitution, migration or extraction reactivation was made. Real-adapter
evidence confirms the existing options/result mismatch remains. All seven P4
findings therefore remain partial/open, not silently deferred or approved.

One combined scoped review found no significant issues. Final bounded evidence:
**365 caller/strategy tests**, **102 ledger/schema/evidence tests** (216
deselected), all **101 exact proposed handler bindings**, and strict docs build.
Protected-base typing/architecture pass; lint77, exceptions202 and policy1
still block adoption. No checker or policy was weakened.

Full CI at `80d8fb2` found four inconsistent optional-context test fixtures
(2127 passed, 4 failed, 4 skipped). Those fixtures disabled memory but expected
cached memory hooks to execute. Test-only `25f1986` explicitly enables memory
and supplies a key in the loaded conversation fixture. Its targeted suite
passed **220**, with **4 skipped**. Final-head CI run `34296565494` now passed
**2131**, with **4 skipped**; frontend, typing and architecture also passed.
Lint, exceptions, policy and the aggregate quality gate remain red. These are
fresh results for `25f1986`, not inherited from the earlier P5 receipt.

**191 = 143 keep recommendations + 28 resolved + 20 open.** Only the original
`legacy-single-search-context-continuation` finding closes in this batch.
Remaining: P3 six, P4 seven partial, classic persistence/H5 one, P9 five and
UI upload-continuation/H6 one. There remain **198 proposals (101/67/30), zero
active**. Ten orchestrator ledger entries changed: seven original P4 records,
two existing original cleanup records and one P3. No new records. Overall
46 original records differ from their snapshots, 145 remain unchanged. Original
IDs/categories/package assignments and all 46 task IDs are preserved.

H1-H7, trusted profile identity and collection repair/disposition, exact
exception/policy approvals, protected adoption, live integration/recovery and
final review/merge remain. Runtime rollback is to `a4010ad`, coordinated with
docs; it restores the old unsafe fallback and is not a data repair. No schema
migration, new peer dependency, merge, deployment or release.

## Integration checkpoint - persistence follow-up CI (2026-09-09)

**Functional CI passed at the pinned component heads; quality adoption remains
blocked.** This checkpoint supersedes the earlier "CI started" receipt below,
not its source-level behavior or pending decisions.

Orchestrator runtime commit `6f89c39` initially had 2 failed legacy history
timing assertions, 2054 passes and 4 skips in run `34292636509`. Test-only
commit `a4010adf943ba3648dc73e1433e344676baba7e1` observes and drains each
test's detached writes before asserting awaited create calls. It changes no
runtime durability behavior or exception record. The targeted history/P5
suite passed 67 cases; full run `34293505842` passed **2056**, with **4 skipped**.
Frontend build, typing and architecture also passed.

Ingestion `ce5c2c8`, run `34292631115`: **951 unit tests** and frontend,
typing and architecture passed. UI `8872cfc`, run `34292602772`: **534 unit
tests** and **468 container tests** passed, as did typing and architecture.
In all three repositories, lint, exceptions, policy and the aggregate quality
gate still fail. No approval, protection, deployment or merge is implied.

These results cover only those committed sources. Subsequent bounded P3/P4
work is separate and cannot inherit this full-suite receipt.

## Current delivery - persistence, UI and ingestion follow-up (2026-09-08)

**This batch is delivered; #681 is not complete.** This section supersedes
current-status prose below while preserving the 46 historical task IDs.

| Surface | Draft PR / target | Immutable source |
| --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#346 / develop | `6f89c399f046a79f2f15e4d709c47864f33f7f8f` |
| Ingestion | Azure/gpt-rag-ingestion#296 / develop | `ce5c2c86dd902b23487bdb98fa26d3f94691fef2` |
| UI | Azure/gpt-rag-ui#110 / develop | `8872cfc92c70180e2e07a6cc2842942c020c767b` |
| Shared docs | Azure/GPT-RAG#688 / docs | `1f8555aa986577d42233a119ce257a7d6bcfc0a9` |

P5 captures independent write snapshots before scheduling, retains task
ownership, orders updates after confirmed creation, and never logs a `None`
write as completed persistence. Managed ambiguous writes require the actual
submitted assistant item ID plus adjacent matching roles/text, not old repeated
text. Malformed reconciliation remains unconfirmed; no write retry.
Classic SSE remains best effort: no global pending-task bound, shutdown drain,
cross-request serialization or durable queue. H5 remains pending.

UI false/raised ingestion outcomes display a reference-bearing failure notice
without false file-received/processed-success bookkeeping. H6 question
continuation is unchanged. OpenAPI failures are uncached so later generation
can recover; H3 response policy is unchanged. Actual failed owner-index upsert
evidence confirms absent listing and opaque 404 read/feedback/delete before
managed content access. H4 continuation/repair policy is unchanged.

Ingestion uses the same wildcard label selectors and precedence for endpoint
and connection-string configuration loads. Credential/source order and
environment opt-in remain unchanged (H1). Legacy feedback overview failures
are characterized, not redesigned: zero or partial counts still lack an
unavailability signal (H2). No response schema or authorization changes.

### Review and evidence

One combined three-repository review found a P5 cleanup defect: a failing
diagnostic sink could replace the primary stream error/cancellation and skip
audit-context cleanup. Eight regression cases failed before correction.
Ordinary diagnostic failure now preserves the primary outcome; independent
`finally` cleanup resets audit context even when a new process-control exception
propagates. The new diagnostic boundary is proposed, not self-approved.

Fresh final-source evidence: orchestrator **138** P5/caller/audit lifecycle
passes and **96** selected exact-ledger/schema passes (222 deselected);
all **101** handler bindings match proposed records. UI **45** focused
hook/router/upload cases plus **one** isolated installed-startup recovery case.
That installed wheel predates the later H4 diagnostic-only edit; H4 has
source-level route evidence. Ingestion **38** complete scoped tests passed with
declared AppConfig 1.8.1/provider 2.5.0 in an isolated overlay after ambient
provider 2.1.0 failures were reproduced. No ambient environment modification.
Earlier P5 199/102 and ingestion 218 receipts remain historical, not final-byte
full-suite results. Strict documentation build passed.

Protected-base checks still block adoption: orchestrator lint 78, exceptions
202, policy 1; ingestion 59 BLE001, 67 pending proposals, 67 unapproved handlers,
9 protected-policy changes and 1 bootstrap; UI four existing BLE001,
30 unapproved handlers and a bootstrap-review blocker. Typing and architecture
pass in all three local reports. No check was disabled or policy weakened.
All four remote PR heads match the table and remain OPEN/draft. Full CI for
these new heads has started; these local receipts do not assert it is green.

### Accounting and remaining work

**191 = 143 keep recommendations + 27 resolved + 21 open.**
Two managed P5 findings are functionally closed, not approved. Classic
`legacy-detached-conversation-persistence` is now partial/open pending H5.
UI/ingestion behavioral records remain open despite their bounded corrections.
Current ledgers contain **198 proposals (101/67/30), zero active**: two new
subordinate P5 cleanup proposals join the five earlier P1/P6 companions.
37 original records differ from the original source snapshots, 154 are
unchanged; all original IDs/categories/package assignments are preserved.
The existing `stream-failed-audit-before-propagation` keep was rebound because
its enclosing try changed, without approval or reclassification.

Remaining: P3 identity/context (7), P4 profile (7), P5/H5 (1), P9 decisions (5),
and P2/H6 (1). H1-H7 are not approved. Bounded P4 follow-up has started
separately; no P4 source or closure is part of this immutable receipt.
Exact maintainer approvals, protected-policy adoption, authorized administrator
settings, live integration/recovery and final review/merge still remain.
No criterion was silently removed.

Documentation is source-pinned in the orchestrator, ingestion and
troubleshooting pages and explicitly marked unmerged. Components can roll back
independently to `463999c`, `34a6043` and `b8318dc`; no new peer dependency or data
migration. Code rollback cannot undo writes or establish durable recovery.
No merge, release, deployment, settings change or exception activation.

## Current delivery - consolidated P7/P8 (2026-09-08)

**Seven original findings resolved; the issue is not complete.** This section
supersedes current-status prose below without changing the 46 historical tasks.
One combined review covered both component diffs. It found no new source defect;
the UI ledger's stale unbinding/capacity claims were corrected before committing.

| Surface | Draft PR / target | Immutable source |
| --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#346 / develop | `463999c1ba314d55a50ab2aa646544b9eb7adac4` |
| UI | Azure/gpt-rag-ui#110 / develop | `b8318dccdc3ac67c8e30abc85e5dbe2968af554a` |
| Shared docs | Azure/GPT-RAG#688 / docs | `144360ec3c52656694752d032fb4f3607fcc07c9` |

P7 resolves `audit-export-primary-isolation`, `audit-failure-event-export`,
and `audit-final-warning-sink`. Ordinary audit errors remain best effort.
Process-control exceptions normally propagate; only a tool boundary immediately
re-raising its own primary failure/timeout/cancellation explicitly preserves it.
The preservation flag is per call, not inferred from ambient exception state.
`audit-tool-failure-propagation` was rebound to its changed caller, not newly
approved. No schema or configuration changes.

P8 resolves `ui-boundary-14/15/16/17` using the allowed invalidated-association
alternative, not by claiming physical shutdown. Installed Engine.IO invokes the
callback before closing completes. Bound sockets are invalidated before that
callback; messages and racing admissions are denied. Failed cleanup retains
inactive, capacity-counted Socket.IO bindings until successful reconciliation.
Independent namespace cleanup can continue; Engine.IO reservation release is
distinct from Socket.IO unbinding. No automatic reclamation, browser/TCP close
or stronger framework cancellation guarantee is asserted.

Evidence: P7 targeted audit/Foundry callers **240 passed**; P8 security **83**,
embed auth **16**, main policy **9 passed**. Independent combined review reran
six P7 and nine P8/P1 cases and a 100-cycle real-Engine.IO normal-close probe
at capacity one without retained registry state. These are focused local
receipts, not full-suite or new-head CI/adoption evidence. All exceptions remain
proposed; protected policy checks are still blockers. Source diff checks and
remote component heads match. UI push encountered a transient GitHub 500;
ordinary retry succeeded without rewriting history.

**Inventory: 191 = 143 keep recommendations + 25 resolved + 23 open.**
Current proposals remain **196 (99/67/30), zero active/approved**. P3 (7), P4 (7),
P5 (3), P9 (5) and P2/H6 (1) remain; none was silently deferred.
Documentation is consolidated in the audit contract, governance overview and
troubleshooting pages, marked unmerged. Components can roll back independently
to `03e908d` / `f2ac90c`; no new peer dependency or data migration. A source
rollback is not transport-state reconciliation or durable-data recovery.

Execution now batches coherent changes/review/documentation/PR updates, runs
focused tests during iteration and reserves full suites for integration
checkpoints, parallelizes independent repositories, and reports milestones
rather than repeated intermediate progress.

Scope assessment read the actual #681 and protected pre-681 orchestrator base
`c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18`. Profile adapter mismatch and
`user_id/default_user` selection, detached conversation writes, unchecked
write-result success logging, and text-only managed-write confirmation already
existed there. Minimal truthful-result and safe-identity corrections remain
required; full memory reactivation/key migration, durable queues and distributed
idempotency are separable follow-up candidates. **No package, acceptance
criterion, exception, H1-H7 behavior or protection setting was approved or
removed by this assessment.** Live acceptance, adoption and merges still remain.

## Current delivery — reviewed P6 persistence only (2026-09-08)

P6 closes **`nl2sql-schema-unavailable-compatibility`** and
**`nl2sql-sql-result-translation`** functionally, not by exception approval.
This section supersedes current-status claims below; the entire prior P2/P1
receipt and all original 46 task IDs/markers remain historical and unchanged.
No expanded review round or other work package is included.

| Surface | Existing draft PR / target | Immutable P6 source |
| --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#346 / develop | `03e908d23d770c16c8ea8a94a5c268c561afa2b2` |
| Shared docs | Azure/GPT-RAG#688 / docs | `c41777505e5ff2678fc41c04b5f89dc8374cb9c3` |

### Delivered scope

- Optional serialized `SchemaInfo.error` distinguishes unavailable schemas
  (constant missing-table reason or provider/validation exception class) from
  valid empty columns. The maintained collector sends unavailable and usable
  schemas separately to SQL generation; no new terminal failure policy.
- SQL execution attempts cursor then connection cleanup for resources returned
  to the caller. Ordinary close failures do not prevent the other close or
  replace primary typed results or propagating cancellation. Explicit typed
  validation/execution-result answers remain ordinary completed answers.
  **Not worker-thread cancellation redesign or a guarantee for resources never
  returned by acquisition.**
- Orchestrator changes are only `.quality/exceptions.json`, `AGENTS.md`,
  `src/plugins/nl2sql/{nl2sql_types.py,plugin.py}`,
  `src/strategies/nl2sql_strategy.py`, and
  `tests/{test_nl2sql_plugin_boundaries.py,test_primary_strategy_failure_boundaries.py,test_quality_policy.py}`.
  AGENTS replaces the stale no-error-field limitation precisely.
- Shared docs change only `docs/quickstart_nl2sql.md` and
  `docs/services_orchestrator.md`, with unmerged notes pinned to the new
  orchestrator SHA. No shipped behavior, manifest, deployment or peer package
  changes; rollback is the preceding orchestrator artifact, without data migration.

### Evidence and limitations

- Scoped review handoff: **no findings**. Existing
  `.artifacts/p6-sql-pytest.xml` confirms **187 passed**, zero failures/errors/
  skips, 6.768s, across NL2SQL plugin/validation/strategy, SQL connections,
  primary strategy boundaries, audit lifecycle and orchestration turn tests.
  The reviewed handoff also reports **454 quality-related passes before the
  last case**; that is historical evidence, not a fresh full-suite receipt.
- Fresh `.venv/Scripts/python.exe -m pytest -q tests/test_quality_policy.py -k nl2sql`:
  **8 passed, 308 deselected, 9.63s**. Exact source bindings pass for all eight
  NL2SQL proposals. The two rebound fingerprints and new cleanup fingerprint
  match `.artifacts/p6-sql-quality.json` exactly.
- That report uses **candidate base/head `c9a74f9e8bc500c183f54e2f7540146770503452`**,
  not the protected adoption base. Typing/architecture pass; lint/exceptions/
  policy report violations. **Not adoption evidence, approval, or new-head CI.**
- `python -m mkdocs build --strict`: **passed, 13.56s**. Existing non-nav
  visual-guide message is informational. Working-tree and staged diff checks
  pass. No unnecessary full tests or dependency installations.
- Original reconciliation: **191 = 143 keep recommendations + 18 functionally
  closed + 30 open** (including partials). Current ledgers: **196 =
  orchestrator 99 + ingestion 67 + UI 30**; all proposed, zero active/approved.
  New subordinate companion: `nl2sql-sql-cleanup-preserves-primary-outcome`.
  Original review hashes and historical delivery evidence remain unchanged.
- H6 and identity/durability decisions remain unresolved; no other package,
  merge, publication, settings, approval or live Azure validation. Append-only
  immutable handoff comments go to #346/#688/#689 via `gh api`; the unavailable
  PR-body update tool leaves body refresh to the parent/owner.

## Current delivery — reviewed P2 persistence only (2026-09-08)

P2's five reviewed IDs are persisted without new runtime scope. **Four original
findings close functionally, not by exception approval; `ui-boundary-23` remains
partial/open pending H6.** This section supersedes current-status claims below;
all original 46 task IDs/markers, prior hashes and historical receipts remain.

| Surface | Existing draft PR / target | P2 source |
| --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#346 / develop | `c9a74f9e8bc500c183f54e2f7540146770503452` |
| Ingestion | Azure/gpt-rag-ingestion#296 / develop | `34a6043ea3b6c563e528aad69c0ae70e3be32ff4` |
| UI | Azure/gpt-rag-ui#110 / develop | `f2ac90cc7c236cc3e677f147bcc107367f2fd821` |
| Docs | Azure/GPT-RAG#688 / docs | `9b0e98e78b89987022885897b825545124f0d1c0` |

### Delivered behavior and files

- **`agent-provider-pre-output-option-retry`: functionally closed.**
  Retry requires supplied `max_tokens` and a field-scoped invalid-payload
  rejection of that option or `max_output_tokens`. Ambiguous/other-option
  failures, absent token options, cancellation and any prior chunk (including
  metadata) do not replay. At most one retry removes only `max_tokens`; original
  input/thread/remaining options, including `store=False`, remain unchanged.
  Files: `.quality/exceptions.json`, `src/strategies/agent_provider_v2.py`,
  `tests/test_legacy_runtime_boundary_dispositions.py`,
  `tests/test_single_agent_rag_v2_thread_conversation.py`.
- **`unblock-log-read-failure`: functionally closed.** Only typed
  `ResourceNotFoundError` maps to 404; other read/download failures and invalid
  JSON/non-object logs produce sanitized 500 errors without upload or cache
  invalidation. Files: `.quality/exceptions.json`, `api/admin.py`,
  `tests/test_operator_failure_boundaries.py`.
- **`ui-boundary-01`: functionally closed by scope/evidence correction only.**
  Existing secure-download catch covers synchronous downloader acquisition,
  not conversation resolution or lazy stream iteration. No new runtime handler
  or transport-termination guarantee.
- **`ui-boundary-20`: functionally closed.** Standalone download errors use
  generic text and static diagnostics; typed not-found alone maps to 404,
  including no message-based `BlobNotFound` classification.
- **`ui-boundary-23`: partial/open.** Upload bookkeeping adds names only after
  confirmed batch ingestion; false/raised outcomes preserve earlier names.
  The boolean contract cannot confirm partial per-file success. **Existing
  nonempty-question continuation after failed attachments is unchanged;
  H6 remains a user decision.** UI files: `.quality/exceptions.json`,
  `src/gpt_rag_ui/bootstrap.py`, `src/gpt_rag_ui/services/chat.py`,
  `tests/test_boundary_failures.py`, `tests/test_download_security.py`,
  `tests/test_installed_package.py`.
- Shared docs update existing `docs/services_orchestrator.md`,
  `docs/services_ingestion.md` and `docs/troubleshooting.md` with concise
  unmerged semantics and immutable component links. No duplicate product docs.

### Evidence and limits

Existing reviewed receipts remain: ingestion **35 passed**, regression-first
**9 failed**; orchestrator **62 passed**, plus strengthened **19 passed**;
UI **24 passed**. The earlier combined installed-test command exited nonzero
and is not a clean receipt despite its passing standalone case.

Fresh focused working-tree checks before committing (Python 3.12.9):

- Orchestrator `.venv/Scripts/python.exe -m pytest -q
  tests/test_legacy_runtime_boundary_dispositions.py
  tests/test_single_agent_rag_v2_thread_conversation.py`: **62 passed**, 5.05s.
  Ambient Python first failed collection (two SDK import errors); the existing
  isolated environment resolves this. No dependency/source workaround.
- Ingestion `python -m pytest -q tests/test_operator_failure_boundaries.py`:
  **35 passed**, 1.58s.
- UI `python -m unittest discover -s tests -p test_boundary_failures.py -v`
  and the same command with `test_download_security.py`: **10 + 14 passed**.
- Independently, `python -m unittest discover -s tests -p
  test_installed_package.py -k
  test_installed_startup_preserves_documented_failure_boundaries -v`:
  **1 passed, exit 0**, 347.663s, fresh non-editable wheel installation.
  An initial dotted `tests.test_installed_package` invocation failed import;
  repository discovery is the valid command. It is not the earlier combined
  red receipt.
- Final docs `python -m mkdocs build --strict`: **passed**, 23.98s. Existing
  non-nav `orchestrator_visual_guide.md` is informational, not a build failure.
- Scoped `git diff --check` / staged checks passed. Exact ledger comparison
  confirms only these five proposed records changed; no IDs added or removed.

Original accounting is now **191 = 143 keep recommendations + 16 functional
closures + 32 open**: 17 fixes, 3 partial fixes, 5 decisions, 7 evidence gaps.
Four P1 cleanup companions remain separate: **195 current ledger records =
98 orchestrator / 67 ingestion / 30 UI; zero approvals**.

These are local receipts, not new immutable-head CI, live provider acceptance,
Azure durability or transport-termination evidence. Quality adoption remains
red; prior full-suite/environment limitations are not erased. P3–P9 remain
unimplemented here, and P2 H6 is not resolved. No manifest, wire-schema,
authorization-policy, settings, merge, release, deployment or publication change.
Components are independent bounded corrections, with coordinated docs/tracking;
no new peer-version requirement or manifest pin is introduced. Review components
through their existing PRs before any separately authorized integration; retain
docs as unmerged until shipping. Revert each P2 component commit independently
and its corresponding doc notice for code rollback; this cannot undo durable
writes/deletions or make unconfirmed uploads confirmed.

## Current delivery — P1 cleanup/cancellation only (2026-09-08)

P1's seven original findings are **functionally closed, not approved**.
Orchestrator `133eb7097d42a0c1ddf9f9397029abeeebd3a5d7` observes completed
profile tasks, preserves caller cancellation and skips cleanup without memory.
Ingestion `926a08d6b1ad75254fed4447a3e72e17c0bf8703` preserves primary
query/run errors across cleanup/summary failures and propagates NL2SQL child
cancellation through run/audit handling. UI
`48d87b2fb2fb9a158d02f204cfbcc3941fb6126e` separates feedback submission from
form cleanup and preserves disconnect failure across a secondary close failure.
Docs `1f2d815768f084de674cf3c66e71c761c903fdae` pins these unmerged candidates;
final `python -m mkdocs build --strict` passed (5.28s). Existing PRs remain draft.

Local evidence: orchestrator **1,943 passed / 4 expected skips**, plus the
five-case INFO-capture regression passed after exact-warning assertions;
ingestion **935 passed / 1 known pre-existing App Configuration failure**
(unmodified git-archive baseline **925 passed / same one failure**, installed
provider 2.1.0 versus declared ==2.5.0); UI **525 passed**. All current ledger
bindings match passing named tests: **98/67/30**, with 433 unique orchestrator
selectors. Quality adoption remains red. These are local precommit working-tree
receipts, not replacement immutable-head CI evidence. See
[P1 handoff](../../.artifacts/p1-delivery.md) for exact receipts and limitations.

Original inventory remains **191 = 143 keep recommendations + 12 functional
closures + 36 open** (22 fixes, 2 partial fixes, 5 decisions, 7 evidence gaps).
The 12 closures comprise the previous five plus P1's seven. Four new proposed
cleanup companions (two ingestion, two UI) are tracked separately:
**195 current ledger records = 98/67/30; zero approvals**.

**Explicitly remaining, not implemented here:** P2 truthful outcomes/public
errors/retry (5); P3 request context/OBO (7, including 2 partial); P4 profile
identity/adapter/persistence (7); P5 conversation durability/reconciliation
(3); P6 SQL schema/resources (2, left for parent); P7 audit BaseException
evidence (3); P8 actual transport termination evidence (4); P9 behavioral
decisions (5). Keep recommendations also require separate exact-policy review.
No manifest, deployment, identity-policy, release, settings, exception approval
or merge change. Code rollback cannot undo durable writes/deletions.

All 46 task IDs and their prior completion markers below remain historical.
The prior delivery/CI sections are retained, superseded for current P1 status
by this section, not rewritten as evidence for the new heads.

## Post-delivery exception review and approved follow-up

The 46-task delivery below is historical implementation accounting, **not
merge readiness**. The subsequent individual review of all 191 proposals found
143 keep recommendations (not approvals), 32 correction recommendations
(including inaccurate proposal scopes), nine behavioral decisions and seven
evidence gaps. Technical follow-up remains; this supersedes any earlier claim
that only administrative adoption is outstanding.

On 2026-09-08 the user approved interrupting a turn when its required retrieval
fails instead of returning an ordinary ungrounded answer. Orchestrator
`2f0f860c652916edd020e08f969e211f52a221f6` implements this for configured
provider initialization and Search/Foundry execution through the real
strategy/composite-provider/failed-turn path. Legitimate zero matches, existing
absent endpoint/index guards and lite/multimodal no-retrieval intents remain.
No new fallback flag or identity-policy approval is introduced.

Regression-first evidence reproduced the previous success-shaped fallback.
Local full pytest reports 1,936 passed and four explicitly inapplicable
Agent Service intent-opt-out skips; the narrow selection has 212 passed and
four skips and was independently rerun during review. Typing and architecture
pass; the full quality result still fails for unapproved policy/exception
records. All 98 records remain proposed. These are local working-tree receipts,
not a claim that a new immutable-head CI run passed.

Documentation `19788e7f9a58c5a1edbed8c5e5a8832b96a0988d` pins this correction
in three existing pages; final strict MkDocs build passed in 6.95 seconds.
Scoped source/call-chain and documentation review found no significant issue.
Both follow-ups are committed and pushed to their existing draft branches.
Other review recommendations and decisions remain open. No merge, publication,
deployment, repository-rule activation or blanket exception approval occurred.

**Input**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [quality contract](contracts/quality-gates.md),
[UI contract](contracts/ui-compatibility.md), [quickstart.md](quickstart.md).

**Prerequisites**: Read the approved plan, spec, constitution 1.0.0 and the owning
repository's instructions. Use Python 3.12 and the existing component test runner.
This task-generation refresh preserves all 46 IDs, repository assignments and
previously recorded completion markers; it does not certify implementation.

**Organization**: Setup, component-local foundations, four user-story phases in
spec priority order, then cross-repository handoff. Start pending work with
`- [ ]`; keep `[X]` only where delivery evidence already exists.

**Authorization**: Maintainer approved implementation through PRs on 2026-09-06.
Do not merge PRs, publish releases/images, deploy, or change GitHub settings
directly. Administration/live environment acceptance is recorded as pending
when it cannot be completed through this authorized PR-only workflow.

**Tests**: Required by FR-002/005/007/008/011/012 and SC-001 through SC-006.
Use existing pytest in backends and unittest in UI; mutation fixtures precede
checker implementation. Record pre-existing failures separately.

**Path conventions**: `orchestrator/`, `ingestion/`, `ui/` prefix paths in their
own repositories, not new umbrella directories. `site/` means the `docs` branch
of Azure/GPT-RAG. Unprefixed paths belong to this umbrella branch.

| Design record / contract | Creation and enforcement tasks |
| --- | --- |
| RepositoryPolicy and ModuleSurface in `.quality/policy.json` (orchestrator surfaces in protected `.quality/module-surfaces.json`) | T002-T004 inventory; T006-T008 parsing; T024-T026 architecture/ownership enforcement |
| TypingScope and TypingBaselineEntry in `.quality/typing-scope.json` and `.quality/typing-baseline.json` | T006-T008 parsing; T009-T014 identity, scope and diagnostic ratchet |
| ExceptionJustification in `.quality/exceptions.json` | T006-T008 parsing; T018-T020 fixtures; T024-T029 exact-site approval and failure behavior |
| CheckRun artifacts and quality contract Q1/Q5 | T009-T017 structured outputs, protected evaluator and fail-closed aggregation |
| UI ownership, imports, resources and matrix U1-U4 | T004 inventory; T023 citation owner; T030-T038 package migration/acceptance |
| DeliveryEvidence and documentation | T039-T043 component/site PRs, exact refs, recovery and outstanding acceptance |

## Phase 1: Setup

**Purpose**: Persist authorization and reconcile source assumptions.

- [X] T001 Record maintainer approval and PR-only authorization in docs/adr/ADR-0005-python-quality-gates-and-ui-package.md and specs/001-python-module-boundaries/plan.md.
- [X] T002 [P] Reconcile orchestrator/develop against research refs and inventory source roots, typed/public surfaces and existing workflows in orchestrator/.quality/policy.json.
- [X] T003 [P] Reconcile ingestion/develop against research refs and inventory flat roots, typed/public surfaces and scheduler ownership in ingestion/.quality/policy.json.
- [X] T004 [P] Freeze UI public imports, launch paths, settings, module ownership and resources against current source in ui/.quality/policy.json and ui/tests/test_module_compatibility.py.
- [X] T005 [P] Inspect site/docs/contributing.md, site/docs/deploy.md and related auth/continuity pages; record affected examples and keep unshipped guidance gated in the documentation PR.

## Phase 2: Foundational Policy Records

**Purpose**: Establish each repository's own tested tooling/records. Foundation
completion gates that repository's stories, not independent work in peers.

- [X] T006 [P] Add exact compatible development tool pins and schema-validated policy.json, typing-scope.json, typing-baseline.json and exceptions.json records in orchestrator/requirements-quality.txt, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py; reject missing/unknown/invalid records per data-model.md.
- [x] T007 [P] Add equivalent exact pins and validated four-record parsing in ingestion/requirements-quality.txt, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py, preserving flat-module discovery.
- [X] T008 [P] Add equivalent exact pins and validated four-record parsing in ui/requirements-quality.txt, ui/.quality/ and ui/.github/scripts/check-quality.py, preserving stable identities for legacy/package moves.

**Checkpoint**: No blanket ignores, runtime dependency pollution, dynamic source
imports by checkers, or success-shaped parse-error fallbacks.

## Phase 3: US1 - Catch Quality Regressions Before Merge (P1, MVP)

**Goal**: Lint and incremental typing report actionable regressions without
silently accepting new debt or missing execution.

**Independent test**: In each repository, a clean lint/type change passes;
new findings, count-neutral debt substitutions, lost coverage, and failed/skipped
execution cannot pass. Exercise Q6 through the existing runner and test aggregate
job/artifact integrity. Real merge-eligibility acceptance additionally requires
the complete US2 policy and separately authorized administrative activation.

### Tests

- [X] T009 [P] [US1] Add Q6 lint/type ratchet, suppression, move identity and tool-error fixtures in orchestrator/tests/test_quality_policy.py; cover missing/skipped/neutral jobs, stale/wrong-SHA artifacts and candidate self-approval attempts before implementing the checker/aggregate.
- [x] T010 [P] [US1] Add equivalent Q6 lint/type, suppression, move, tool-error and job/artifact/policy-integrity fixtures in ingestion/tests/test_quality_policy.py.
- [X] T011 [P] [US1] Add equivalent unittest fixtures in ui/tests/test_quality_policy.py, including flat-to-package moves retaining coverage and aggregate/policy tampering rejection.

### Implementation

- [X] T012 [P] [US1] Implement explicit Ruff/mypy settings, protected minimum typing scope, individual-finding baseline and structured reports in orchestrator/pyproject.toml, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py.
- [x] T013 [P] [US1] Implement equivalent flat-layout lint/type enforcement in ingestion/pyproject.toml, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py.
- [X] T014 [P] [US1] Implement equivalent UI lint/type enforcement and migration-safe scope in ui/pyproject.toml, ui/.quality/ and ui/.github/scripts/check-quality.py.
- [X] T015 [P] [US1] Wire the protected-base evaluator, actual same-workflow dependencies and always-evaluated quality-gate into orchestrator/.github/workflows/pr_pipeline.yaml; pin action SHAs, preserve frontend/tests, protect policy/workflow/tool files in orchestrator/.github/CODEOWNERS using verified maintainers, and document separate latest-head review/rules activation without privileged PR execution.
- [x] T016 [P] [US1] Wire equivalent protected-base quality-gate and policy ownership in ingestion/.github/workflows/tests.yml and ingestion/.github/CODEOWNERS, preserving existing tests/frontend checks and rejecting incomplete job/artifact evidence.
- [X] T017 [P] [US1] Wire equivalent protected-base quality-gate and policy ownership in ui/.github/workflows/tests.yml and ui/.github/CODEOWNERS, retaining unittest and reporting incomplete execution as failure.

**Checkpoint**: Workflow evidence is distinct from administrator-required merge
checks. Gate activation is not claimed merely because YAML exists.

## Phase 4: US2 - Enforce Dependency and Error Rules (P1)

**Goal**: Detect full static cycles, forbidden/private imports and unjustified
broad handlers; retain explicitly contracted failure outcomes.

**Independent test**: Positive public-facade imports pass; all Q6 graph/handler
mutations fail, including delayed/type-only imports and Ruff-exempt broad
handlers. Dependency failures preserve public errors and safe diagnostics.

### Tests

- [X] T018 [P] [US2] Add Q6 full-graph, cross-root/late/type-only cycle, private-member, legitimate facade/sibling, dynamic-import and broad-handler fixtures in orchestrator/tests/test_quality_policy.py; include aliases, tuples, exception groups, logged/re-raised handlers and stale or unexecuted exception evidence.
- [x] T019 [P] [US2] Add equivalent flat-root and cross-root fixtures in ingestion/tests/test_quality_policy.py.
- [X] T020 [P] [US2] Add equivalent flat/package/adapter and registration fixtures in ui/tests/test_quality_policy.py.

### Implementation

- [X] T021 [P] [US2] Break Search/Foundry IQ OBO cycle through a focused same-repository helper in orchestrator/src/connectors/, retaining existing callable behavior and compatibility exports.
- [X] T022 [P] [US2] Break api-to-main scheduler cycles through explicit jobs-owned state in ingestion/jobs/, ingestion/api/admin.py, ingestion/api/panel.py and ingestion/main.py without duplicating locks/registries.
- [X] T023 [P] [US2] Extract citation/reference rendering from ui/app.py into ui/src/gpt_rag_ui/services/ and make ui/datalayer.py consume that owner without changing grants or source links.
- [X] T024 [P] [US2] Implement full-graph/private-surface/exception-ledger enforcement in orchestrator/.github/scripts/check-quality.py and orchestrator/.quality/, narrowing or explicitly justifying existing handlers.
- [x] T025 [P] [US2] Implement equivalent graph/exception enforcement in ingestion/.github/scripts/check-quality.py and ingestion/.quality/, preserving the narrowly best-effort audit contract.
- [X] T026 [P] [US2] Implement equivalent graph/exception enforcement in ui/.github/scripts/check-quality.py and ui/.quality/, keeping disabled/not-ready and optional notification contracts explicit.
- [X] T027 [P] [US2] Prove unchanged OBO/MCP/retrieval and orchestration failure outcomes in orchestrator/tests/test_foundry_iq_mcp.py, orchestrator/tests/test_orchestration_turn.py and existing audit tests.
- [x] T028 [P] [US2] Prove scheduler, indexing/deletion/retrieval, config and strict-auth failure outcomes in ingestion/tests/test_admin_jobs_queue.py, ingestion/tests/test_admin_run_now.py and related existing public-boundary tests.
- [X] T029 [P] [US2] Prove backend, auth/ownership, download, panel/store and configuration failure outcomes in ui/tests/test_download_security.py, ui/tests/test_panel_routes.py and related existing suites.

## Phase 5: US3 - Navigate a Modular Compatible UI (P2)

**Goal**: All runtime responsibilities belong to the package; roots are only
startup/public-import adapters; installed and deployed use remains compatible.

**Independent test**: Entire reviewed U4 matrix passes before/after, including
non-editable wheel installation outside a checkout, both import orders,
single-owner state/callback registration, staged resources and Linux container
parity. No result may rely on editable installation or source-path leakage.

### Tests

- [X] T030 [US3] Add non-editable distribution, asset-root, startup-order, canonical-state and old/new import-order acceptance tests in ui/tests/test_installed_package.py and ui/tests/test_module_compatibility.py.

### Implementation

- [X] T031 [US3] Add setuptools src discovery and explicit legacy-module distribution in ui/pyproject.toml with inert ui/src/gpt_rag_ui/__init__.py; preserve requirements.txt as initial runtime dependency source.
- [X] T032 [US3] Move configuration/cache/settings and pure helpers into ui/src/gpt_rag_ui/config/ and ui/src/gpt_rag_ui/util/, retaining one state owner and equivalent precedence/defaults.
- [X] T033 [US3] Move identity primitives and backend/storage transports into ui/src/gpt_rag_ui/auth/ and ui/src/gpt_rag_ui/clients/, keeping identity and error behavior unchanged.
- [X] T034 [US3] Move history, chat, continuity, feedback, ownership, cursor and download decisions into ui/src/gpt_rag_ui/services/ without business logic in adapters.
- [X] T035 [US3] Move framework routes/callbacks and telemetry into ui/src/gpt_rag_ui/api/ and ui/src/gpt_rag_ui/telemetry/ with ordered single registration.
- [X] T036 [US3] Implement ui/src/gpt_rag_ui/bootstrap.py and thin ui/main.py, ui/app.py and inventoried legacy adapters; preserve conditional hosted/panel initialization and staged asset roots.
- [X] T037 [US3] Wire non-editable package installation into ui/Dockerfile and contributor startup; exercise existing Linux-image startup/resource cases without changing uvicorn main:app, deployment flags or Windows/Linux lifecycle behavior, and record unavailable container execution as pending evidence.
- [X] T038 [US3] Move private test seams to canonical owners and prove the entire U4 matrix through ui/tests/ while retaining dedicated legacy compatibility assertions.

## Phase 6: US4 - Adopt and Recover Incrementally (P2)

**Goal**: Reviewed, independently usable changes in each repository, with exact
ref evidence and documentation/recovery instructions; no automatic merge.

**Independent test**: Each PR can run with unchanged shipped peers; its previous
artifact and recovery order are identified, with unavailable live evidence
clearly distinguished from successful local evidence.

### Implementation and delivery evidence

- [X] T039 [P] [US4] Update orchestrator/AGENTS.md and its PR with scope/exception commands, current SHA, peer compatibility, targeted evidence and recovery.
- [X] T040 [P] [US4] Update ingestion/AGENTS.md and its PR with flat-layout ownership, gate commands, scheduler evidence and recovery.
- [X] T041 [P] [US4] Update ui/AGENTS.md and its PR with ownership/import/resource inventory, packaging commands and rollback.
- [X] T042 [US4] Update site/docs/contributing.md and affected operator examples in a PR targeting docs; do not publish proposed controls as already active.
- [X] T043 [US4] Record all component/docs PRs, exact candidate and preceding compatible SHAs, integration/rollback order, before/after scenario evidence and task status in specs/001-python-module-boundaries/tasks.md and the umbrella PR; explicitly track blocked live integration/recovery and administrative clean/failing-PR merge-eligibility evidence without changing settings or deploying.

## Phase 7: Polish and PR Handoff

**Purpose**: Reconcile artifacts with demonstrated outcomes and preserve a
reviewable PR record. Recording blocked acceptance does not satisfy that
acceptance criterion.

- [X] T044 Review specs/001-python-module-boundaries/plan.md and contracts/ against actual implementation; document justified refinements without silently reducing acceptance.
- [X] T045 Validate links/task syntax and run the final existing full component suites, applicable frontend checks, UI package/container cases and existing asset/docs checks from specs/001-python-module-boundaries/quickstart.md in the owning tests/ and workflows; record commands, SHAs, outcomes and unavailable evidence separately.
- [X] T046 Commit only scoped files and create/update the umbrella feature PR targeting develop, including docs/adr/ADR-0005-python-quality-gates-and-ui-package.md and specs/001-python-module-boundaries/.

## Dependencies and Execution Order

T001 authorizes the coordinated direction. T002/T003/T004/T005 are independent.
Each component's foundation depends on its inventory, not another component's
new code. US1 and US2 share that component's checker/test files: execute their
edits sequentially under one repository owner to avoid conflicting policies.

T023 uses the package skeleton from T031 and precedes the rest of the UI
composition migration. This is the explicit cross-story prerequisite; do not
introduce temporary duplicated citation business logic just to follow story
number order. T030/T031 can run once the UI inventory is frozen.

US3 proceeds in dependency order after the UI foundation and its graph contract.
T039/T040/T041 accompany their owning changes, not a later documentation cleanup.
T042 depends on verified component behavior. T043/T044/T045 finalize the
coordinated handoff, with no dependency on unmerged companion runtime changes.
T046 opened the initial draft coordination PR early; its checked state means
only that PR exists. T043 owns updating the same PR with final delivery evidence.

### Dependency graph

Arrows denote implementation prerequisites, not new task IDs or permission to
merge. US1's local code/fixture milestone unblocks US2; do not wait for
administrative merge-eligibility acceptance before implementing US2.

```text
T001
  -> T002 -> T006 -> US1 orchestrator -> US2 orchestrator -> T039
  -> T003 -> T007 -> US1 ingestion    -> US2 ingestion    -> T040
  -> T004 -> T008 -> US1 UI          -> US2 UI -> US3 UI  -> T041
  -> T005 ------------------------------------------------> T042

UI preparation: T004 + T008 -> T030 -> T031 -> T023
T039 + T040 + T041 + verified component outcomes -> T042
T039 + T040 + T041 + T042 -> T043 -> T044 -> T045
T046: draft PR already opened; T043 updates its final evidence
```

The early US3 preparation tasks T030/T031 unblock US2's citation extraction;
the rest of US3 follows the established UI graph contract. This is not a cycle
between entire stories. Within each repository, keep its checker/test edits
serial: US1 fixtures precede lint/type implementation, which precedes workflow
wiring; US2 fixtures precede cycle repair/enforcement and public-boundary
regressions. US3 moves follow T032 -> T033 -> T034 -> T035 -> T036 -> T037 -> T038.

## Parallel Examples

### Implementation resumed

On 2026-09-06 the maintainer explicitly requested implementation of the remaining
issue work. The previously frozen PRs below are historical checkpoints, not a
reason to defer executable tasks. The three component owners resume their
existing branches and PRs; the UI owner also owns the remaining installed-package
acceptance changes. No second writer edits a component concurrently.

Complete repository-local code and regression evidence before the next handoff.
Inventory, policy parsing, mutation fixtures, workflow wiring and package moves
may be marked complete when their own task criteria are demonstrated; lack of
administrative activation alone must not leave those implementation tasks
incorrectly unchecked. Conversely, do not mark handler approval or live
acceptance complete merely because their limitations were documented.

The MAF primary-failure resolution is recorded in the implementation plan:
reuse the existing safe terminal-error/audit-failure path, with no new wire or
audit schema. Other failure boundaries retain their individually established
contracts. Actual review, settings activation, deployment and publication
remain outside this PR-only authorization.

#### Resumed implementation accounting

The UI owner delivered the remaining repository-local implementation at
`ee35c9ffea67902b4dc935e287beb5d4640ce6d6` in
[Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110).
Its PR maps T008/T011/T014/T017/T020/T026/T029/T032-T036/T038 to
specific source and regression cases. The independent review of the immutable
`653660e..ee35c9f` follow-up found no significant issues.

[UI CI 34050677391](https://github.com/Azure/gpt-rag-ui/actions/runs/34050677391)
passed 521 source/installed cases, including 52 quality fixtures and 11 clean
non-editable acceptance methods, with zero skips; the ephemeral offline Linux
image passed 455 cases. CI evaluated merge `d76bfc1b3ae878d63dd737b97e3f23301024cbcf`,
whose tree equals the final head tree. Lint, typing and architecture passed.
The 28 exact retained-boundary proposals are still **unapproved**, and absent
protected-policy adoption still fails the aggregate. Checking implementation
tasks does not approve those records, activate merge protection, prove full
legacy typing cleanliness, or replace live peer/recovery acceptance.

The orchestrator owner delivered T002/T006/T009/T012/T015/T018 at
`5883d0a4abdd98146b53d2c4858ccf971d707655` in
[Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346).
This includes the protected 78-record ModuleSurface companion at `61b26e4`,
isolated tooling at `703e67f`, and the separate MAF correction at
`f06d0cd7204c63e61ce1b6c80ae768c5f7f0597c`. Independent review of the isolated
tooling slice found no significant new issues. The owner reports 1,071 passing
cases and a passing frontend build at this checkpoint. Remaining legacy
handler dispositions are substantive implementation work: T024 and final
cross-component T045 remain unchecked.

The ingestion owner delivered T007/T010/T013/T016/T019 and the named public
failure evidence in T028 in
[Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296).
The protected evaluator, flat-layout ratchets, adversarial fixtures and
same-workflow evidence checks are implemented, not activated merge settings.
The remaining T025 legacy-handler work is separate from those foundations.

The parent handed seven ingestion chunking/runtime-test files back to the
ingestion owner. After correcting test fixtures, 29 genuine
failure cases reproduced cancellation suppression, hidden failures, unsafe
diagnostics, false upload confirmation and resource leaks. The corrected
46-case chunk/parser selection plus existing ingestion/metadata/Search/audit
cases passed 147 cases. The owner integrated that work at
`26358cb8f57c982e3c80171bf8dc6b154491388d`; actual CI run `34060288839`
passed 666 cases with 96 warnings. This is offline component evidence, not
live source-to-Search acceptance. The subsequent operator/startup checkpoint
`902224592414cf4000cb5e96caaf6999a4604953` reports 703 local cases and
35 inactive proposals, with 95 unproposed sites still requiring disposition.
Its local count must not be attributed to the earlier CI run.

The later orchestrator profile-helper checkpoint
`b5b04ea5bebf96ff3afda4d12cd3fc0805705a06` passed 1,290 cases with 8
warnings in Linux CI `34067719459`; frontend, typing, architecture and assets
passed. It retains 93 unproposed sites and 29 inactive proposals. It does not
include the subsequent primary NL2SQL/Multimodal flow correction or the
parent's citation-signing handoff.

Ingestion subsequently completed T025 at
`0f7b1cea85078c7ee4260a20fe4f66255976cb12`: 916 local Python cases passed
with 150 warnings; all 65 exact inactive proposals reference passing selectors,
with zero unproposed sites and zero active approvals. The 200 remaining
findings are explicitly review/adoption categories: 60 BLE001, 65 unapproved
handlers, 65 pending exception reviews and 10 protected-policy/bootstrap
findings. No other lint, typing or architecture findings remain at this
checkpoint. These records are individually characterized proposals, not a
blanket approval or successful full quality gate.

The parent repaired the ingestion frontend peer/build blockers and returned
six files to its owner: compatible React DOM runtime/types, the React JSX type
import, Vitest configuration typing, and the matching Tailwind 4 PostCSS
adapter loading the existing theme configuration. Clean `npm ci`, the existing
frontend test, lint and TypeScript/Vite build passed with Node 22.14.0.
The local Node 20.14.0 was insufficient for the already-declared Vite 8.
No global runtime, Docker entrypoint, Python pins or dashboard behavior was
changed. The owner integrated the frontend and an existing-workflow frontend
job at final commit `f51f5154a0a63df8c7479c14d0b2ddaff93a7f13`.
Same-head CI `34125232907` passed 926 Python cases with 146 warnings in
26.81 seconds, plus clean npm installation, one frontend test, lint and the
TypeScript/Vite build on Node 22.23.2. Typing, architecture and the separate
agent-assets workflow also passed. The 65 proposals remain inactive, with
zero unproposed handlers; lint/exception/policy/aggregate failures remain
review/adoption-only. Independent review of backend `9022245..0f7b1c`
found no significant issues. No ingestion implementation remains pending;
this is not exception approval, merge protection or live deployment evidence.

Orchestrator T027 is delivered at
`2dc69285efa3d6bffb661e05e69797f54e1be45c`. Its real primary-strategy
regressions cover NL2SQL/Multimodal failure, cancellation, partial welcome
output, typed SQL-result controls, audit outcome and generic deduplicated SSE;
the preceding MAF correction remains in the same history. Same-head CI
`34123751052` passed 1,333 cases with 8 warnings in 46.81 seconds, including
the existing OBO/MCP/retrieval cases. Frontend, typing and architecture passed;
other quality gates remain red. This does not dispose of the remaining
independent handlers in T024.

The parent also returned a bounded HTTP/startup/dashboard slice to the
orchestrator owner: 44 new cases plus adjacent existing cases passed 229
tests locally. It preserves optional warmup, cancellation, auth statuses and
partial configuration writes while removing unsafe raw diagnostics and
unexpected configuration-to-default translations. The owner integrated it at
`b93fb58cdb59dbb30b1db88b39c8843296b7713b`; this local receipt is not
attributed to the earlier 2dc commit.

The final parent legacy-runtime handoff covers the provider, single-agent
strategy and orchestration runtime. Fifteen diagnostic regressions failed
before correction, while 22 compatibility controls passed. The resulting
37 new cases and adjacent hosted, thread/history, audit and primary-strategy
cases passed 146 tests with 6 warnings locally. Two redundant wrappers were
removed; eleven remaining boundaries have individual failure/cancellation
evidence integrated into the inactive proposal ledger at the final commit
below. The targeted local result remains distinct from the full CI receipt.

The one-shot invalid-payload retry remains limited to failure before any
output and preserves input, thread and non-token options. Managed turn writes
are not retried: ambiguous failure is reconciled only against the exact
two-message tail, while reconciliation failure preserves the original write
exception. Hosted execution keeps its separate no-managed-conversation path.
Optional startup, feedback resolution and detached persistence remain
distinct from primary streaming failure. Legacy search-context and strategy
token-setter failures retain their existing continuation behavior with bounded
diagnostics; this is negative compatibility evidence, not strict OBO
enforcement or new permission approval.

#### Final orchestrator implementation closure

Orchestrator T024 is delivered at
`6b652d8c4d664863a3d02d439b7b77210963320d` in
[Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346).
The final inventory contains 98 broad sites with 98 exact inactive proposals,
zero unproposed sites, zero stale fingerprints and zero active approvals.
This supersedes the incomplete orchestrator milestones above without erasing
their historical evidence. The dependency and context-provider integrations
retain the explicitly documented legacy identity fallbacks, not new permission.

[Same-head CI 34170936566](https://github.com/Azure/gpt-rag-orchestrator/actions/runs/34170936566)
completed with 1,880 passing cases, 8 warnings and 128.90 seconds on Python
3.12.14, including 315 quality cases. Frontend, typing, architecture and the
separate [agent-assets workflow](https://github.com/Azure/gpt-rag-orchestrator/actions/runs/34170936577)
passed. Parent inspected the five downloaded quality reports, all bound to
the exact final SHA: lint has 84 BLE001 findings; exceptions has 98 unapproved
handlers and 98 inactive-record findings; policy has one bootstrap-review
finding. No other finding category or analysis execution error is present.
The aggregate remains correctly blocked, not green or activated.

Parent reviewed the final `31348dc..6b652d8` source delta, new Foundry/helper
regressions and exact ledger fixtures. No significant new logic issue was
found. Foundry credential failures do not issue an HTTP request; HTTP errors
retain status without response bodies. Nullable provider construction can
still produce ordinary ungrounded answers, which is not successful retrieval.
Intent failure keeps the question fallback; optional image validation strips
images without discarding the answer. These are bounded, characterized
compatibility outcomes, not blanket authorization of recovery.

#### Final coordinated delivery

The current implementation accounting is **46/46 tasks**, within the authorized
PR-only delivery scope. The runtime and documentation implementation is delivered;
this is not full feature acceptance, green quality adoption or permission to
merge. The historical pending-work statements below describe earlier milestones.

| Surface | Final immutable candidate | PR / target |
| --- | --- | --- |
| Orchestrator | `6b652d8c4d664863a3d02d439b7b77210963320d` | [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346) / develop |
| Ingestion | `f51f5154a0a63df8c7479c14d0b2ddaff93a7f13` | [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296) / develop |
| UI | `ee35c9ffea67902b4dc935e287beb5d4640ce6d6` | [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110) / develop |
| Documentation | `de1d66d236173c33cac1936a79ed05037baf2d9b` | [#688](https://github.com/Azure/GPT-RAG/pull/688) / docs |

The documentation owner completed one final reconciliation commit after
`b81befa`: eleven edited pages, covering twelve existing pages across the full
PR. Contributor setup, current ownership, primary versus typed/optional failure
outcomes, identity limitations, partial configuration writes, ACL failures and
purge/persistence evidence are aligned with the final component sources.
Parent read the entire immutable final documentation delta and found no
significant discrepancy. No pages, navigation entries or deployment defaults
were added.

After its last edit, existing `python -m mkdocs build --site-dir
<session-artifacts>\docs-candidate-site` passed in 28.06 seconds using MkDocs
1.6.1 / Python 3.12.9. The owner inspected twelve rendered pages and 54 local
article links/anchors, with zero broken references; only the pre-existing
navigation INFO remains. The final #688 body was read back at `de1d66d` with
the same component refs, outcomes and publication restrictions.

Parent ran the existing `.github/scripts/validate-agentic-assets.py`, checked
the 46 unique stable task IDs and local feature-document links, and verified
the final scoped diff. Component-specific reproduction commands remain in
[quickstart.md](quickstart.md), and their full suites/frontend/package/image
results above come from actual immutable-head workflows, not invented combined
or live test execution.

The review/adoption gate still requires genuine decisions on the 98/65/28
inactive proposals and protected-policy bootstrap. Required-check activation,
controlled positive/negative merge-eligibility exercises, exact-peer live
integration and recovery remain separately unauthorized and unperformed.
No manifest change, merge, release/tag/image/package publication, Azure
deployment or repository-settings activation is included. The previous-artifact
recovery targets below remain valid, but cannot undo durable writes or deletions.

#### Delivered history boundary

UI commit `653660e31daa2de8219bf38a571e8bd97f227a8a` in
[Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110)
implements the previously missing history separation. `api.history` owns the
Chainlit `BaseDataLayer` adapter, fresh-instance factory, callback registration,
ambient/request context and authorized conversation selection.
`services.history.HistoryService` owns user/history operations and the single
in-memory user cache; each history operation receives `HistoryOperationContext`.
Existing Chainlit value types remain supported without a duplicate DTO model.
The root `datalayer` adapter preserves its public class and factory exports.
Conversation persistence still uses authenticated orchestrator APIs, not direct
UI database access.

Independent source review compared the committed adapter, service, legacy
exports, policy mapping and twelve new history regression methods with the prior
implementation. The completed
[workflow 34049278802](https://github.com/Azure/gpt-rag-ui/actions/runs/34049278802)
ran those methods and passed 483 unit cases, including installed-wheel
acceptance, and 422 offline Linux-image cases. Typing and architecture also
passed. Lint, exceptions, policy and the aggregate gate remain failed; this
milestone does not certify the whole quality policy or final U4 acceptance.
Further component implementation continues.

Inventory tasks T003/T004 are complete independently of those remaining gates.
The immutable ingestion policy at `3a46472b19049631fa4427699a79968134a46769`
records 52 modules, their source revision, flat roots, typed/public surfaces and
scheduler dependency ownership. The UI inventory at
`871106dbe891a1ccde373b4964c5e56a71c4f4cc` records 79 module/adapter surfaces;
the history milestone updates the explicit legacy export destinations and
compatibility assertions without discarding that inventory.

| Story | Safe independent work |
| --- | --- |
| US1 | Orchestrator T009/T012/T015, ingestion T010/T013/T016 and UI T011/T014/T017 proceed under separate owners |
| US2 | Orchestrator OBO fix T021 and ingestion scheduler fix T022; each has independent regression tests |
| US3 | Remain sequential for source moves; resource/packaging tests can be reviewed separately after inventory without concurrent edits to the same modules |
| US4 | Component guidance/evidence T039/T040/T041 proceed independently; site update follows actual outcomes |

`[P]` means independent of peer-repository tasks once its own prerequisites are
complete, not permission to edit one component's checker concurrently.

## Implementation Strategy

The MVP is US1's runnable lint/type regression feedback plus protected-policy
design; full "required before merge" acceptance also needs administrator
activation and the complete US2 policy. US2 makes architecture/error enforcement
green before claiming all quality jobs active. UI source moves follow in validated dependency
slices. Preserve deployability at each commit; publish independent component
PRs against develop rather than branches requiring an unmerged peer PR.

Keep related UI slices in one reviewable PR if separating them would require
unapproved merges to satisfy the no-unmerged-dependency rule. Record incremental
commits and recovery points. Do not create a stack that only works when several
unmerged branches are deployed together.

No task checkbox denotes release or production rollout. GitHub required-check
activation, live Azure integration and recovery rehearsal remain explicit
acceptance evidence outside this PR-only authorization if not otherwise
available. Never mark those outcomes passed based solely on local unit tests.

## Acceptance Coverage

| Story | Requirements / outcomes | Executable evidence |
| --- | --- | --- |
| US1 | FR-001-FR-004; SC-001 | T009-T017 and Q6 ratchet/execution/tampering fixtures; T043 records real rule activation and PR eligibility separately |
| US2 | FR-005-FR-008, FR-012, FR-014; SC-002/SC-003 | T018-T029 and Q3/Q4/Q6; complete graph, exact handler justification and existing public-failure outcomes |
| US3 | FR-009-FR-012, FR-015; SC-004/SC-005/SC-007 | T004, T023, T030-T038, T041; every U4 row, adapter/source inventory, installed bundle, container and ownership review |
| US4 | FR-013-FR-015; SC-006 | T039-T043; exact-ref peer compatibility, recovery result or explicit blocked prerequisite, docs impact and PR-only handoff |

## Delivery Record

Maintainer direction was approved on 2026-09-06. The docs inventory at
`dfa448127a162b86c0836d374b9f2689c61d4ea7` identifies `docs/contributing.md`
as affected. No existing operator examples use the UI root Python imports or
installed-package commands; deployment/auth/continuity pages need no edits if
their contracted operator behavior remains unchanged. The following records
are implementation checkpoints, not final component acceptance.

The umbrella feature inherits the Spec Kit/constitution installation commit
`507abf887eb42ef35b06647171ba1b6781dad4c6`, previously published on `main` but
not yet on `develop` when work began. The coordination PR includes that
prerequisite alongside the design/task artifacts; it does not republish a
release or change component pins.

| Review surface | PR / status | Checkpoint |
| --- | --- | --- |
| Umbrella coordination | [#689](https://github.com/Azure/GPT-RAG/pull/689), draft, target `develop` | Specification, decisions and delivery evidence; no runtime or manifest changes |
| Contributor site | [#688](https://github.com/Azure/GPT-RAG/pull/688), draft, target `docs`; all three checkpoint interfaces and UI ownership/setup recorded, publication gated | `10ecf1a9a1ea61a5b9e7f733785fd93294bcbbea` |
| Orchestrator | [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346), draft, target `develop` | `ef649eeab6144156b4c90c4422d62f229454dedc`, base `c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18` |
| Ingestion | [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296), draft, target `develop` | `bbe52923dbaf2b8ce4f6f371e492ad32ae7ffe45`, base `38a395586ee1d440a8e1ca8233413f8c25b3fdc2` |
| UI | [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110), draft, target `develop` | `4959ecaf04ea94ce0d35837c73b43ea3884c5be8`, base `c635bc6696714b543feec24b4a062a8a8f3ff6d0` |

At those component revisions, the owners report:

| Surface | Existing runner / selected results | Explicitly incomplete acceptance |
| --- | --- | --- |
| Orchestrator | 840 pytest cases passed, including 83 quality fixtures; 5/78 modules in blocking typing, zero baseline entries; graph 78 modules / 196 edges | 100 BLE001 findings, 154 unapproved broad handlers, empty exception ledger and bootstrap policy failure |
| Ingestion | 295 pytest cases passed; three modules in blocking typing, zero baseline entries, 354 imported diagnostics visible; graph 53 nodes / 145 edges | 131 Ruff findings, 218 unapproved broad handlers, empty exception ledger and nine bootstrap/protected-policy findings |
| UI | 436 unittest cases passed, including 17 policy, three compatibility and six installed-package cases; typing/architecture passed, 119 imported diagnostics visible | 20 BLE001 findings, 62 unapproved broad/unsupported handlers, empty exception ledger and bootstrap failure; clean dependencies, expanded installed matrix and Linux container parity pending |

The UI full suite ran at `34273fffb1da549252e82ed0337e3cdd22636042`;
`4959eca` only restores README line endings and removes two extra EOF blanks.
The [remote UI workflow](https://github.com/Azure/gpt-rag-ui/actions/runs/34040530051)
also passed unit tests, typing and architecture at `4959eca`, while lint,
exceptions, policy and the aggregate failed. The installed environments at that
checkpoint reuse system-site third-party packages; they do not prove clean
dependency resolution.

Parent source review of the backend cycle-removal diffs and their regression
fixtures supports T021/T022: Search retains its public OBO wrappers and scope
cache behavior; main and API share the jobs-owned scheduler, registry and lock.
The published contributor/PR handoffs support T039-T042 for these exact
checkpoints only. They do not close the independent checker, failure, installed
matrix or activation tasks. The follow-up record below reconciles subsequent
fix commits and documentation without treating remaining acceptance as passed.

Exact reproduction interfaces and the tested tool-version refinement are in
[quickstart.md](quickstart.md#backend-checkpoint-reproduction) and
[research.md](research.md#implementation-checkpoints). Passing local suites does
not certify all Q6 cases. A scoped exception proposal is not actual maintainer
approval. The site preview must not be published as shipped enforcement while
these conditions remain unresolved.

### Follow-up checkpoints and review dispositions

These later results supplement, rather than replace, the historical checkpoint
results above. All PRs remain drafts with their original target branches.

| Surface | Later immutable checkpoint | Evidence and remaining limits |
| --- | --- | --- |
| Orchestrator | `29df99d9b1e1393d6b775d9d5362c445a7fdd021` | Owner reports 884 pytest cases, including 117 quality fixtures; ten exact audit proposals, none active. Actual CI passed tests/frontend/typing/architecture and failed lint/exceptions/policy/aggregate. Seven actionable frozen-checkpoint checker findings require follow-up. |
| Ingestion | `46d08d31e5090045e481f22da699e09f444159dc` | Owner reports 348 pytest cases, explicit index/delete/config/job failure remedies and four audit proposals, none active. Actual CI passed tests/typing/architecture and failed lint/exceptions/policy/aggregate. Five actionable frozen-checkpoint checker findings and representative failure-contract review remain. |
| Orchestrator tooling | `550a6eedc022c879658964cbac919835c6d3b96d` | All seven accepted original checker findings are independently closed by exact immutable-source replay, including 24 aggregate and 14 malformed-diagnostic cases. Owner reports 185 quality fixtures and 952 full-suite cases; the independent reviewer did not rerun the full suite or filesystem Git fixture. No approvals activated. |
| Orchestrator failure evidence | `8d0ac0532b06b2fe83a084d5748646c3009c7283` | Actual Linux CI reports 978 tests and eight warnings; frontend, typing and architecture pass. Provider/startup, retrieval and real MAF/turn/SSE outcomes are characterized, not universally accepted. Lint 99, exceptions 164 (153 sites plus 11 proposed records) and bootstrap policy still block the aggregate. |
| Ingestion tooling | `4b19beed8dd653309f17a7b4001a0b5a117eef34` | Independent replay closes original findings 2-5, including 22 existing fixture cases and 11 malformed-record CLI variants. Finding 1 remains reproducible at this revision for implicit builtin names overwritten by unrelated local imports; its later repair is below. Owner reports 114 focused fixtures. The separate runtime compatibility follow-up is not part of this commit. |
| Ingestion runtime | `f8c3f8406fac904f2fade9c321fd8bdd924d482d` | Restores PUT post-write refresh compatibility and adds provider, run-level purge/cleanup and real Search SDK-result evidence; eight proposals, zero active. The provider merge-order fixture still needs the later CI correction below. |
| Ingestion residual repair | `0fdfc46441287f8585c62be87b3250eaddace389` | Both implicit-builtin reproductions are independently closed, with matching regression and valid controls. Actual CI run `34045353956` still reports one new unit failure and 421 passes: a fixture calls a private SDK method using the wrong positional signature for CI's declared App Configuration provider 2.5.0. This historical unit failure is corrected below, not counted as intentionally failing adoption. |
| Ingestion final checkpoint | `3a46472b19049631fa4427699a79968134a46769` | Corrected paged-load/merge fixture uses the existing provider 2.5.0 and Search 11.5.2 pins, asserts no environment fallback, and retains the last-selected value. Actual CI `34046006654` reports 422 tests and 96 warnings; typing/architecture pass. Lint 131, exceptions 210 (202 sites plus eight proposals), policy nine and aggregate remain red; zero active approvals. Earlier local provider 2.1.0/Search 11.7.0b2 results were not pinned-runtime evidence and are superseded. |
| UI | `043d89b87bd2504a9df1429df35c4ed05b4c2d60` | Clean temporary runtime environment, unchanged requirements plus `pip check`, non-editable wheel, seven installed methods and all 410 existing behavioral cases copied outside the checkout, with no skips and installed-origin assertions. The same-head Linux unit job reports 437 cases. This resolves the initial system-site dependency limitation. |
| UI | `e9620fce81daa879c0d945113911e58ae4b574e3` | Includes quality/evidence and Linux image wiring from `ab523d84dde80e4c62bdf2c6cd7cdf52f5a50ad0`, followed by parent-owned startup/upload assertions and generated-artifact Docker exclusions. Ten installed methods passed on Windows in 399.345 seconds; same-head Linux CI passed 456 unit cases and 410 image behavioral cases. Quality adoption is still red. |
| UI tooling | `ae9d0d7d41556e0d8d4c4116fbb17765fbc1210f` | Actual Linux unit job reports 460 cases; container, typing and architecture also pass. Parent subsequently reproduced three checker gaps: qualified suppression on untyped functions, indirect exception bindings/approval reuse, and undiscovered root namespace runtime packages. The following checkpoint repairs them. |
| UI final checkpoint | `871106dbe891a1ccde373b4964c5e56a71c4f4cc` | Parent independently closes all three original reproductions using frozen source. Owner reports 48 focused quality cases; actual CI `34045788683` passes 471 unit cases, 410 offline image behavioral cases and typing/architecture. Lint 20, unapproved handlers 63 and bootstrap policy one still fail adoption. Runtime, dependency pins and parent-owned acceptance files are unchanged. |
| Contributor site | `fa65c333f6c55ce51c0209cdd81922c8be85acba` | Historical clean-install documentation at UI `043d89b`, preserving earlier full-suite counts and preview warnings; superseded by the final reconciliation below. |
| Documentation final checkpoint | `b81befa396f45657990fe2bad14a6e9911100fb7` | Draft #688 updates only `docs/contributing.md`, `docs/howto_authentication.md` and `docs/ingestion_nl2sql_data_source.md`. Exact final component refs, distinct evidence CLIs, startup/image results, failure changes and remaining ownership/adoption limits are reconciled. Existing MkDocs build passes after the final edit; no nav, deployment page, runtime or publication change. |

The [UI image workflow](https://github.com/Azure/gpt-rag-ui/actions/runs/34042563761)
built the actual Dockerfile without publishing an image and ran it with
`--network none` and a read-only tests mount. Its helper verified installed
canonical origins, real `main:app` Uvicorn listeners in ready and disconnected
not-ready modes, staged VERSION/public content and all 410 existing behavioral
cases. Missing local Docker Desktop is no longer a global container-evidence
blocker. This is an ephemeral image exercise, not Azure deployment or live-peer
integration.

The ten installed methods additionally exercise standalone Entra and Copilot
startup with authentication configured before Chainlit import, real
`HTTPSession.persist_file` writes and session cleanup under the staged asset
root, and invalid Copilot configuration rejected only when activated. Missing
OAuth preserves the existing distinct responses: root HTTP 503 with Retry-After,
health HTTP 200 with `X-App-Mode: auth-required`. No application file is written
under site-packages. These results and the explicit setuptools/wheel inventory
support T030/T031/T037; they do not close all ownership or full U4 acceptance.

Frozen backend tooling reviews produced these actionable categories, assigned
back to the existing component owners with reproductions:

| Component | Required review fixes |
| --- | --- |
| Orchestrator | Permanent automatic typing coverage across successive PRs; AST `no_type_check` suppressions; lexical alias resolution; private package-initializer ownership; independently verified report identities; unique, evidenced dynamic-import sites; malformed mypy diagnostic rejection |
| Ingestion | Lexical aliases; indirect exception binding/approval identity; ownership restrictions across cross-area moves; unique dynamic-import sites; closed exact policy-record schemas |
| UI | Qualified `typing.no_type_check` on an untyped function containing typed locals; indirect catches and changed binding identity; valid root namespace packages omitted from source discovery |

Independent orchestrator replay at `550a6ee` closes its seven accepted original
findings; the imported-diagnostic suggestion remains withdrawn. Ingestion
`4b19bee` closes its indirect-catch, move, dynamic-site and schema findings;
`0fdfc46` additionally closes both implicit-builtin reproductions involving
unrelated local `ValueError as Exception` and `json.loads as __import__`
bindings. UI `871106d` closes its three parent reproductions, including a
closed-schema valid approval control that must fail after exception rebinding.
All 15 actionable findings from these bounded reviews are now closed.
This does not certify all future checker inputs or full feature acceptance.

The additional suggestion to block every imported legacy type diagnostic was
not accepted: [research](research.md#r2-incremental-typing-without-accepting-new-debt) explicitly retains imported
diagnostics in reports while classifying blocking scope, and Q6/SC-001 require
in-scope regression enforcement. Reporting uncovered diagnostics is deliberate
incremental adoption, not permission to lose automatically covered modules.

Architecture review also rejected the interpretation that only audit handlers
may ever recover. FR-008 remains conditional on the existing public failure
contract; legitimate boundary translation or cleanup still needs an exact
necessary, genuinely approved record when broad handling remains. The bounded
immutable-source assessment of representative backend outcomes is complete;
it identifies the following distinctions rather than approving broad recovery:

- AppConfig provider failures have different established startup/default and
  authentication outcomes in the two backends. A mocked high-level config
  failure is not evidence for the real provider-to-startup path.
- Context-provider degradation, strict Search connector propagation and
  explicit anonymous error-result translation are different contracts. MAF
  `8d0ac05` now tests the real strategy/turn/SSE chain: model failure emits raw
  synthetic error detail as ordinary response text and in diagnostics, followed
  by `outcome.produced`/`request.completed`. Cancellation propagates separately
  with `request.cancelled`. This characterizes an unresolved failure/redaction
  risk; it neither approves that fallback nor redesigns the streaming contract.
- Confirmed Search index/delete results and failed purge scans are real
  operational corrections, not behaviorally identical lint cleanup. Run-level
  late-failure/cleanup and pinned SDK-result evidence remain necessary.
- Ingestion `46d08d3` changed successful durable config write followed by failed
  local refresh from the existing HTTP 200/applied response to HTTP 207.
  `f8c3f84` restores that exact compatibility outcome with safe diagnostics and
  only a proposed exception record. Genuine write, apply, reload, scheduling
  and Search failure corrections remain. Provider reads now preserve
  KeyError/default handling and selector order while propagating unexpected
  errors and exhausted Azure retries; constructor fallback paths were not
  reordered or removed.

The documentation impact search at `fa65c33` found no documented promise of
successful deletion after a failed scan or unconfirmed SDK result. Nevertheless,
the authentication diagram's `200 / 202` authorization label needed to distinguish
authorization from operational success. Documentation `b81befa` now makes that
distinction, qualifies the successful refresh path and adds explicitly unshipped
notes for the final ingestion apply/PUT and NL2SQL confirmation/failure outcomes.
Existing public audit events, status fields and counters remain unchanged.
This is not a claim that only contributor documentation was affected.

Immutable UI source review at `ae9d0d7` confirms T023: history
`_messages_to_steps` calls the extracted citation service with explicit
`conversation_id`, `principal_id` and `copilot_session_id`; the citation
service does not obtain them from Chainlit session state. Existing behavioral
and image cases retain citation/download outcomes.

The same review confirms a bounded U1 gap, not merely an ambiguous folder
label. `api.history.register_data_layer` registers the service factory, while
`services.history.get_data_layer` constructs `OrchestratorDataLayer`.
That service class still mixes history operations with callback/DTO adaptation,
ambient `_get_session_metadata` resolution and `update_thread` framework-session
mutation. Complete the API-owned adapter/session seam while retaining
service-owned history behavior, single user/request-context ownership and its
consume-once semantics. Preserve `datalayer.OrchestratorDataLayer` and
`datalayer.get_data_layer`; update the ownership inventory and compatibility
tests without introducing a service-to-API forwarding cycle. No new DTO
hierarchy, singleton factory requirement or Cosmos history implementation is
implied. T034/T035 and full U1/U4 acceptance remain open.

The orchestrator owner also records an unverified tool-launch isolation
question: candidate working-directory lookup for Ruff/mypy and source
`PYTHONPATH` for Import Linter. Shadow-module/startup-hook adversarial execution
was not exercised by the seven-finding closure review. This is not a proven
additional exploit or a completed Q1/Q5 isolation claim; broader protected-tool
execution acceptance remains open.

### Integration and recovery record

The unchanged peer/recovery targets remain orchestrator v4.1.1
(`9b64a5b962067161cb55252c6e0917a2738ba984`), ingestion v2.7.3
(`38a395586ee1d440a8e1ca8233413f8c25b3fdc2`) and UI v2.6.2
(`f59cca919f0bc59631d7bba7f3e223dff3718244`). These are compatibility targets,
not a claim that the three candidate heads have been exercised together in a
live environment. No manifest pin or deployment combination has been changed.

Proposed order, conditional on remaining implementation and human approvals:

1. Review the umbrella design and each component's protected-policy bootstrap,
   exact handler dispositions and evidence. The backend branches remain
   independent; neither depends on the other's unmerged runtime code.
2. Complete UI ownership/compatibility and checker work before adopting its
   package change. Exercise each candidate with unchanged shipped peers, then
   the exact three-candidate combination, using separately authorized live
   integration and recovery procedures.
3. Publish the matching documentation only with the corresponding shipped
   behavior. Activate required checks/latest-head review and demonstrate clean
   and failing PR eligibility only through the authorized administrative
   process; existing YAML and code-owner names do not activate those controls.

For an independently introduced runtime regression, the proposed recovery is
restoration of that component's preceding artifact, starting with UI if the
last introduced change was its packaging, then reversing any subsequently
introduced backend changes. Since peer contracts are unchanged, a component
rollback must not require an unmerged companion change. Code corrections or
runtime-only revert PRs retain the quality controls; disabling them is not a
recovery mechanism. A later coordinated manifest change would require restoring
its preceding validated combination as a unit.

Artifact restoration does not restore deleted Search data or undo configuration
already persisted remotely. Those side effects need separate, explicitly
authorized recovery evidence. Neither artifact restoration, live integration,
nor recovery of external state has been performed in this PR-only task.

This closes the bounded evidence/reconciliation work in T043/T044, not their
underlying feature acceptance. There are 15 checked tasks and 31 unchecked
tasks. T045 remains open for complete acceptance beyond the maintained suites:
the unresolved ownership/failure work, broader Q6/U4 cases and protected-tool
execution cannot be certified by the passing runs recorded here.

Unchecked tasks are intentionally not represented as completed by the existence
of the coordination PR. Required rules activation, live integration and live
recovery have not been performed.
