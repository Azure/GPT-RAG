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
Keep existing frontend jobs; no frontend source change is planned.

Record exact commands, exit status, SHA and pre-existing failures. A prior
failure is not silently accepted as a quality-policy exception.

## 2. Exercise the quality interface after implementation

The following commands require the matching component checkpoint containing
`requirements-quality.txt`, `.quality` records and `check-quality.py`:

```powershell
python -m pip install -r requirements-quality.txt
$Base = git merge-base HEAD origin/develop
python .github\scripts\check-quality.py --check all --base-ref $Base --report .artifacts\quality.json
```

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
# Orchestrator, at its recorded checkpoint.
python -m pytest -q --junitxml=.artifacts\pytest.xml
python .github\scripts\check-quality.py --check all --base-ref $Base --report .artifacts\quality.json --test-results .artifacts\pytest.xml

# Ingestion, at its recorded checkpoint.
python -m pytest tests -q --junitxml=.artifacts\pytest.xml -o junit_family=legacy
python .github\scripts\quality-evidence.py --junit .artifacts\pytest.xml --base-ref $Base --report .artifacts\test-evidence.json
python .github\scripts\check-quality.py --check all --base-ref $Base --report .artifacts\quality.json --test-evidence .artifacts\test-evidence.json
```

These drafts intentionally do **not** satisfy the exit-0 acceptance target:
inherited lint/broad-handler findings and bootstrap review remain outstanding.
Do not approve exceptions or lower policy to reproduce a green result.
Passing existing tests or selected architecture/typing checks is not full
acceptance. Review of exact policy schemas, adversarial cases and public failure
contracts remains independent of these owner-reported checkpoint results.

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
