# Audit event v1 contract

These schemas are the shared GPT-RAG audit contract consumed by orchestrator
v3.8.0 and ingestion v2.5.0.

`audit-event-v1.sha256` pins the exact LF-encoded bytes:

- Logical schema: `825db8ef40a81e2c19e5d80d37c565b6b47fc9a6540e9881d35cc12b8fde5aab`
- Application Insights wire schema: `066c8f5408610ab839d5121d06ca5bc59e8797e551d5c47c875c5ba52f7e0588`

Consumers must use `schema_version` when interpreting events and ignore unknown
optional fields. Technical audit evidence supports operator governance work but
does not establish legal or regulatory compliance.
