---
name: engineering-principles
description: GPT-RAG architecture and implementation principles. Use for design, review, meaningful refactoring, Azure integration, security, testing, or operational changes.
---

# GPT-RAG engineering principles

Load only the references needed for the task:

| When the task involves | Read |
| --- | --- |
| Repository purpose, boundaries, components, or Azure architecture | [GPT-RAG architecture](references/gpt-rag-architecture.md) |
| Tests, validation, compatibility, or evidence | [Testing and evidence](references/testing-and-evidence.md) |
| Identity, secrets, networking, retrieval security, or operations | [Security and operations](references/security-and-operations.md) |

Use these principles as design questions rather than dogma. The task
requirements, executable configuration, versioned contracts, and current
implementation remain the sources of truth.
