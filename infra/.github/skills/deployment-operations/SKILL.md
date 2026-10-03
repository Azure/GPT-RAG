---
name: deployment-operations
description: Safely investigates and operates AI Landing Zone preflight, What-If, azd, Azure DevOps, and jumpbox bootstrap paths. Use for approved deployment operations or incident diagnosis.
---

# AI Landing Zone deployment operations

1. Establish the approved subscription, resource group, deployment mode,
   identity, source commit, and parameter source without exposing private data.
2. Run deterministic preflight, then Azure-aware checks as authorization allows.
3. Use What-If or `azd provision --preview`; inspect destructive changes,
   replacements, role assignments, network access, and policy effects.
4. For failures, isolate the phase: substitution, preflight, ARM validation,
   resource deployment, data-plane setup, or jumpbox bootstrap.
5. Preserve logs and exit codes. Do not retry non-transient failures or hide
   resource-level errors behind a successful wrapper exit code.
6. Before mutation, state expected effect and rollback or roll-forward.
7. Record the exact command and resulting deployment or operation state.

Production mutation requires explicit approval. A preview or diagnostic request
is not approval to deploy.
