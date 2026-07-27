# AI Transparency Notes

## Overview and purpose

GPT-RAG is a solution accelerator for building retrieval-augmented assistants
on Azure. A deployed runtime combines a configured model with selected
enterprise grounding sources and application services. The organization that
deploys GPT-RAG chooses the model, data sources, access controls, deployment
topology, user experience, and operating policies.

This note summarizes intended uses, capabilities, limitations, and shared
responsibilities. It does not certify a deployment or replace the adopter's
legal, privacy, security, risk, records-management, or human-oversight review.
Actual behavior depends on the deployed configuration, connected data, model,
and enabled features.

## Intended uses

GPT-RAG is intended to help organizations create assistants that retrieve
information from approved sources and generate responses grounded in that
information. Example scenarios include enterprise knowledge discovery,
question answering, summarization, and configured text, image, or voice
experiences.

Adopters should define the intended users, approved data, permitted tasks, and
prohibited uses before deployment. GPT-RAG should not be treated as an
independent authority, a compliance decision maker, or the sole basis for
high-impact decisions about a person. Scenarios that can materially affect
people or operations need controls and human review appropriate to their risk.

## Capabilities

Depending on configuration, GPT-RAG can:

- ingest or query supported grounding sources;
- retrieve relevant content and provide source references with generated
  responses;
- orchestrate configured models, retrieval strategies, and tools;
- apply application authentication and source-specific authorization patterns;
  and
- support modular Azure deployment, optional network isolation, and
  configurable observability.

See [Architecture](architecture.md) and the
[Grounding sources overview](howto_grounding_overview.md) for the current
component and source boundaries.

## Limitations

Generated responses can be inaccurate, incomplete, outdated, ambiguous, or
unsuitable for the user's context. A source reference shows what content was
used; it does not prove that the response or source is correct. Retrieval
quality depends on source quality, indexing, permissions, configuration, and
the user's question. A configured source or tool can also be unavailable,
return incomplete results, or fail.

GPT-RAG does not determine whether an organization has the right to use data,
whether an answer is legally compliant, or whether a deployment satisfies an
external framework. Its audit events are best-effort operational evidence, not
an independently attested or complete record. Review the fuller limitations in
[Governance and responsible operation](governance_overview.md).

## Human oversight and accountability

The adopter remains accountable for the deployed system and its outcomes.
Business and data owners should approve the purpose and data sources. Platform
teams should configure identity, networking, retention, and access. Runtime
operators should monitor health and investigate failures. People using or
acting on generated content should be able to recognize the assistant's role,
inspect relevant sources, and escalate uncertain or consequential outcomes.

Human review should match the use-case risk. It should occur before sensitive
data is connected, before material configuration changes are released, and
before generated output is used for consequential action.

## Data, privacy, and security considerations

Only connect data that the organization is authorized to process for the
defined users and purpose. Classify and minimize source scope, preserve
source-system authorization where supported, and test representative allowed
and denied access. Retrieved excerpts can enter model prompts, responses,
conversation history, or troubleshooting paths, so downstream handling must
match the source classification.

Use managed identities, least-privilege Azure RBAC, Key Vault references, and
network controls appropriate to the deployment. Do not place credentials in
prompts, source content, configuration, or telemetry. Retention and deletion
depend on the deployed Azure services and operator configuration; inspect and
test those settings rather than assuming one policy applies to every
deployment.

## Reliability and evaluation expectations

Evaluate the complete configured system, not only the model. Before release,
use representative questions, sources, identities, and failure conditions to
measure answer quality, retrieval relevance, source-reference usefulness,
authorization behavior, latency, and recovery. Include cases where the correct
behavior is to acknowledge uncertainty or return no answer.

Re-evaluate after changing models, prompts, indexes, grounding sources, tools,
permissions, or infrastructure. Monitor runtime health and cost, preserve
reviewable evidence appropriate to the scenario, and keep a tested rollback or
disable path. No evaluation set can guarantee future responses.

## Responsible deployment and operation

Start with a non-production environment. Confirm regional service support,
capacity, data boundaries, access assignments, network posture, logging,
retention, deletion, and incident procedures. Limit enabled sources and tools
to those required by the scenario. Document known limitations for users and
operators, and review them when the deployment changes.

The [Deployment Guide](deploy.md) describes supported deployment paths.
[Governance and responsible operation](governance_overview.md) provides the
detailed responsibility, data, telemetry, retention, and operational guidance.

## AI-assisted repository maintenance

GitHub Copilot coding agents and repository skills help maintainers with scoped
engineering work such as analysis, implementation, documentation, and
validation. These are engineering-time tools. They are separate from agents,
models, retrieval, and orchestration in a deployed GPT-RAG runtime.

Humans define or approve tasks and review resulting changes. Coding agents work
in ephemeral GitHub-hosted environments and are constrained by repository
instructions, specialized agent definitions, and reusable skills. The normal
pull request process still applies, and continuous integration validates
changes before merge.

### Azure evaluation access

When an approved maintenance task requires Azure deployment, the
[Copilot setup workflow](https://github.com/Azure/GPT-RAG/blob/main/.github/workflows/copilot-setup-steps.yml)
signs in through GitHub OpenID Connect (OIDC) using a dedicated managed
identity. No Azure client secret is configured or supplied. Required Azure
identifiers are stored as GitHub variables, and the coding-agent secret set is
empty.

Deployments use the fixed Azure Developer CLI environment
`gptrag-evaluation` and dedicated non-production resource group
`rg-gptrag-evaluation`. The identity has **Contributor** and **Role Based Access
Control Administrator** at that resource group only, for resource provisioning
and in-group role assignments. It has no subscription-wide Owner, Contributor,
or Reader assignment.

A [live OIDC smoke test](https://github.com/Azure/GPT-RAG/actions/runs/30205002536)
confirmed that reads outside the group are denied. It created, verified, and
deleted a temporary identity only inside the evaluation group, then confirmed
that no smoke-test identities remained. Evaluation resources are cleaned up
after testing.

The accepted boundary is recorded in
[ADR-0002](https://github.com/Azure/GPT-RAG/blob/main/docs/adr/ADR-0002-copilot-azure-oidc.md).
Changing the resource scope, identity model, or deployment target requires
maintainer review.
