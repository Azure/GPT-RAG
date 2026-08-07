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

## Hosted conversation capability v1

`hosted-conversation-capability-v1.schema.json` defines the owner-bound
capability exchanged between the client and the UI BFF. The UI BFF is the only
component that creates, reads, appends to, or deletes Foundry managed
Conversations. It derives `oid` from the authenticated server-side principal,
signs the canonical length-prefixed framing, and verifies the capability before
every conversation operation. The capability is never forwarded to hosted
orchestration, so the hosted service does not read the caller object ID.

The hosted container receives neither the capability key nor authority to access
managed Conversations. The envelope contains a non-secret `key_id` and an HMAC
signature; the key itself remains in Key Vault and App Configuration stores only
a Key Vault reference. Enabling continuity requires a dedicated UI BFF vault via
`HOSTED_CONTINUITY_KEY_VAULT_URI` or `HOSTED_CONTINUITY_KEY_VAULT_NAME`; the
shared workload vault is rejected. The platform assigns the UI BFF secret-read
permission at the individual capability-secret scope.

`hosted-conversation-capability-v1.sha256` pins the exact LF-encoded schema
bytes. Consumers must reject unknown schema versions, invalid or expired
signatures, mismatched owners, and non-canonical framing.
