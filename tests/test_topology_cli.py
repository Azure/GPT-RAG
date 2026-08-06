"""Regression tests for the shared topology-resolution CLI/integration.

``config.deployment.topology`` is the single shared entry point used by both
``preProvision`` implementations (PowerShell and POSIX shell) to detect a
fresh vs. existing environment and materialize the resolved topology; and by
``preDeploy``/``postProvision`` (via ``--describe``) to read it back without
any further Azure CLI calls. These tests cover the Azure CLI plumbing
(``resource_group_exists``, ``read_persisted_settings``) in isolation from
the network, and the CLI wrapper's default/``--describe`` behavior end to
end.
"""

from __future__ import annotations

import json
import subprocess
import unittest
from unittest.mock import patch

from config.deployment import topology
from config.deployment.composition import DeploymentMode


def _completed(returncode: int, stdout: str = "", stderr: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


class ResourceGroupExistsTests(unittest.TestCase):
    def test_empty_name_short_circuits_without_calling_az(self) -> None:
        with patch("config.deployment.topology.subprocess.run") as mock_run:
            self.assertFalse(topology.resource_group_exists(""))
            self.assertFalse(topology.resource_group_exists(None))
            mock_run.assert_not_called()

    @patch("config.deployment.topology.subprocess.run")
    def test_true_when_az_reports_true(self, mock_run: object) -> None:
        mock_run.return_value = _completed(0, "true")

        self.assertTrue(
            topology.resource_group_exists("rg-test", "subscription-test")
        )
        called_args = mock_run.call_args.args[0]
        self.assertIn("--subscription", called_args)
        self.assertIn("subscription-test", called_args)

    @patch("config.deployment.topology.subprocess.run")
    def test_false_when_az_reports_false(self, mock_run: object) -> None:
        mock_run.return_value = _completed(0, "false")

        self.assertFalse(topology.resource_group_exists("rg-test"))

    @patch("config.deployment.topology.subprocess.run")
    def test_fails_closed_when_az_command_fails(self, mock_run: object) -> None:
        mock_run.return_value = _completed(1, "", "ERROR: not found")

        with self.assertRaisesRegex(Exception, "cannot safely continue"):
            topology.resource_group_exists("rg-test")


class ReadPersistedSettingsTests(unittest.TestCase):
    def test_empty_endpoint_short_circuits_without_calling_az(self) -> None:
        with patch("config.deployment.topology.subprocess.run") as mock_run:
            self.assertEqual({}, topology.read_persisted_settings(""))
            self.assertEqual({}, topology.read_persisted_settings(None))
            mock_run.assert_not_called()

    @patch("config.deployment.topology.subprocess.run")
    def test_reads_only_keys_that_exist(self, mock_run: object) -> None:
        mock_run.return_value = _completed(
            0,
            json.dumps(
                [
                    {"key": "DEPLOYMENT_TOPOLOGY", "value": "classic"},
                    {"key": "UNRELATED", "value": "ignored"},
                ]
            ),
        )

        settings = topology.read_persisted_settings("https://appconfig.example.test")

        self.assertEqual({"DEPLOYMENT_TOPOLOGY": "classic"}, settings)

    @patch("config.deployment.topology.subprocess.run")
    def test_returns_empty_when_nothing_persisted(self, mock_run: object) -> None:
        mock_run.return_value = _completed(0, "[]")

        settings = topology.read_persisted_settings("https://appconfig.example.test")

        self.assertEqual({}, settings)

    @patch("config.deployment.topology.subprocess.run")
    def test_fails_closed_when_existing_settings_cannot_be_read(
        self, mock_run: object
    ) -> None:
        mock_run.return_value = _completed(1, "", "ERROR: forbidden")

        with self.assertRaisesRegex(Exception, "cannot safely continue"):
            topology.read_persisted_settings("https://appconfig.example.test")


class ResolveEnvironmentTopologyTests(unittest.TestCase):
    @patch("config.deployment.topology.read_persisted_settings")
    @patch("config.deployment.topology.resource_group_exists")
    def test_fresh_environment_defaults_to_hosted_no_panel(
        self, mock_rg_exists: object, mock_read_settings: object
    ) -> None:
        mock_rg_exists.return_value = False

        mode = topology.resolve_environment_topology(
            {}, resource_group_name="rg-test", app_config_endpoint="https://x"
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)
        mock_read_settings.assert_not_called()

    @patch("config.deployment.topology.read_persisted_settings")
    @patch("config.deployment.topology.resource_group_exists")
    def test_existing_environment_reads_persisted_settings(
        self, mock_rg_exists: object, mock_read_settings: object
    ) -> None:
        mock_rg_exists.return_value = True
        mock_read_settings.return_value = {"DEPLOYMENT_TOPOLOGY": "classic"}

        mode = topology.resolve_environment_topology(
            {}, resource_group_name="rg-test", app_config_endpoint="https://x"
        )

        self.assertEqual(DeploymentMode.CLASSIC, mode)
        mock_read_settings.assert_called_once_with("https://x")

    @patch("config.deployment.topology.read_persisted_settings")
    @patch("config.deployment.topology.resource_group_exists")
    def test_explicit_classic_wins_without_reading_persisted_settings(
        self, mock_rg_exists: object, mock_read_settings: object
    ) -> None:
        mode = topology.resolve_environment_topology(
            {"DEPLOYMENT_TOPOLOGY": "classic"},
            resource_group_name="rg-test",
            app_config_endpoint="https://x",
        )

        self.assertEqual(DeploymentMode.CLASSIC, mode)
        mock_rg_exists.assert_not_called()
        mock_read_settings.assert_not_called()

    @patch("config.deployment.topology.read_persisted_settings")
    @patch("config.deployment.topology.resource_group_exists", return_value=True)
    def test_explicit_hosted_detects_existing_classic_migration(
        self, _mock_rg_exists: object, mock_read_settings: object
    ) -> None:
        mock_read_settings.return_value = {"DEPLOYMENT_TOPOLOGY": "classic"}

        mode, migrating = topology.resolve_environment_topology_context(
            {"DEPLOYMENT_TOPOLOGY": "hosted-no-panel"},
            resource_group_name="rg-test",
            app_config_endpoint="https://x",
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)
        self.assertTrue(migrating)

    @patch("config.deployment.topology.read_persisted_settings")
    @patch("config.deployment.topology.resource_group_exists")
    def test_materialized_migration_stays_sticky_without_azure_lookup(
        self, mock_rg_exists: object, mock_read_settings: object
    ) -> None:
        mode, migrating = topology.resolve_environment_topology_context(
            {
                "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
                "HOSTED_AGENT_MIGRATION": "true",
            },
            resource_group_name="rg-test",
            app_config_endpoint="https://x",
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)
        self.assertTrue(migrating)
        mock_rg_exists.assert_not_called()
        mock_read_settings.assert_not_called()


class MainCliTests(unittest.TestCase):
    @patch("config.deployment.topology.resource_group_exists", return_value=False)
    def test_default_mode_prints_materialized_settings(
        self, _mock_rg_exists: object
    ) -> None:
        argv = ["prog"]
        env = {"AZURE_RESOURCE_GROUP": "rg-test"}
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("builtins.print") as mock_print:
                exit_code = topology.main()

        self.assertEqual(0, exit_code)
        printed = "\n".join(call.args[0] for call in mock_print.call_args_list)
        self.assertIn("DEPLOYMENT_TOPOLOGY=hosted-no-panel", printed)
        self.assertIn("CHAT_BACKEND=hosted_agent", printed)
        self.assertIn("HOSTED_AGENT_MIGRATION=false", printed)

    def test_describe_mode_prints_json_without_any_azure_cli_call(self) -> None:
        argv = ["prog", "--describe"]
        env = {"DEPLOYMENT_TOPOLOGY": "classic"}
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("config.deployment.topology.subprocess.run") as mock_run:
                with patch("builtins.print") as mock_print:
                    exit_code = topology.main()
                mock_run.assert_not_called()

        self.assertEqual(0, exit_code)
        (payload,) = mock_print.call_args_list[0].args
        description = json.loads(payload)
        self.assertEqual("classic", description["topology"])
        self.assertEqual("orchestrator", description["chat_backend"])

    def test_validate_hosted_deploy_rejects_missing_foundry_project(self) -> None:
        argv = ["prog", "--validate-hosted-deploy"]
        env = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            "HOSTED_AGENT_IMAGE_VERSION": "sha256:" + ("a" * 64),
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("builtins.print") as mock_print:
                exit_code = topology.main()

        self.assertEqual(1, exit_code)
        self.assertIn("AZURE_AI_PROJECT_ENDPOINT", mock_print.call_args.args[0])

    def test_validate_hosted_context_allows_digest_to_be_prepared_later(
        self,
    ) -> None:
        argv = ["prog", "--validate-hosted-context"]
        env = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "AZURE_AI_PROJECT_ENDPOINT": "https://project.example.test",
            "AZURE_AI_PROJECT_RESOURCE_ID": "/subscriptions/test/projects/p",
        }
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("builtins.print") as mock_print:
                exit_code = topology.main()

        self.assertEqual(0, exit_code)
        (payload,) = mock_print.call_args_list[0].args
        self.assertEqual("hosted-no-panel", json.loads(payload)["topology"])

    def test_validate_hosted_deploy_rejects_unprepared_image(self) -> None:
        argv = ["prog", "--validate-hosted-deploy"]
        env = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "AZURE_AI_PROJECT_ENDPOINT": "https://project.example.test",
            "AZURE_AI_PROJECT_RESOURCE_ID": "/subscriptions/test/projects/p",
        }
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("builtins.print") as mock_print:
                exit_code = topology.main()

        self.assertEqual(1, exit_code)
        self.assertIn(
            "HOSTED_AGENT_IMAGE_VERSION",
            mock_print.call_args.args[0],
        )

    def test_canonical_topology_overrides_stale_compatibility_flag(
        self,
    ) -> None:
        argv = ["prog", "--describe"]
        env = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
        }
        with patch("sys.argv", argv), patch("os.environ", env):
            with patch("builtins.print") as mock_print:
                exit_code = topology.main()

        self.assertEqual(0, exit_code)
        (payload,) = mock_print.call_args_list[0].args
        description = json.loads(payload)
        self.assertEqual("hosted-no-panel", description["topology"])


if __name__ == "__main__":
    unittest.main()
