from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]


class ConversationsPanelContractTests(unittest.TestCase):
    def test_schema_checksum_matches_pinned_sha256(self) -> None:
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        checksum_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.sha256"
        )
        checksum = checksum_path.read_text(encoding="utf-8").split()[0]

        self.assertEqual(
            hashlib.sha256(
                schema_path.read_bytes().replace(b"\r\n", b"\n")
            ).hexdigest(),
            checksum,
        )

    def test_schema_is_valid_json_with_every_expected_shape(self) -> None:
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        defs = schema["$defs"]

        expected_defs = {
            "CorrelationId",
            "Cursor",
            "ConversationSummary",
            "ConversationsListResponse",
            "MessageItem",
            "MessagesResponse",
            "FeedbackCreateRequest",
            "FeedbackRecord",
            "FeedbackListResponse",
            "DeleteConversationResponse",
            "OperatorOverviewMetricsResponse",
            "SuppressibleCount",
            "CorpusCurationItem",
            "CorpusCurationQueueResponse",
            "CorpusCurationDecisionRequest",
            "CorpusCurationDecisionResponse",
            "ErrorResponse",
        }
        self.assertEqual(expected_defs, set(defs))

    def test_every_object_shape_forbids_extra_properties(self) -> None:
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))

        for name, definition in schema["$defs"].items():
            if definition.get("type") == "object":
                with self.subTest(shape=name):
                    self.assertFalse(
                        definition.get("additionalProperties", True),
                        f"{name} must set additionalProperties: false",
                    )

    def test_correlation_id_matches_audit_event_v1_pattern(self) -> None:
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        audit_schema_path = REPO_ROOT / "contracts" / "audit-event-v1.schema.json"
        panel_schema = json.loads(schema_path.read_text(encoding="utf-8"))
        audit_schema = json.loads(audit_schema_path.read_text(encoding="utf-8"))

        self.assertEqual(
            panel_schema["$defs"]["CorrelationId"]["pattern"],
            audit_schema["properties"]["correlation_id"]["pattern"],
        )

    def test_message_item_carries_no_document_or_citation_specific_fields(
        self,
    ) -> None:
        # MessageItem is deliberately minimal (role/content only) -- it is
        # read live from managed Conversations and never persisted to
        # Cosmos; the schema must not grow implementation-specific fields
        # that would encourage caching content elsewhere.
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        message_item = schema["$defs"]["MessageItem"]

        self.assertEqual(set(message_item["properties"]), {"role", "content"})

    def test_no_content_or_message_body_fields_in_metadata_shapes(self) -> None:
        # Cosmos-backed shapes must never define a field that could carry
        # chat content (ADR-0004 content-confinement).
        schema_path = (
            REPO_ROOT / "contracts" / "conversations-panel-v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        forbidden_field_names = {
            "content",
            "message_body",
            "transcript",
            "citation",
            "citations",
        }
        metadata_shapes = (
            "ConversationSummary",
            "FeedbackRecord",
            "CorpusCurationItem",
        )
        for name in metadata_shapes:
            with self.subTest(shape=name):
                fields = set(schema["$defs"][name]["properties"])
                self.assertEqual(fields & forbidden_field_names, set())


if __name__ == "__main__":
    unittest.main()
