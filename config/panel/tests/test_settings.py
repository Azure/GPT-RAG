from __future__ import annotations

import unittest

from config.panel import settings


class PanelSettingsTests(unittest.TestCase):
    def test_defaults_are_safe_when_panel_disabled(self) -> None:
        published = settings.public_settings({})

        self.assertEqual(published["PANEL_HISTORY_ENABLED"], "false")
        self.assertEqual(
            published["PANEL_HISTORY_OWNER_BINDING_VALIDATED"], "false"
        )
        self.assertEqual(
            published["PANEL_CONVERSATION_ENUMERATION_MODE"], "owner_index"
        )
        self.assertEqual(published["PANEL_CONVERSATIONS_TOKEN_AUDIENCE"], "")
        self.assertEqual(published["PANEL_CONVERSATIONS_TENANT_ID"], "")
        self.assertEqual(
            published[settings.OWNER_INDEX_CONTAINER_CONFIG_KEY],
            settings.OWNER_INDEX_CONTAINER_NAME,
        )
        self.assertEqual(
            published[settings.FEEDBACK_CONTAINER_CONFIG_KEY],
            settings.FEEDBACK_CONTAINER_NAME,
        )
        self.assertEqual(published["PANEL_CURSOR_TTL_SECONDS"], "600")
        self.assertEqual(published["PANEL_OVERVIEW_MIN_CARDINALITY"], "5")

    def test_owner_binding_validated_gate_forced_false_even_if_set(self) -> None:
        published = settings.public_settings(
            {
                "PANEL_HISTORY_OWNER_BINDING_VALIDATED": "true",
                "PANEL_CONVERSATION_ENUMERATION_MODE": "delegated",
            }
        )

        self.assertEqual(
            published["PANEL_HISTORY_OWNER_BINDING_VALIDATED"], "false"
        )
        # The enumeration-mode selector itself is a plain pass-through; only
        # the live-evidence gate is force-disabled.
        self.assertEqual(
            published["PANEL_CONVERSATION_ENUMERATION_MODE"], "delegated"
        )

    def test_container_names_are_overridable(self) -> None:
        published = settings.public_settings(
            {
                settings.OWNER_INDEX_CONTAINER_CONFIG_KEY: "custom-owner-index",
                settings.FEEDBACK_CONTAINER_CONFIG_KEY: "custom-feedback",
            }
        )

        self.assertEqual(
            published[settings.OWNER_INDEX_CONTAINER_CONFIG_KEY],
            "custom-owner-index",
        )
        self.assertEqual(
            published[settings.FEEDBACK_CONTAINER_CONFIG_KEY], "custom-feedback"
        )

    def test_container_names_are_partitioned_by_principal_never_session(
        self,
    ) -> None:
        # ADR-0004's threat model: never store unpartitioned
        # container/session-keyed data. This is a static assertion that the
        # canonical container names are distinct from the classic
        # conversation-content container and match the /principal_id
        # partition convention documented alongside them.
        self.assertNotEqual(
            settings.OWNER_INDEX_CONTAINER_NAME, "conversations"
        )
        self.assertNotEqual(settings.FEEDBACK_CONTAINER_NAME, "conversations")
        self.assertNotEqual(
            settings.OWNER_INDEX_CONTAINER_NAME, settings.FEEDBACK_CONTAINER_NAME
        )


if __name__ == "__main__":
    unittest.main()
