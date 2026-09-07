# Validation Guide: Python Module Boundaries

This guide separates **existing runnable checks**, **draft checkpoint commands**
and **remaining acceptance**. Planning itself created no runtime implementation;
the [delivery record](tasks.md#delivery-record) now identifies component drafts.
Their commands are not instructions for released component tags, nor evidence
of active required checks. Execute them in the matching component checkout,
not this umbrella.

## Prerequisites

Use Python 3.12 and the owning repository's development environment. Fetch the
current `develop` branch, record HEAD and the PR base SHA, and inspect that
repository's scoped instructions. Existing runtime dependencies come from its
`requirements.txt`; orchestrator/ingestion CI also installs pytest-related
dependencies. UI uses unittest, not a new pytest runner.

Existing unit tests use mocked service boundaries and should not require live
Azure credentials. If a dependency is missing, restore it using the repository's
documented setup, then rerun the same command. Do not interpret import failure
or missing tools as a clean baseline.

## 1. Establish the current behavior baseline

These full-suite commands already exist in component CI or `AGENTS.md`:

| Component | Existing command |
| --- | --- |
| Orchestrator | `pytest -q` |
| Ingestion | `python -m pytest tests -q` |
| UI | `python -m unittest discover -s tests -v` |

For a local cycle-removal slice, use the relevant existing selectors first:

```powershell
# Orchestrator: OBO/Search/Foundry IQ cycle.
pytest -q tests\test_foundry_iq.py tests\test_foundry_iq_mcp.py tests\test_retrieval_backend.py

# Ingestion: shared scheduler/registry state.
python -m pytest -q tests\test_admin_jobs_queue.py tests\test_admin_run_now.py tests\test_panel_api.py tests\test_main_deployment_gating.py

# UI: startup compatibility; run from the UI checkout.
python -m unittest discover -s tests -p "test_main*.py" -v
```

Choose additional existing auth, datalayer, citations, continuity and panel tests
from the compatibility inventory when their owner moves. Full suites are
required for final component/integration evidence, not every documentation edit.
Keep existing frontend jobs. Ingestion's final implementation also repairs
existing frontend dependency/build blockers and adds a frontend job to its
existing Tests workflow.

Record exact commands, exit status, SHA and pre-existing failures. A prior
failure is not silently accepted as a quality-policy exception.

## 2. Exercise the quality interface after implementation

The following commands require the matching component checkpoint containing
`requirements-quality.txt`, `.quality` records and `check-quality.py`:

```powershell
python -m pip install -r requirements-quality.txt
$Base = git merge-base HEAD origin/develop
```

Use the matching component invocation below: interpreter startup flags are part
of the protected interface, not interchangeable options. Local reproduction
assumes a trusted interpreter and installed dependencies; a virtual environment
is not an operating-system sandbox. CI separates candidate behavioral tests from
static evaluation using the protected evaluator and dependency configuration.

For a release-target PR, substitute its actual protected target for `develop`.
The checker creates the report's parent directory and never edits code or policy.
Expected result: exit 0, all expected checks passed, no new in-scope debt,
uncovered scope listed, and matching base/head/policy identities. A successful
lint run alone is not the full gate.

When diagnosing a failure, invoke one supported `--check` value from
[the quality contract](contracts/quality-gates.md#q1-command-and-result-interface).
The wrapper uses the pinned tool's supported command/structured output; it must
not infer success from a parser exception. No command accepts or rewrites a
baseline automatically.

### Backend checkpoint reproduction

The orchestrator and ingestion checkpoints in the delivery record exercised
Python 3.12.9, Ruff 0.16.5, mypy 2.3.1, Import Linter 2.14 and Grimp 3.16.
See [the recorded version refinement](research.md#implementation-checkpoints);
do not substitute the unavailable research candidates.

After restoring the owning repository's runtime/test/quality dependencies,
produce evidence with its existing runner and checkpoint-specific interface:

```powershell
# Orchestrator, from 703e67f94f4f36971bdb388e0eacb920560f9b6e.
python -m pytest -q --junitxml=.artifacts\pytest.xml
python -I -S .github\scripts\check-quality.py --check all --base-ref $Base --report .artifacts\quality.json --test-results .artifacts\pytest.xml

# Ingestion, from f47c98f5ca9762a539e7279e681e4a0d75e967f7.
python -m pytest tests -q --junitxml=.artifacts\pytest.xml -o junit_family=legacy
python -I .github\scripts\quality-evidence.py --junit .artifacts\pytest.xml --base-ref $Base --report .artifacts\test-evidence.json
python -I .github\scripts\check-quality.py --check all --base-ref $Base --report .artifacts\quality.json --test-evidence .artifacts\test-evidence.json
```

Orchestrator also requires `-I -S` for `aggregate-quality.py`: it skips automatic
site/startup-hook processing and explicitly discovers installed distribution
paths. Ingestion also requires `-I` for `quality-gate.py`; installed tooling and
site initialization remain trusted, so `-I` alone is not a claim that installed
`.pth` hooks cannot execute. Neither component applies these static-evaluator
startup requirements to its existing pytest command. The report and test-evidence
argument names remain component-specific.

These drafts intentionally do **not** satisfy the exit-0 acceptance target:
orchestrator handler dispositions and protected review/adoption remain
outstanding. Ingestion's final `f51f5154a0a63df8c7479c14d0b2ddaff93a7f13`
has zero unproposed handlers and no ordinary lint findings; its 65 exact
inactive proposals still fail the unapproved-handler/review gates.
Do not approve exceptions or lower policy to reproduce a green result.
Passing existing tests or selected architecture/typing checks is not full
acceptance. Review of exact policy schemas, adversarial cases and public failure
contracts remains independent of these owner-reported checkpoint results.

### UI evidence and image checkpoint reproduction

UI `ee35c9ffea67902b4dc935e287beb5d4640ce6d6` includes the completed
repository-local package/history/isolation work and a unittest evidence runner.
It requires a shared execution identity for local evidence consumption:

```powershell
$env:QUALITY_RUN_ID = [guid]::NewGuid().ToString()
python .github\scripts\run-unittest.py --base-ref $Base --report .artifacts\unittest.json
python .github\scripts\check-quality.py --check all --base-ref $Base --test-evidence .artifacts\unittest.json --report .artifacts\quality.json
```

Keep the same `QUALITY_RUN_ID` for the runner and consuming checker. CI supplies
its run ID and attempt instead. The runner retains the existing unittest suite;
it does not create a second test framework. Missing, skipped, changed-source or
wrong-execution evidence must not authorize an exception.

The existing UI workflow also builds the actual Dockerfile and runs
`tests/container_smoke.py` explicitly in the ephemeral Linux image, offline with
a read-only tests mount. The helper is intentionally outside `test_*.py`
discovery. At this final UI checkpoint, actual ready/not-ready Uvicorn listeners,
installed origins, staged assets and 455 image cases passed.
The full unit job passed 521 source/installed cases, including clean-wheel and
actual synthetic startup/file-persistence acceptance. Quality adoption remains incomplete; successful
image/unit jobs do not imply a passing `quality-gate` or Azure integration.

Later same-head results and independently reviewed repairs are recorded in
[the follow-up table](tasks.md#follow-up-checkpoints-and-review-dispositions).
For example, UI `ae9d0d7d41556e0d8d4c4116fbb17765fbc1210f` passed 460
unit cases and the image job, but subsequent source-policy, catch-binding and
namespace-discovery reproductions still required repairs. A passing behavioral
suite is not proof that all checker mutations are rejected.
The earlier UI checkpoint `871106dbe891a1ccde373b4964c5e56a71c4f4cc` closes
those three reproductions and passes 471 unit cases plus the unchanged
410-case image exercise. The evidence CLI is unchanged and adoption remains
red. Backend final refs, SDK-aligned results and the explicitly superseded
ingestion fixture failure are likewise recorded in the follow-up table.

UI history milestone `653660e31daa2de8219bf38a571e8bd97f227a8a` subsequently
passes 483 unit cases, including twelve new history-boundary regressions, and
422 offline Linux-image cases in
[workflow 34049278802](https://github.com/Azure/gpt-rag-ui/actions/runs/34049278802).
The framework adapter/factory/context now lives in `api.history`; the service
receives explicit operation context and retains the single user-cache owner.
Legacy `datalayer` exports still resolve to their canonical implementation.
Its evidence CLI remains the one above. That history milestone is superseded
for final code evidence by `ee35c9ffea67902b4dc935e287beb5d4640ce6d6`.
Actual workflow `34050677391` passed 521 source/installed cases with zero skips
and 455 offline Linux-image cases. Eleven clean non-editable package methods
cover the installed/startup/resource boundaries. Lint, typing and architecture
passed; 28 exact inactive boundary proposals and protected-policy bootstrap
still fail adoption. U1/U4 repository-local implementation is delivered.
This does not substitute for genuine review, active required checks or live
identity, peer and recovery acceptance.

## 3. Prove rejection and required merge enforcement

Add planned checker fixtures under existing `tests/`, for example
`test_quality_policy.py`, with no new test framework. Their test cases must
cover the complete [negative-fixture matrix](contracts/quality-gates.md#q6-minimum-acceptance-fixtures).
They operate on temporary source trees and compare explicit pass/violation/error
outcomes.

After those files exist, run the corresponding focused command:

```powershell
# Orchestrator or ingestion.
python -m pytest -q tests\test_quality_policy.py

# UI.
python -m unittest discover -s tests -p "test_quality_policy.py" -v
```

Then, with maintainer authorization, use clean and deliberately failing draft
PRs in each repository to prove SC-001/002/003 against real rules. Confirm that
missing/skipped jobs, stale artifacts, baseline self-edits and unreviewed policy
changes cannot merge. These PR/settings operations are implementation acceptance
activities, not actions authorized by this planning invocation.

## 4. Prove UI installation, resources and single ownership

After package metadata/install wiring exists, build code without resolving a
second runtime dependency set:

```powershell
python -m pip wheel --no-deps --wheel-dir .artifacts\wheel .
```

Implement `tests/test_installed_package.py` using unittest and temporary
directories/subprocesses. A checkpoint implementation is not evidence that the
entire acceptance matrix has passed. The test must build/use the wheel and:

1. Create a clean Python 3.12 environment with the existing runtime requirements
   and the **non-editable** wheel. Inspect the wheel's module inventory.
2. Stage only existing deployment assets, not source Python, outside the source
   checkout. Start from another non-repository directory and use the existing
   `CHAINLIT_APP_ROOT` setting for that asset root.
3. Remove inherited source-path shortcuts. Assert canonical and legacy modules
   resolve from the installed distribution, not the checkout.
4. Exercise the unchanged Uvicorn target with mocked external-service boundaries;
   check auth-before-Chainlit, readiness, routes, VERSION footer, public resources
   and writable configuration/upload paths outside site-packages.
5. Exercise both import orders for every supported legacy/canonical adapter.
   Assert one config/continuity/client owner and one callback registration.
6. Repeat backend/panel activation variants and intentionally disabled states.
   A missing wheel file or module fails; known optional-resource behavior remains
   the pre-change behavior.

After implementation:

```powershell
python -m unittest discover -s tests -p "test_installed_package.py" -v
python -m unittest discover -s tests -v
```

Build the unchanged Docker entrypoint with its newly wired package installation
and repeat representative startup/resource cases in the Linux image. Use the
existing component container/deployment instructions; do not invent a different
supported launch command. If hook files change, validate both PowerShell and
shell variants and PowerShell 5.1 compatibility where required.

## 5. Component combinations, recovery and documentation

Each deployable code slice records its candidate SHA plus the unchanged peer
refs from [the plan](plan.md#technical-context). CI-only policy slices require
no redeployment. Runtime slices prove affected behavior against shipped peers
without depending on an unmerged companion change.

For final integration, record all three actual candidate SHAs and execute the
entire compatibility matrix. Rehearse recovery by replacing the changed
component artifact with the previous known-good artifact, restoring any later
manifest combination as a unit. Verify startup/auth and the affected operation
after recovery. No schema/data migration is expected.

Artifact rollback does not undo previously persisted configuration or deleted
Search documents. Restoration of those external side effects requires its own
authorized recovery procedure and evidence; a successful code revert cannot be
reported as data recovery. Preserve public event names and counters when
comparing outcomes, and distinguish expected failure characterization from
acceptance of that behavior.

Live Azure validation requires explicit authorization and an existing suitable
environment. Network-isolated data-plane access needs the existing permitted
VNet path; do not disable isolation to make evidence easier. Missing access is
reported as blocked evidence, not as a pass. Do not publish artifacts, tags or
manifest pins from this guide without the separate release approval.

Update contributor commands/maps in each owning repository and relevant docs
on the `docs` branch with the implementation. Evidence records generic validation
environment descriptions, exact commits and feature modes, never credentials,
customer contents or private validation environment/resource-group names.

## Acceptance traceability

| Outcome | Required evidence |
| --- | --- |
| SC-001 | Three required gates; clean PR eligible, new lint/type regressions blocked |
| SC-002 | Full graph/private-surface positive and negative fixtures in all three repositories |
| SC-003 | Handler inventory/approval integrity and all inventoried public failure scenarios |
| SC-004 | Every module/responsibility mapped; root adapters contain no business logic |
| SC-005 | Frozen before/after compatibility matrix, installed bundle and container parity |
| SC-006 | Independently usable exact-ref combination and recovery/docs record per slice |
| SC-007 | Maintainer-approved ownership map with no ambiguous/duplicated responsibilities |

Completion requires these results, not merely the existence of this guide.
