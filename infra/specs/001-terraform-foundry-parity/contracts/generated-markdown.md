# Generated parity Markdown contract

`docs/terraform-parity.md` is generated from `parity/inventory.json` and is never edited directly.

## Required output

1. A generated-file warning and inventory schema version.
2. Both repository tags and immutable commits.
3. Generation timestamp derived from inventory data, not wall-clock execution.
4. A summary count by support status and scenario.
5. Capabilities sorted by category, then stable capability ID.
6. One row per capability and scenario.
7. Consumer impact, compatibility expectation, blocked reason, proposal links, and evidence links.
8. A statement that static validation and Terraform plan output are not deployment evidence.

Values are Markdown-escaped. Unknown fields fail generation. Running the generator twice against
the same inventory produces byte-identical output. CI fails when the committed document differs
from generated output.
