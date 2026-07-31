from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import patch

from config.deployment import appconfig
from config.deployment.composition import (
    DeploymentMode,
    compose_parameters,
    resolve_mode,
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
        self.assertFalse(parameters["deployHostedAgent"]["value"])
        self.assertEqual(
            {
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
                "DEPLOY_ADMINISTRATIVE_PANEL": "false",
                "DEPLOYMENT_TOPOLOGY": "classic",
                "CHAT_BACKEND": "orchestrator",
                "HOSTED_AGENT_BASE_URL": "",
                "HOSTED_AGENT_RESOURCE_SCOPE": "",
                "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS": "60",
            },
            settings_by_name(composed),
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
        self.assertEqual([], parameters["databaseContainersList"]["value"])
        self.assertNotIn(
            "CosmosDBBuiltInDataContributor", dataingest["roles"]
        )
        self.assertEqual("hosted_agent", settings_by_name(composed)["CHAT_BACKEND"])

    def test_hosted_with_panel_keeps_only_panel_backing_resources(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "DEPLOY_ADMINISTRATIVE_PANEL": "true",
            "HOSTED_AGENT_IMAGE_VERSION": DIGEST,
        }

        composed = compose_parameters(source_parameters(), environment)
        parameters = composed["parameters"]

        self.assertEqual(DeploymentMode.HOSTED_PANEL, resolve_mode(environment))
        self.assertEqual(
            ["frontend", "dataingest"],
            [
                app["service_name"]
                for app in parameters["containerAppsList"]["value"]
            ],
        )
        self.assertTrue(parameters["deployCosmosDb"]["value"])
        self.assertTrue(parameters["databaseContainersList"]["value"])
        self.assertEqual("hosted_agent", settings_by_name(composed)["CHAT_BACKEND"])

    def test_hosted_mode_rejects_mutable_image_reference(self) -> None:
        environment = {
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
            "HOSTED_AGENT_IMAGE_VERSION": "v3.9.0",
        }

        with self.assertRaisesRegex(ValueError, "immutable OCI digest"):
            compose_parameters(source_parameters(), environment)


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
                "DEPLOY_ADMINISTRATIVE_PANEL": "true",
                "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            },
            require_hosted_endpoint=True,
        )

        self.assertEqual("hosted_agent", settings["CHAT_BACKEND"])
        self.assertEqual("", settings["ORCHESTRATOR_BASE_URL"])
        self.assertEqual(
            "https://agent.example.test/protocols",
            settings["HOSTED_AGENT_BASE_URL"],
        )
        self.assertEqual(2, len(json.loads(settings["CONTAINER_APPS"])))

    @patch("config.deployment.appconfig._container_app", side_effect=_app)
    def test_hosted_runtime_fails_closed_without_scope(self, _mock: object) -> None:
        with self.assertRaisesRegex(ValueError, "explicit data-plane scope"):
            appconfig.build_settings(
                {
                    "AZURE_RESOURCE_GROUP": "rg-test",
                    "RESOURCE_TOKEN": "test",
                    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "true",
                    "HOSTED_AGENT_BASE_URL": "https://agent.example.test/protocols",
                },
                require_hosted_endpoint=True,
            )


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
