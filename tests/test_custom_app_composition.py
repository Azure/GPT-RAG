from __future__ import annotations

import json
import unittest
from pathlib import Path

from config.deployment.composition import compose_parameters


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = "samples/custom-app/containerapp"
CLASSIC = {
    "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
    "DEPLOY_ADMINISTRATIVE_PANEL": "false",
}


def source_parameters() -> dict[str, object]:
    return json.loads((ROOT / "main.parameters.json").read_text(encoding="utf-8"))


def apps_for(environment: dict[str, str]) -> list[dict[str, object]]:
    composed = compose_parameters(source_parameters(), environment)
    return composed["parameters"]["containerAppsList"]["value"]


class CustomAppCompositionTests(unittest.TestCase):
    def test_trio_composition_unchanged_without_custom_definition(self) -> None:
        expected = source_parameters()["parameters"]["containerAppsList"]["value"]
        self.assertEqual(expected, apps_for(dict(CLASSIC)))
        self.assertEqual(
            expected,
            apps_for({**CLASSIC, "AGENTLZ_APP_DEFINITION": "app-definition.json"}),
        )

    def test_sample_containerapp_composes_into_container_apps_list(self) -> None:
        apps = apps_for({**CLASSIC, "AGENTLZ_APP_DEFINITION": SAMPLE})
        trio = source_parameters()["parameters"]["containerAppsList"]["value"]
        self.assertEqual(trio, apps[: len(trio)])
        custom = apps[len(trio):]
        self.assertEqual(1, len(custom))
        web = custom[0]
        self.assertEqual("web", web["service_name"])
        self.assertTrue(web["external"])
        self.assertEqual("0.5", web["cpu"])
        self.assertEqual("1.0Gi", web["memory"])
        self.assertEqual("WEB_APP", web["canonical_name"])
        self.assertIsNone(web["name"])
        self.assertNotIn("image", web)
        self.assertIn("AcrPull", web["roles"])
        self.assertEqual(set(trio[2]), set(web))

    def test_sample_folder_or_file_selection_is_equivalent(self) -> None:
        by_folder = apps_for({**CLASSIC, "AGENTLZ_APP_DEFINITION": SAMPLE})
        by_file = apps_for(
            {**CLASSIC, "AGENTLZ_APP_DEFINITION": f"{SAMPLE}/app-definition.json"}
        )
        self.assertEqual(by_folder, by_file)

    def test_hosted_sample_adds_no_container_app(self) -> None:
        expected = source_parameters()["parameters"]["containerAppsList"]["value"]
        apps = apps_for(
            {**CLASSIC, "AGENTLZ_APP_DEFINITION": "samples/custom-app/hosted"}
        )
        self.assertEqual(expected, apps)


if __name__ == "__main__":
    unittest.main()
