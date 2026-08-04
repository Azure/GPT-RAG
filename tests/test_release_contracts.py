from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleasedPinTests(unittest.TestCase):
    def test_manifest_contains_exact_released_pins(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        components = {item["name"]: item for item in manifest["components"]}

        self.assertEqual("unreleased", manifest["tag"])
        self.assertEqual("v2.4.1", manifest["ailz_tag"])
        self.assertEqual(
            "fbc5d226543d0fb7a29ccd241c45df5c3caa82ee",
            manifest["ailz_commit"],
        )
        self.assertEqual(
            ("v3.9.0", "779b136d4da5d4bdcf9442dc1ec7a6115571f06a"),
            (
                components["gpt-rag-orchestrator"]["tag"],
                components["gpt-rag-orchestrator"]["commit"],
            ),
        )
        self.assertEqual(
            ("v2.6.0", "cb9f1a08a2e780c15ffd096f6e56c04b5e5bd4ca"),
            (
                components["gpt-rag-ingestion"]["tag"],
                components["gpt-rag-ingestion"]["commit"],
            ),
        )
        self.assertEqual(
            ("v2.5.0", "5328ec7e222e47f56b50b077ccf8a51c30f61681"),
            (
                components["gpt-rag-ui"]["tag"],
                components["gpt-rag-ui"]["commit"],
            ),
        )

    def test_gitmodule_and_gitlink_match_landing_zone_release(self) -> None:
        gitmodules = (ROOT / ".gitmodules").read_text(encoding="utf-8")
        self.assertIn("branch = v2.4.1", gitmodules)

        completed = subprocess.run(
            ["git", "ls-files", "--stage", "infra"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn(
            "fbc5d226543d0fb7a29ccd241c45df5c3caa82ee",
            completed.stdout,
        )

    def test_rollback_restores_full_classic_release_contract(self) -> None:
        rollback = json.loads(
            (ROOT / "config" / "deployment" / "rollback.json").read_text(
                encoding="utf-8"
            )
        )

        self.assertEqual("v3.7.0", rollback["umbrella"]["tag"])
        self.assertEqual("v2.3.0", rollback["umbrella"]["ailz_tag"])
        self.assertEqual(
            {
                "gpt-rag-ui": "v2.3.13",
                "gpt-rag-orchestrator": "v3.8.0",
                "gpt-rag-ingestion": "v2.5.0",
            },
            rollback["components"],
        )
        self.assertEqual(
            "false", rollback["azd"]["DEPLOY_HOSTED_AGENT_ORCHESTRATION"]
        )
        self.assertEqual(
            "false", rollback["azd"]["DEPLOY_ADMINISTRATIVE_PANEL"]
        )
        self.assertEqual(
            "orchestrator", rollback["appConfiguration"]["CHAT_BACKEND"]
        )
        self.assertEqual(
            {
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
                "DEPLOY_ADMINISTRATIVE_PANEL": "false",
                "CHAT_BACKEND": "orchestrator",
                "DEPLOYMENT_TOPOLOGY": "classic",
                "HOSTED_AGENT_BASE_URL": "",
                "HOSTED_AGENT_RESOURCE_SCOPE": "",
                "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS": "60",
            },
            {
                key: value
                for key, value in rollback["appConfiguration"].items()
                if key != "label"
            },
        )


class LifecycleParityTests(unittest.TestCase):
    def test_canonical_hosted_agent_adr_is_retained_and_revised(self) -> None:
        adr = ROOT / "docs" / "adr" / "ADR-0001-hosted-agents.md"
        self.assertTrue(adr.is_file())
        content = adr.read_text(encoding="utf-8")
        self.assertIn("ADR-0001", content)
        self.assertIn("implementation boundary implemented by issue #595", content)
        self.assertIn("Implemented accelerator and landing-zone boundary", content)
        self.assertIn("AI Landing Zone remains accelerator-neutral", content)

    def test_powershell_and_shell_hooks_use_shared_mode_contracts(self) -> None:
        pairs = (
            ("preProvision.ps1", "preProvision.sh", "deployment.composition"),
            ("postProvision.ps1", "postProvision.sh", "deployment.appconfig"),
        )
        scripts = ROOT / "scripts"

        for powershell, shell, contract in pairs:
            with self.subTest(contract=contract):
                self.assertIn(
                    contract,
                    (scripts / powershell).read_text(encoding="utf-8-sig"),
                )
                self.assertIn(
                    contract,
                    (scripts / shell).read_text(encoding="utf-8-sig"),
                )

    def test_both_predeploy_hooks_select_components_and_hosted_agent(self) -> None:
        scripts = ROOT / "scripts"
        for name in ("preDeploy.ps1", "preDeploy.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                self.assertIn("DEPLOY_HOSTED_AGENT_ORCHESTRATION", content)
                self.assertIn("gpt-rag-orchestrator", content)
                self.assertIn("gpt-rag-ingestion", content)
                self.assertIn("gpt-rag-ui", content)
                self.assertIn("azd deploy orchestrator-agent", content)
                self.assertIn(
                    "AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT", content
                )

    def test_hosted_manifest_contains_no_secret_values(self) -> None:
        content = (ROOT / "hosted-agent" / "azure.yaml").read_text(
            encoding="utf-8"
        )
        self.assertIn("host: azure.ai.agent", content)
        self.assertIn("protocol: responses", content)
        self.assertIn("protocol: invocations", content)
        self.assertNotIn("API_KEY", content)
        self.assertNotIn("PASSWORD", content)
        self.assertNotIn("InstrumentationKey=", content)
        self.assertNotIn("AccountKey=", content)


if __name__ == "__main__":
    unittest.main()
