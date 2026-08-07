# Shared GPT-RAG contracts

## Audit event v1

These schemas are the shared GPT-RAG audit contract consumed by orchestrator
v3.8.0 and ingestion v2.5.0.

`audit-event-v1.sha256` pins the exact LF-encoded bytes:

- Logical schema: `825db8ef40a81e2c19e5d80d37c565b6b47fc9a6540e9881d35cc12b8fde5aab`
- Application Insights wire schema: `066c8f5408610ab839d5121d06ca5bc59e8797e551d5c47c875c5ba52f7e0588`

Consumers must use `schema_version` when interpreting events and ignore unknown
optional fields. Technical audit evidence supports operator governance work but
does not establish legal or regulatory compliance.

## Hosted conversation ownership

The preferred binding is `HOSTED_CONVERSATION_OWNER_BINDING=delegated`. The
trusted UI BFF derives the opaque `x-ms-user-identity` value only from its
authenticated server-side user principal and sends it to the hosted Responses
2.0.0 endpoint. Browser input is never an ownership source. This identity value
is also separate from OBO access tokens: OBO remains authorization for retrieval
and downstream data, while the delegated header partitions Foundry-managed
response chains.

The UI BFF receives exactly two direct assignments at the individual hosted
agent scope:

- Foundry Agent Consumer
  (`eed3b665-ab3a-47b6-8f48-c9382fb1dad6`).
- GPT-RAG Hosted Agent User Identity Impersonation
  (`bef66abe-a495-530a-be1d-5d882fecff03`), a custom role with no `Actions`
  and exactly
  `Microsoft.CognitiveServices/accounts/AIServices/agents/endpoints/UserIdentityImpersonation/action`
  in `DataActions`.

Inherited, group-derived, custom-equivalent, or broader assignments do not
satisfy this contract. Foundry User and Project Runtime User are prohibited.
The hosted container receives neither role and no ownership key. Before
continuity is enabled, setup verifies the live routed Responses protocol is
exactly 2.0.0 and both assignments are direct and exact. Until then,
`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED=false`,
`HOSTED_CONTINUITY_ENABLED=false`, and the runtime contract is HTTP 503.

## Hosted conversation capability v1 (disabled fallback)

`hosted-conversation-capability-v1.schema.json` is retained only for an explicit
`HOSTED_CONVERSATION_OWNER_BINDING=capability` fallback. Delegated deployments
do not provision or require its Key Vault, secret, secret role, or App
Configuration Key Vault reference. Switching to delegated removes active
fallback access and indirection while retaining historical secret versions.

In capability mode, the UI BFF derives `oid` from the authenticated server-side
principal, signs and verifies the canonical framing, and keeps the envelope at
the UI boundary. The hosted container receives neither the envelope nor the
HMAC key. The key must be in a dedicated UI BFF vault selected with
`HOSTED_CONTINUITY_KEY_VAULT_URI` or
`HOSTED_CONTINUITY_KEY_VAULT_NAME`; the shared workload vault is rejected.

`hosted-conversation-capability-v1.sha256` pins the exact LF-encoded schema
bytes. Capability consumers must reject unknown schema versions, invalid or
expired signatures, mismatched owners, and non-canonical framing.
