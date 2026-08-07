from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

from config.deployment import appconfig
from config.deployment.composition import (
    ConflictingTopologySignalsError,
    DeploymentMode,
    HostedPanelUnsupportedError,
    compose_parameters,
    describe_mode,
    materialized_settings,
    resolve_explicit_topology,
    resolve_mode,
    resolve_topology,
    selected_components,
)
from config.deployment.hosted import invocations_base_url


ROOT = Path(__file__).resolve().parents[1]
DIGEST = "sha256:" + ("a" * 64)


def source_parameters() -> dict[str, object]:
    return json.loads((ROOT / "main.parameters.json").read_text(encoding="utf-8"))


def settings_by_name(document: dict[str, object]) -> dict[str, str]:
    settings = document["parameters"]["additionalAppConfigurationSettings"]["value"]
    return {item["name"]: item["value"] for item in settings}


class DeploymentCompositionTests(unittest.TestCase):
    def test_false_defaults_preserve_classic_composition(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
        }

        composed = compose_parameters(source_parameters(), environment)
        parameters = composed["parameters"]
        apps = parameters["containerAppsList"]["value"]

        self.assertEqual(DeploymentMode.CLASSIC, resolve_mode(environment))
        self.assertEqual(
            ("gpt-rag-ui", "gpt-rag-orchestrator", "gpt-rag-ingestion"),
            selected_components(DeploymentMode.CLASSIC),
        )
        self.assertEqual(
            ["orchestrator", "frontend", "dataingest"],
            [app["service_name"] for app in apps],
        )
        self.assertTrue(parameters["deployCosmosDb"]["value"])
        self.assertFalse(parameters["prepareHostedAgent"]["value"])
        self.assertFalse(parameters["deployHostedAgent"]["value"])
        settings = settings_by_name(composed)
        expected = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
            "PREPARE_HOSTED_AGENT": "false",
            "DEPLOY_HOSTED_AGENT": "false",
            "HOSTED_AGENT_PREPARED": "false",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            "DEPLOYMENT_TOPOLOGY": "classic",
            "CHAT_BACKEND": "orchestrator",
            "HOSTED_AGENT_BASE_URL": "",
            "HOSTED_AGENT_RESOURCE_SCOPE": "",
            "HOSTED_AGENT_IMAGE_VERSION": "",
            "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS": "60",
        }
        self.assertTrue(expected.items() <= settings.items())
        self.assertEqual(
            settings["HOSTED_CONVERSATION_OWNER_BINDING"],
            "delegated",
        )
        self.assertEqual(
            settings["HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED"],
            "false",
        )
        self.assertEqual(
            settings["HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION"],
            "2.0.0",
        )
        self.assertEqual(
            settings["HOSTED_CONTINUITY_UNAVAILABLE_STATUS_CODE"],
            "503",
        )

    def test_panel_flag_does_not_change_classic_mode(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
            "DEPLOY_ADMINISTRATIVE_PANEL": "true",
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertEqual(DeploymentMode.CLASSIC, resolve_mode(environment))
        self.assertEqual(
            "false",
            settings_by_name(composed)["DEPLOY_ADMINISTRATIVE_PANEL"],
        )

    def test_hosted_without_panel_removes_orchestrator_and_cosmos(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }

        composed = compose_parameters(source_parameters(), environment)
        parameters = composed["parameters"]
        apps = parameters["containerAppsList"]["value"]
        dataingest = next(
            app for app in apps if app["service_name"] == "dataingest"
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, resolve_mode(environment))
        self.assertEqual(
            ("gpt-rag-ui", "gpt-rag-ingestion"),
            selected_components(DeploymentMode.HOSTED_NO_PANEL),
        )
        self.assertEqual(
            ["frontend", "dataingest"],
            [app["service_name"] for app in apps],
        )
        self.assertFalse(parameters["deployCosmosDb"]["value"])
        self.assertTrue(parameters["prepareHostedAgent"]["value"])
        self.assertTrue(parameters["deployHostedAgent"]["value"])
        self.assertEqual([], parameters["databaseContainersList"]["value"])
        self.assertNotIn(
            "CosmosDBBuiltInDataContributor", dataingest["roles"]
        )
        self.assertEqual("hosted_agent", settings_by_name(composed)["CHAT_BACKEND"])

    def test_fresh_hosted_composition_allows_automatic_image_preparation(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(composed["parameters"]["prepareHostedAgent"]["value"])
        self.assertFalse(composed["parameters"]["deployHostedAgent"]["value"])
        self.assertEqual(
            "",
            composed["parameters"]["hostedAgent"]["value"]["version"],
        )
        self.assertNotIn(
            "orchestrator",
            [
                app["service_name"]
                for app in composed["parameters"]["containerAppsList"]["value"]
            ],
        )
        self.assertEqual(
            "hosted_agent",
            settings_by_name(composed)["CHAT_BACKEND"],
        )

    def test_isolated_hosted_preparation_requests_dedicated_acr_pool(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "NETWORK_ISOLATION": "true",
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(
            composed["parameters"]["deployAcrTaskAgentPool"]["value"]
        )

    def test_classic_composition_preserves_acr_pool_operator_setting(
        self,
    ) -> None:
        source = source_parameters()

        composed = compose_parameters(
            source,
            {"DEPLOYMENT_TOPOLOGY": "classic", "NETWORK_ISOLATION": "true"},
        )

        self.assertEqual(
            source["parameters"]["deployAcrTaskAgentPool"],
            composed["parameters"]["deployAcrTaskAgentPool"],
        )

    def test_prepare_only_migration_preserves_classic_runtime(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "PRESERVE_CLASSIC_RUNTIME": "true",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }

        composed = compose_parameters(source_parameters(), environment)
        parameters = composed["parameters"]

        self.assertTrue(parameters["prepareHostedAgent"]["value"])
        self.assertFalse(parameters["deployHostedAgent"]["value"])
        self.assertTrue(parameters["deployCosmosDb"]["value"])
        self.assertEqual(
            ["orchestrator", "frontend", "dataingest"],
            [
                app["service_name"]
                for app in parameters["containerAppsList"]["value"]
            ],
        )
        self.assertNotEqual([], parameters["databaseContainersList"]["value"])
        self.assertEqual(
            "orchestrator",
            settings_by_name(composed)["CHAT_BACKEND"],
        )
        self.assertEqual(
            "classic",
            settings_by_name(composed)["DEPLOYMENT_TOPOLOGY"],
        )

    def test_migration_handoff_keeps_classic_runtime_until_endpoint(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "PRESERVE_CLASSIC_RUNTIME": "true",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(composed["parameters"]["deployHostedAgent"]["value"])
        self.assertIn(
            "orchestrator",
            [
                app["service_name"]
                for app in composed["parameters"]["containerAppsList"]["value"]
            ],
        )
        self.assertTrue(composed["parameters"]["deployCosmosDb"]["value"])
        self.assertEqual(
            "orchestrator",
            settings_by_name(composed)["CHAT_BACKEND"],
        )

    def test_migration_endpoint_without_success_marker_stays_classic(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "PRESERVE_CLASSIC_RUNTIME": "true",
            "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertIn(
            "orchestrator",
            [
                app["service_name"]
                for app in composed["parameters"]["containerAppsList"]["value"]
            ],
        )
        self.assertTrue(composed["parameters"]["deployCosmosDb"]["value"])
        self.assertEqual(
            "orchestrator",
            settings_by_name(composed)["CHAT_BACKEND"],
        )

    def test_migration_cuts_over_after_digest_and_endpoint_exist(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "PRESERVE_CLASSIC_RUNTIME": "true",
            "HOSTED_CUTOVER_COMPLETE": "true",
            "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertNotIn(
            "orchestrator",
            [
                app["service_name"]
                for app in composed["parameters"]["containerAppsList"]["value"]
            ],
        )
        self.assertFalse(composed["parameters"]["deployCosmosDb"]["value"])
        self.assertEqual(
            "hosted_agent",
            settings_by_name(composed)["CHAT_BACKEND"],
        )

    def test_migration_does_not_cut_over_without_success_marker(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "PRESERVE_CLASSIC_RUNTIME": "true",
            "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertEqual(
            "orchestrator",
            settings_by_name(composed)["CHAT_BACKEND"],
        )
        self.assertIn(
            "orchestrator",
            [
                app["service_name"]
                for app in composed["parameters"]["containerAppsList"]["value"]
            ],
        )

    def test_digest_materializes_deploy_handoff(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(composed["parameters"]["prepareHostedAgent"]["value"])
        self.assertTrue(composed["parameters"]["deployHostedAgent"]["value"])
        self.assertEqual(
            DIGEST,
            composed["parameters"]["hostedAgent"]["value"]["version"],
        )

    def test_network_isolated_hosted_mode_provisions_acr_agent_pool(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "NETWORK_ISOLATION": "true",
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(
            composed["parameters"]["deployAcrTaskAgentPool"]["value"]
        )

    def test_generated_digest_must_match_manifest_source_commit(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            "HOSTED_AGENT_IMAGE_SOURCE_COMMIT": "a" * 40,
        }

        with self.assertRaisesRegex(
            ValueError, "manifest.json now pins"
        ):
            compose_parameters(
                source_parameters(),
                environment,
                expected_hosted_source_commit="b" * 40,
            )

    def test_generated_digest_must_match_startup_command(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            "HOSTED_AGENT_IMAGE_SOURCE_COMMIT": "a" * 40,
            "HOSTED_AGENT_IMAGE_STARTUP_COMMAND_SHA256": "0" * 64,
        }

        with self.assertRaisesRegex(
            ValueError, "does not match.*HOSTED_AGENT_STARTUP_COMMAND"
        ):
            compose_parameters(
                source_parameters(),
                environment,
                expected_hosted_source_commit="a" * 40,
            )

    def test_hosted_with_panel_fails_closed_until_611(self) -> None:
        # Hosted-panel is not implemented yet (tracked by #611): any signal
        # that would actually select it must fail closed rather than
        # silently provisioning panel-adjacent resources.
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "true",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        with self.assertRaisesRegex(HostedPanelUnsupportedError, "611"):
            resolve_mode(environment)
        with self.assertRaisesRegex(HostedPanelUnsupportedError, "611"):
            compose_parameters(source_parameters(), environment)

    def test_legacy_generated_digest_without_startup_provenance_remains_valid(
        self,
    ) -> None:
        manifest = json.loads(
            (ROOT / "manifest.json").read_text(encoding="utf-8")
        )
        orchestrator = next(
            component
            for component in manifest["components"]
            if component["name"] == "gpt-rag-orchestrator"
        )
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            "HOSTED_AGENT_IMAGE_SOURCE_COMMIT": orchestrator["commit"],
        }

        composed = compose_parameters(source_parameters(), environment)

        self.assertTrue(composed["parameters"]["deployHostedAgent"]["value"])

    def test_deployment_topology_hosted_panel_fails_closed_until_611(self) -> None:
        environment = {"DEPLOYMENT_TOPOLOGY": "hosted-panel"}

        with self.assertRaisesRegex(HostedPanelUnsupportedError, "611"):
            resolve_mode(environment)

    def test_hosted_mode_rejects_mutable_image_reference(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "HOSTED_AGENT_IMAGE_VERSION": "v3.9.0",
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }

        with self.assertRaisesRegex(ValueError, "immutable OCI digest"):
            compose_parameters(source_parameters(), environment)

    def test_hosted_mode_rejects_noncanonical_uppercase_digest(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "HOSTED_AGENT_IMAGE_VERSION": "sha256:" + ("A" * 64),
            "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
        }

        with self.assertRaisesRegex(ValueError, "immutable OCI digest"):
            compose_parameters(source_parameters(), environment)

    def test_hosted_mode_rejects_missing_delegated_scope(self) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        with self.assertRaisesRegex(ValueError, "delegated-user data-plane scope"):
            compose_parameters(source_parameters(), environment)


class EnvironmentTopologyResolutionTests(unittest.TestCase):
    """Regression tests for ADR-0001 rev. 5 fresh-vs-existing resolution.

    ``resolve_topology`` is the single source of truth used by both
    ``preProvision`` implementations (PowerShell and POSIX shell) via
    ``config.deployment.topology``. These tests exercise it directly against
    synthetic "resource group exists" / "persisted App Config settings"
    inputs so the decision matrix is verified without any Azure CLI calls.
    """

    def test_fresh_deployment_defaults_to_hosted_no_panel(self) -> None:
        mode = resolve_topology({}, resource_group_exists=False)

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)
        self.assertEqual("hosted_agent", describe_mode(mode)["chat_backend"])

    def test_existing_environment_with_persisted_classic_topology_stays_classic(
        self,
    ) -> None:
        mode = resolve_topology(
            {},
            resource_group_exists=True,
            persisted_settings={"DEPLOYMENT_TOPOLOGY": "classic"},
        )

        self.assertEqual(DeploymentMode.CLASSIC, mode)

    def test_existing_environment_with_persisted_hosted_topology_stays_hosted(
        self,
    ) -> None:
        mode = resolve_topology(
            {},
            resource_group_exists=True,
            persisted_settings={
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                "DEPLOY_ADMINISTRATIVE_PANEL": "false",
            },
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)

    def test_existing_unmarked_pre_cutover_environment_is_classic(self) -> None:
        # A resource group exists (this is not a fresh deployment) but no
        # ADR-0001 topology markers were ever persisted -- this is a
        # pre-cutover environment and must not be silently promoted to
        # hosted just because it predates the new default.
        mode = resolve_topology({}, resource_group_exists=True, persisted_settings={})

        self.assertEqual(DeploymentMode.CLASSIC, mode)

    def test_existing_environment_without_persisted_settings_argument_is_classic(
        self,
    ) -> None:
        mode = resolve_topology({}, resource_group_exists=True)

        self.assertEqual(DeploymentMode.CLASSIC, mode)

    def test_persisted_chat_backend_is_a_topology_signal(self) -> None:
        mode = resolve_topology(
            {},
            resource_group_exists=True,
            persisted_settings={"CHAT_BACKEND": "orchestrator"},
        )

        self.assertEqual(DeploymentMode.CLASSIC, mode)

    def test_conflicting_persisted_backend_fails_closed(self) -> None:
        with self.assertRaisesRegex(
            ConflictingTopologySignalsError, "migration"
        ):
            resolve_topology(
                {},
                resource_group_exists=True,
                persisted_settings={
                    "DEPLOYMENT_TOPOLOGY": "classic",
                    "CHAT_BACKEND": "hosted_agent",
                },
            )

    def test_explicit_topology_wins_over_fresh_default(self) -> None:
        mode = resolve_topology(
            {"DEPLOYMENT_TOPOLOGY": "classic"},
            resource_group_exists=False,
        )

        self.assertEqual(DeploymentMode.CLASSIC, mode)

    def test_explicit_topology_wins_over_persisted_classic(self) -> None:
        mode = resolve_topology(
            {"DEPLOYMENT_TOPOLOGY": "hosted-no-panel"},
            resource_group_exists=True,
            persisted_settings={"DEPLOYMENT_TOPOLOGY": "classic"},
        )

        self.assertEqual(DeploymentMode.HOSTED_NO_PANEL, mode)

    def test_conflicting_persisted_signals_fail_with_migration_guidance(
        self,
    ) -> None:
        persisted = {
            "DEPLOYMENT_TOPOLOGY": "classic",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "false",
        }

        with self.assertRaisesRegex(
            ConflictingTopologySignalsError, "migration"
        ):
            resolve_topology(
                {}, resource_group_exists=True, persisted_settings=persisted
            )

    def test_canonical_topology_overrides_stale_materialized_flags(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
        }

        self.assertEqual(
            DeploymentMode.HOSTED_NO_PANEL,
            resolve_explicit_topology(environment),
        )
        self.assertEqual(
            DeploymentMode.HOSTED_NO_PANEL,
            resolve_topology(environment, resource_group_exists=True),
        )

    def test_explicit_classic_rollback_overrides_materialized_hosted_flags(
        self,
    ) -> None:
        environment = {
            "DEPLOYMENT_TOPOLOGY": "classic",
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "true",
            "CHAT_BACKEND": "hosted_agent",
        }

        self.assertEqual(
            DeploymentMode.CLASSIC,
            resolve_topology(environment, resource_group_exists=True),
        )

    def test_unknown_deployment_topology_value_fails_closed(self) -> None:
        with self.assertRaises(Exception):
            resolve_mode({"DEPLOYMENT_TOPOLOGY": "not-a-real-topology"})

    def test_materialized_settings_agree_with_describe_mode(self) -> None:
        for mode in (DeploymentMode.CLASSIC, DeploymentMode.HOSTED_NO_PANEL):
            materialized = materialized_settings(mode)
            description = describe_mode(mode)

            self.assertEqual(
                materialized["CHAT_BACKEND"], description["chat_backend"]
            )
            self.assertEqual(
                materialized["DEPLOY_ADMINISTRATIVE_PANEL"] == "true",
                description["deploy_administrative_panel"],
            )
            self.assertEqual(
                materialized["DEPLOY_HOSTED_AGENT_ORCHESTRATION"] == "true",
                description["deploy_hosted_agent_orchestration"],
            )
            # Materialized settings must round-trip: feeding them back
            # through resolve_mode as an explicit signal must reproduce the
            # same mode, since preDeploy/postProvision read them back via
            # `--describe` with no further Azure CLI lookups.
            self.assertEqual(mode, resolve_mode(materialized))

    def test_materialized_migration_preservation_round_trips(self) -> None:
        materialized = materialized_settings(
            DeploymentMode.HOSTED_NO_PANEL,
            preserve_classic_runtime=True,
        )

        self.assertEqual("true", materialized["PRESERVE_CLASSIC_RUNTIME"])
        self.assertEqual("false", materialized["DEPLOY_HOSTED_AGENT_ORCHESTRATION"])
        self.assertEqual("hosted-no-panel", materialized["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("orchestrator", materialized["CHAT_BACKEND"])
        self.assertTrue(
            describe_mode(
                DeploymentMode.HOSTED_NO_PANEL,
                preserve_classic_runtime=True,
            )["preserve_classic_runtime"]
        )

    def test_materialized_migration_switches_after_cutover(self) -> None:
        materialized = materialized_settings(
            DeploymentMode.HOSTED_NO_PANEL,
            preserve_classic_runtime=True,
            runtime_mode=DeploymentMode.HOSTED_NO_PANEL,
        )

        self.assertEqual("true", materialized["DEPLOY_HOSTED_AGENT_ORCHESTRATION"])
        self.assertEqual("hosted-no-panel", materialized["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("hosted_agent", materialized["CHAT_BACKEND"])


class AppConfigurationContractTests(unittest.TestCase):
    @staticmethod
    def _app(_resource_group: str, name: str, *, required: bool) -> dict[str, str]:
        del required
        return {"fqdn": f"{name}.example.test", "principalId": f"id-{name}"}

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_classic_runtime_references_orchestrator(self, _mock: object) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
            }
        )

        self.assertEqual("orchestrator", settings["CHAT_BACKEND"])
        self.assertEqual(
            "https://ca-test-orchestrator.example.test",
            settings["ORCHESTRATOR_BASE_URL"],
        )
        self.assertEqual("", settings["HOSTED_AGENT_BASE_URL"])
        self.assertEqual(3, len(json.loads(settings["CONTAINER_APPS"])))

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_uses_explicit_data_plane_contract(
        self, _mock: object
    ) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                "DEPLOY_ADMINISTRATIVE_PANEL": "false",
                "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
                "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
                "HOSTED_CONTINUITY_ENABLED": "true",
                "HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED": "true",
            },
            require_hosted_endpoint=True,
        )

        self.assertEqual("hosted_agent", settings["CHAT_BACKEND"])
        self.assertEqual("", settings["ORCHESTRATOR_BASE_URL"])
        self.assertEqual(
            "https://agent.example.test/protocols",
            settings["HOSTED_AGENT_BASE_URL"],
        )
        self.assertEqual(DIGEST, settings["HOSTED_AGENT_IMAGE_VERSION"])
        self.assertEqual(2, len(json.loads(settings["CONTAINER_APPS"])))
        self.assertEqual("delegated", settings["HOSTED_CONVERSATION_OWNER_BINDING"])
        self.assertEqual("false", settings["HOSTED_CONTINUITY_ENABLED"])
        self.assertEqual(
            "false",
            settings["HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED"],
        )

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_prepare_only_migration_keeps_classic_runtime_settings(
        self, _mock: object
    ) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
                "PRESERVE_CLASSIC_RUNTIME": "true",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            }
        )

        self.assertEqual("orchestrator", settings["CHAT_BACKEND"])
        self.assertEqual("classic", settings["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual(
            "https://ca-test-orchestrator.example.test",
            settings["ORCHESTRATOR_BASE_URL"],
        )
        self.assertEqual(3, len(json.loads(settings["CONTAINER_APPS"])))

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_fresh_hosted_without_endpoint_remains_fail_closed(
        self, _mock: object
    ) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
                "PRESERVE_CLASSIC_RUNTIME": "false",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            }
        )

        self.assertEqual("hosted_agent", settings["CHAT_BACKEND"])
        self.assertEqual("hosted-no-panel", settings["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("", settings["ORCHESTRATOR_BASE_URL"])
        self.assertEqual("", settings["HOSTED_AGENT_BASE_URL"])
        self.assertEqual(2, len(json.loads(settings["CONTAINER_APPS"])))

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_migration_switches_only_after_digest_and_endpoint_exist(
        self, _mock: object
    ) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
                "PRESERVE_CLASSIC_RUNTIME": "true",
                "HOSTED_CUTOVER_COMPLETE": "true",
                "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
                "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            }
        )

        self.assertEqual("hosted_agent", settings["CHAT_BACKEND"])
        self.assertEqual("hosted-no-panel", settings["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("", settings["ORCHESTRATOR_BASE_URL"])
        self.assertEqual(2, len(json.loads(settings["CONTAINER_APPS"])))

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_migration_does_not_publish_hosted_before_success_marker(
        self, _mock: object
    ) -> None:
        settings = appconfig.build_settings(
            {
                "AZURE_RESOURCE_GROUP": "rg-test",
                "RESOURCE_TOKEN": "test",
                "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
                "PRESERVE_CLASSIC_RUNTIME": "true",
                "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
                "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            }
        )

        self.assertEqual("orchestrator", settings["CHAT_BACKEND"])
        self.assertEqual("classic", settings["DEPLOYMENT_TOPOLOGY"])
        self.assertNotEqual("", settings["ORCHESTRATOR_BASE_URL"])

    @patch("config.deployment.appconfig._run_az")
    def test_publish_writes_chat_selector_after_hosted_prerequisites(
        self, mock_run_az: object
    ) -> None:
        appconfig.publish_settings(
            "https://config.example.test",
            {
                "CHAT_BACKEND": "hosted_agent",
                "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
            },
        )

        published_keys = [
            call.args[0][call.args[0].index("--key") + 1]
            for call in mock_run_az.call_args_list
        ]
        self.assertEqual(
            [
                "HOSTED_AGENT_BASE_URL",
                "HOSTED_AGENT_IMAGE_VERSION",
                "CHAT_BACKEND",
            ],
            published_keys,
        )

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_fails_closed_without_scope(self, _mock: object) -> None:
        with self.assertRaisesRegex(ValueError, "delegated-user data-plane scope"):
            appconfig.build_settings(
                {
                    "AZURE_RESOURCE_GROUP": "rg-test",
                    "RESOURCE_TOKEN": "test",
                    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                    "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                },
                require_hosted_endpoint=True,
            )

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_fails_closed_with_malformed_scope(
        self, _mock: object
    ) -> None:
        # A scope value that is present but does not end in '/.default' is
        # not a valid delegated-user data-plane scope and must fail closed
        # exactly like a missing scope, never silently coerced or accepted.
        with self.assertRaisesRegex(ValueError, "delegated-user data-plane scope"):
            appconfig.build_settings(
                {
                    "AZURE_RESOURCE_GROUP": "rg-test",
                    "RESOURCE_TOKEN": "test",
                    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                    "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                    "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/user_impersonation",
                },
                require_hosted_endpoint=True,
            )

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_rejects_scope_without_resource_identifier(
        self, _mock: object
    ) -> None:
        with self.assertRaisesRegex(ValueError, "non-empty resource identifier"):
            appconfig.build_settings(
                {
                    "AZURE_RESOURCE_GROUP": "rg-test",
                    "RESOURCE_TOKEN": "test",
                    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                    "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                    "HOSTED_AGENT_RESOURCE_SCOPE": "/.default",
                },
                require_hosted_endpoint=True,
            )

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_fails_closed_without_base_url(
        self, _mock: object
    ) -> None:
        with self.assertRaisesRegex(ValueError, "HOSTED_AGENT_BASE_URL"):
            appconfig.build_settings(
                {
                    "AZURE_RESOURCE_GROUP": "rg-test",
                    "RESOURCE_TOKEN": "test",
                    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                    "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
                },
                require_hosted_endpoint=True,
            )


class RunAzCommandResolutionTests(unittest.TestCase):
    """Regression tests for the Windows ``az.cmd`` shim lookup.

    ``subprocess.run(["az", ...])`` fails with ``FileNotFoundError``
    on Windows because ``CreateProcess`` does not consult ``PATHEXT``
    the way an interactive shell does. ``_run_az`` must resolve the
    executable via ``shutil.which`` first.
    """

    @patch("config.deployment.appconfig.resolve_az_command")
    @patch("config.deployment.appconfig.subprocess.run")
    def test_uses_resolved_executable_path(
        self, mock_run: object, mock_which: object
    ) -> None:
        mock_which.return_value = r"C:\path\to\az.cmd"
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="ok", stderr=""
        )

        result = appconfig._run_az(["group", "show"])

        mock_which.assert_called_once_with()
        called_args = mock_run.call_args.args[0]
        self.assertEqual(r"C:\path\to\az.cmd", called_args[0])
        self.assertEqual("ok", result)

    @patch("util.azure_cli.shutil.which")
    def test_falls_back_to_bare_command_when_unresolved(
        self, mock_which: object
    ) -> None:
        mock_which.return_value = None

        self.assertEqual("az", appconfig._resolve_az_command())


class HostedEndpointContractTests(unittest.TestCase):
    def test_protocol_endpoint_is_normalized_for_ui_client(self) -> None:
        self.assertEqual(
            "https://agent.example.test/protocols",
            invocations_base_url(
                "https://agent.example.test/protocols/invocations"
                "?api-version=2025-05-15-preview"
            ),
        )

    def test_non_invocations_endpoint_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "end with '/invocations'"):
            invocations_base_url(
                "https://agent.example.test/protocols/responses"
            )

    def test_non_https_endpoint_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "absolute HTTPS"):
            invocations_base_url("http://agent.example.test/invocations")


if __name__ == "__main__":
    unittest.main()
