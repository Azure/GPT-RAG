# AI-assisted maintenance

GPT-RAG maintainers use GitHub Copilot coding agents and repository skills to
help with scoped engineering work such as analysis, implementation,
documentation, and validation. These are engineering-time tools. They are
separate from the agents and orchestration features that a deployed GPT-RAG
runtime may expose to its users.

Humans define or approve the task and review the resulting changes. Coding
agents work in ephemeral GitHub-hosted environments and are constrained by the
repository's instructions, specialized agent definitions, and reusable skills.
The normal pull request process still applies, and continuous integration
validates changes before they are merged.

## Azure evaluation access

When an approved engineering task requires an Azure deployment, the
[Copilot setup workflow](https://github.com/Azure/GPT-RAG/blob/main/.github/workflows/copilot-setup-steps.yml)
signs in through GitHub OpenID Connect (OIDC) using a dedicated managed
identity. No Azure client secret is supplied. Azure RBAC limits that identity
to the dedicated, non-production evaluation resource group
`rg-gptrag-evaluation`.

Deployments use the fixed Azure Developer CLI environment
`gptrag-evaluation`. The identity currently has these roles at that resource
group only:

- **Contributor**, for provisioning and removing evaluation resources.
- **Role Based Access Control Administrator**, for the role assignments that
  the deployment creates within the evaluation resource group.

The identity has no subscription-wide Owner, Contributor, or Reader
assignment. It cannot use these roles to manage resources or role assignments
outside the evaluation resource group. Evaluation resources are cleaned up
after testing to limit ongoing cost and avoid retaining test deployments.

The accepted design and its operational boundaries are recorded in
[ADR-0002](https://github.com/Azure/GPT-RAG/blob/main/docs/adr/ADR-0002-copilot-azure-oidc.md).
Any proposal to widen the resource scope, change the identity model, or use a
different deployment target requires maintainer review.
