from __future__ import annotations

import subprocess
import unittest
from unittest.mock import MagicMock, patch

from config.deployment.hosted_prepare import (
    persist_digest,
    prepare_environment,
)


DIGEST = "sha256:" + ("a" * 64)
NEW_DIGEST = "sha256:" + ("b" * 64)
SOURCE_COMMIT = "eaa787340c27d8df5bb550147e95c5ecd02ad385"
OLD_COMMIT = "1" * 40
MANIFEST = {
    "components": [
        {
            "name": "gpt-rag-orchestrator",
            "repo": "https://github.com/azure/gpt-rag-orchestrator.git",
            "tag": "v3.10.0",
            "commit": SOURCE_COMMIT,
        }
    ]
}


def hosted_environment(**overrides: str) -> dict[str, str]:
    environment = {
        "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
        "HOSTED_AGENT_PREPARED": "true",
        "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        "AZURE_AI_PROJECT_ENDPOINT": "https://project.example.test",
        "AZURE_AI_PROJECT_RESOURCE_ID": "/subscriptions/s/resourceGroups/r/providers/Microsoft.CognitiveServices/accounts/a/projects/p",
        "AZURE_CONTAINER_REGISTRY_ENDPOINT": "registry.azurecr.io",
        "AZURE_RESOURCE_GROUP": "rg-test",
        "NETWORK_ISOLATION": "false",
    }
    environment.update(overrides)
    return environment


class PrepareEnvironmentTests(unittest.TestCase):
    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_classic_topology_is_a_no_build_noop(
        self, mock_prepare: MagicMock
    ) -> None:
        digest, source_commit = prepare_environment(
            {"DEPLOYMENT_TOPOLOGY": "classic"},
            MANIFEST,
        )

        self.assertIsNone(digest)
        self.assertIsNone(source_commit)
        mock_prepare.assert_not_called()

    @patch("config.deployment.hosted_prepare.resolve_az_command")
    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_public_build_uses_manifest_pin_without_agent_pool(
        self,
        mock_prepare: MagicMock,
        mock_resolve_az: MagicMock,
    ) -> None:
        mock_prepare.return_value = NEW_DIGEST
        mock_resolve_az.return_value = "az"

        digest, source_commit = prepare_environment(
            hosted_environment(),
            MANIFEST,
        )

        self.assertEqual(NEW_DIGEST, digest)
        self.assertEqual(SOURCE_COMMIT, source_commit)
        self.assertEqual(
            "v3.10.0",
            mock_prepare.call_args.kwargs["source_ref"],
        )
        self.assertEqual(
            SOURCE_COMMIT,
            mock_prepare.call_args.kwargs["source_commit"],
        )
        self.assertIsNone(mock_prepare.call_args.kwargs["agent_pool"])

    @patch("config.deployment.hosted_prepare.resolve_az_command")
    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_private_build_uses_provisioned_agent_pool(
        self,
        mock_prepare: MagicMock,
        mock_resolve_az: MagicMock,
    ) -> None:
        mock_prepare.return_value = NEW_DIGEST
        mock_resolve_az.return_value = "az"

        prepare_environment(
            hosted_environment(
                NETWORK_ISOLATION="true",
                ACR_TASK_AGENT_POOL="build-pool",
            ),
            MANIFEST,
        )

        self.assertEqual(
            "build-pool",
            mock_prepare.call_args.kwargs["agent_pool"],
        )

    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_private_build_fails_without_agent_pool(
        self, mock_prepare: MagicMock
    ) -> None:
        with self.assertRaisesRegex(ValueError, "ACR_TASK_AGENT_POOL"):
            prepare_environment(
                hosted_environment(NETWORK_ISOLATION="true"),
                MANIFEST,
            )
        mock_prepare.assert_not_called()

    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_explicit_digest_override_skips_build(
        self, mock_prepare: MagicMock
    ) -> None:
        mock_prepare.return_value = DIGEST

        digest, source_commit = prepare_environment(
            hosted_environment(HOSTED_AGENT_IMAGE_VERSION=DIGEST),
            MANIFEST,
        )

        self.assertEqual(DIGEST, digest)
        self.assertIsNone(source_commit)
        self.assertEqual(
            DIGEST,
            mock_prepare.call_args.kwargs["image_version"],
        )
        self.assertEqual("", mock_prepare.call_args.kwargs["source_repo"])

    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_command_override_clears_stale_generated_provenance(
        self, mock_prepare: MagicMock
    ) -> None:
        mock_prepare.return_value = NEW_DIGEST

        digest, source_commit = prepare_environment(
            hosted_environment(
                HOSTED_AGENT_IMAGE_VERSION=DIGEST,
                HOSTED_AGENT_IMAGE_SOURCE_COMMIT=SOURCE_COMMIT,
            ),
            MANIFEST,
            image_version_override=NEW_DIGEST,
        )

        self.assertEqual(NEW_DIGEST, digest)
        self.assertIsNone(source_commit)
        self.assertEqual(
            NEW_DIGEST,
            mock_prepare.call_args.kwargs["image_version"],
        )

    @patch("config.deployment.hosted_prepare.resolve_az_command")
    @patch("config.deployment.hosted_prepare.prepare_hosted_image")
    def test_stale_generated_digest_rebuilds_current_manifest_pin(
        self,
        mock_prepare: MagicMock,
        mock_resolve_az: MagicMock,
    ) -> None:
        mock_prepare.return_value = NEW_DIGEST
        mock_resolve_az.return_value = "az"

        digest, source_commit = prepare_environment(
            hosted_environment(
                HOSTED_AGENT_IMAGE_VERSION=DIGEST,
                HOSTED_AGENT_IMAGE_SOURCE_COMMIT=OLD_COMMIT,
            ),
            MANIFEST,
        )

        self.assertEqual(NEW_DIGEST, digest)
        self.assertEqual(SOURCE_COMMIT, source_commit)
        self.assertIsNone(mock_prepare.call_args.kwargs["image_version"])


class PersistDigestTests(unittest.TestCase):
    @patch("config.deployment.hosted_prepare.shutil.which")
    @patch("config.deployment.hosted_prepare.subprocess.run")
    def test_persists_digest_and_generated_source_commit(
        self,
        mock_run: MagicMock,
        mock_which: MagicMock,
    ) -> None:
        mock_which.return_value = "azd"
        mock_run.return_value = subprocess.CompletedProcess([], 0)

        persist_digest(
            {"AZURE_ENV_NAME": "test"},
            DIGEST,
            SOURCE_COMMIT,
        )

        self.assertEqual(3, mock_run.call_count)
        commands = [call.args[0] for call in mock_run.call_args_list]
        self.assertEqual(
            [
                "HOSTED_AGENT_IMAGE_VERSION",
                "HOSTED_AGENT_IMAGE_SOURCE_COMMIT",
                "HOSTED_AGENT_IMAGE_VERSION",
            ],
            [command[3] for command in commands],
        )
        self.assertEqual("", commands[0][4])
        self.assertEqual(SOURCE_COMMIT, commands[1][4])
        self.assertEqual(DIGEST, commands[2][4])

    @patch("config.deployment.hosted_prepare.shutil.which")
    @patch("config.deployment.hosted_prepare.subprocess.run")
    def test_explicit_override_clears_generated_source_commit(
        self,
        mock_run: MagicMock,
        mock_which: MagicMock,
    ) -> None:
        mock_which.return_value = "azd"
        mock_run.return_value = subprocess.CompletedProcess([], 0)

        persist_digest(
            {"AZURE_ENV_NAME": "test"},
            DIGEST,
            None,
        )

        commands = [call.args[0] for call in mock_run.call_args_list]
        source_command = next(
            command
            for command in commands
            if "HOSTED_AGENT_IMAGE_SOURCE_COMMIT" in command
        )
        source_index = source_command.index(
            "HOSTED_AGENT_IMAGE_SOURCE_COMMIT"
        )
        self.assertEqual("", source_command[source_index + 1])


if __name__ == "__main__":
    unittest.main()
