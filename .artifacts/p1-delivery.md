# P1 immutable delivery handoff — 2026-09-08

P1 only. Seven original functional findings closed; no exception approval.
All existing feature PRs remain OPEN/draft, components targeting develop and
documentation targeting docs. No merge, publication, deployment, settings or
manifest change. P2–P9 remain open, including parent SQL work.

| Surface | PR | Pushed commit |
| --- | --- | --- |
| Orchestrator | Azure/gpt-rag-orchestrator#346 | `133eb7097d42a0c1ddf9f9397029abeeebd3a5d7` |
| Ingestion | Azure/gpt-rag-ingestion#296 | `926a08d6b1ad75254fed4447a3e72e17c0bf8703` |
| UI | Azure/gpt-rag-ui#110 | `48d87b2fb2fb9a158d02f204cfbcc3941fb6126e` |
| Docs | Azure/GPT-RAG#688 | `1f2d815768f084de674cf3c66e71c761c903fdae` |

## Delivered files and behavior

- Orchestrator: `.quality/exceptions.json`,
  `src/strategies/maf_plugins/user_profile_memory.py`,
  `src/strategies/multimodal_strategy.py`,
  `tests/test_strategy_helper_boundaries.py`,
  `tests/test_user_profile_memory_boundaries.py`.
  Observe completed extraction failure; do not clear replacement tasks;
  propagate caller cancellation and prevent save; absent memory skips cleanup.
- Ingestion: `.quality/exceptions.json`, `CHANGELOG.md`, `README.md`,
  `api/retrieval.py`, `jobs/blob_storage_indexer.py`, `jobs/nl2sql_indexer.py`,
  `tests/test_nl2sql_indexer_failures.py`, `tests/test_retrieval.py`,
  `tests/test_worker_failure_boundaries.py`.
  Preserve query/run primary errors and cancellation across secondary cleanup
  and summary failures. NL2SQL child cancellation reaches run/audit wrapper
  instead of a finished summary. No persistence or cleanup guarantee.
- UI: `.quality/exceptions.json`, `src/gpt_rag_ui/api/feedback.py`,
  `src/gpt_rag_ui/auth/embed_security.py`, `tests/test_boundary_failures.py`,
  `tests/test_embed_security.py`. Feedback notification reflects backend
  outcome despite form-removal failure; no repeated write on toast failure.
  Disconnect double failure preserves primary error with safe diagnostics.
- Docs: `docs/howto_multimodality.md`, `docs/howto_userfeedback.md`,
  `docs/services_ingestion.md`; unmerged notices pin the corresponding commits.
- Parent: task top-section and this handoff. Original 46 task IDs untouched.
  Session reconciliation files retain original review hashes and inventory.

## Local evidence, not new-head CI

These existing receipts were inspected, not relabelled as committed-head CI:

| Component | Receipt under owning `.artifacts/` | Result |
| --- | --- | --- |
| Orchestrator | `p1-final-full.xml` | 1,943 passed, 4 expected Agent Service intent-opt-out skips; 164.940s |
| Orchestrator | `p1-final-info.xml` | 5 passed; 3.778s; INFO capture after exact-warning caplog correction |
| Ingestion | `p1-validation-full.xml` | 935 passed, 1 known pre-existing failure; 245.259s |
| Ingestion baseline | `p1-validation-baseline-full.xml` | 925 passed, identical sole failure; 244.230s |
| UI | `p1-validation-retry-tests.json` | 525 passed |

The earlier failing orchestrator caplog receipts are superseded by the final
receipts above, not hidden. Full pytest uses the existing
`python -m pytest -q --junitxml=<receipt>` path; INFO regression adds
`--log-level=INFO` for `test_multimodal_flow_owns_optional_cleanup`.
UI uses `.github/scripts/run-unittest.py` and its exact-source evidence.
Original receipt head fields intentionally remain the precommit heads.

Ingestion baseline proof: `p1-validation-baseline-proof.json`, against
`git archive f51f5154a0a63df8c7479c14d0b2ddaff93a7f13`, archive SHA256
`531b7a8e0c52bd60d0d995bf47b92cfe042ada8502d7ca879b445cf0a0fe73ec`.
All 236 archived files remained unchanged after the suite; no excluded tests;
178 quality-policy tests included. Candidate and baseline share the exact
failure `tests/test_appconfig_failures.py::test_constructor_preserves_selectors_and_sdk_last_selected_value`.
Installed `azure-appconfiguration-provider` 2.1.0 differs from declared
>=2.5.0; baseline and candidate App Configuration implementation/test bytes
are identical. This is a residual local-environment failure, not a P1 pass
or a replacement for the historical successful ingestion CI.

Independent native-scanner audit `p1-verify-ledger.py orch <root>
<root>/.artifacts/p1-final-full.xml` was rerun: 98/98 one-to-one handler matches
and passing bindings, 433 unique selectors / 466 references. Ingestion's
`p1-validation-ledger.json` has 67/67 matches/bindings (118 unique selectors);
UI's has 30/30 (26 unique selectors). Quality adoption remains red as expected;
none of the proposed exception records is activated.

Finalization commands actually executed:

- `git diff --check` across all five worktrees; staged component checks passed.
- Inspected ingestion `.gitattributes` (no CR whitespace exemption for these
  files). Baseline stored all four files as CRLF. Authorized normalization
  changed only `CHANGELOG.md`, `README.md`, `jobs/blob_storage_indexer.py`,
  `jobs/nl2sql_indexer.py` to LF. Removed one pre-existing trailing space on
  README's opening HTML comment exposed by normalization. Git config and
  attributes unchanged. The large raw diff is formatting;
  `git diff --ignore-space-at-eol --stat` retained the nine-file semantic scope.
- No unnecessary full-test rerun after this formatting-only operation.
- Final `python -m mkdocs build --strict`: PASS, 5.28s. Existing unlisted
  `orchestrator_visual_guide.md` notice is INFO, not a strict-build failure.
- Scoped `git add`, `git commit` with Copilot App coauthor trailer and
  `git push` to each existing feature branch.
- `gh pr view ... --json number,url,headRefOid,isDraft,baseRefName,state`
  confirmed all four component/docs commits above at OPEN/draft PR heads.

## Reconciliation and residual risks

Original 191 IDs/categories and original review-file hashes are preserved.
143 keeps remain recommendations. Previous five functional closures plus
seven P1 closures = 12; 36 original IDs remain open. The four new proposed
companions are separate from the 191:
`retrieval-primary-cleanup-preservation`, `blob-primary-summary-preservation`,
`ui-boundary-02-cleanup`, `ui-boundary-11-cleanup`.
Current ledgers: 98 + 67 + 30 = 195, zero approvals.
Fourteen original ledger objects changed since original review (nine orch,
three ingestion, two UI), 177 unchanged, zero changed keep recommendations.
Historical and current raw-checkout/git-blob hashes are explicitly distinguished
in the session reconciliation.

Cross-repository dependency is this candidate combination, not a release pin.
Review components through owning PRs; keep docs unmerged until corresponding
behavior ships with separate authorization. Roll back scoped commits if needed;
reverting code does not reverse writes/deletions. P1 does not resolve profile
adapter/identity issues, conversation durability/reconciliation, actual socket
termination, OBO policy, SQL resources or audit BaseException evidence.
No live Azure or production validation was performed.

PR #689 body update remains blocked: the requested `update_pull_request` tool
is unavailable in this session. Do not use `gh pr edit` or an alternate body
mutation to bypass that requirement. Preserve the historical owner body;
handoff comments identify this current P1 state without relabelling past CI.
