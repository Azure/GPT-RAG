from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class IntegrationPinTests(unittest.TestCase):
    def test_manifest_contains_exact_integration_pins(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        components = {item["name"]: item for item in manifest["components"]}

        self.assertEqual("unreleased", manifest["tag"])
        self.assertEqual(
            "develop",
            manifest["ailz_tag"],
        )
        self.assertEqual(
            "1775f871641311868a15792bf3dc836024c9fb20",
            manifest["ailz_commit"],
        )
        self.assertEqual(
            ("v3.10.0", "eaa787340c27d8df5bb550147e95c5ecd02ad385"),
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
            ("v2.5.1", "971d92a8affd1c859befa4783a26eebc899b425c"),
            (
                components["gpt-rag-ui"]["tag"],
                components["gpt-rag-ui"]["commit"],
            ),
        )

    def test_gitmodule_and_gitlink_match_landing_zone_integration_pin(self) -> None:
        gitmodules = (ROOT / ".gitmodules").read_text(encoding="utf-8")
        self.assertIn(
            "branch = develop",
            gitmodules,
        )

        completed = subprocess.run(
            ["git", "-C", "infra", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn(
            "1775f871641311868a15792bf3dc836024c9fb20",
            completed.stdout.strip(),
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
        self.assertEqual("false", rollback["azd"]["PREPARE_HOSTED_AGENT"])
        self.assertEqual("false", rollback["azd"]["DEPLOY_HOSTED_AGENT"])
        self.assertEqual(
            "false", rollback["azd"]["DEPLOY_ADMINISTRATIVE_PANEL"]
        )
        self.assertEqual(
            "orchestrator", rollback["appConfiguration"]["CHAT_BACKEND"]
        )
        self.assertEqual(
            {
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION": "false",
                "PREPARE_HOSTED_AGENT": "false",
                "DEPLOY_HOSTED_AGENT": "false",
                "HOSTED_AGENT_PREPARED": "false",
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

    def test_lifecycle_hooks_resolve_topology_through_shared_module(self) -> None:
        # ADR-0001 rev. 5: config.deployment.topology is the single source of
        # truth for the fresh-vs-existing/sticky/conflict decision.
        # preProvision resolves and materializes it (no --describe: it is the
        # one hook allowed to perform the Azure resource-group/App
        # Configuration lookups); preDeploy and postProvision.ps1 only ever
        # read the already-materialized decision back via --describe and
        # must never re-derive it independently.
        scripts = ROOT / "scripts"

        for name in ("preProvision.ps1", "preProvision.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                self.assertIn("config.deployment.topology", content)
                # preProvision resolves and materializes topology itself; it
                # must invoke the module without --describe at least once
                # (a comment may still mention --describe when explaining
                # that later hooks read the decision back).
                self.assertTrue(
                    "-m config.deployment.topology\n" in content
                    or "-m config.deployment.topology)" in content
                    or "-m config.deployment.topology\"" in content
                )

        for name in (
            "preDeploy.ps1",
            "preDeploy.sh",
            "postProvision.ps1",
        ):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                self.assertIn("config.deployment.topology", content)
                self.assertTrue(
                    "--describe" in content
                    or "--validate-hosted-deploy" in content
                )

    def test_postprovision_sh_relies_on_materialized_azd_env_not_reresolution(
        self,
    ) -> None:
        # postProvision.sh intentionally does not call config.deployment.topology
        # directly: it mirrors the azd environment (already populated by
        # preProvision) into process env and delegates App Configuration
        # publishing to config.deployment.appconfig, whose resolve_mode() is
        # explicit-signal-only and therefore safe to call only because the
        # topology decision was already materialized upstream.
        content = (ROOT / "scripts" / "postProvision.sh").read_text(
            encoding="utf-8-sig"
        )
        self.assertNotIn("config.deployment.topology", content)
        self.assertIn("config.deployment.appconfig", content)
        self.assertIn("azd env get-values", content)

    def test_both_predeploy_hooks_select_components_and_hosted_agent(self) -> None:
        scripts = ROOT / "scripts"
        for name in ("preDeploy.ps1", "preDeploy.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                # ADR-0001 rev. 5: preDeploy no longer re-derives the hosted
                # flag, deployment mode, or component selection independently.
                # It reads the topology that preProvision already resolved
                # and materialized, via the shared
                # config.deployment.topology --describe contract, and filters
                # manifest.json's components against that read-back selection
                # (config.deployment.composition.selected_components) instead
                # of hardcoding component names per mode.
                self.assertIn("config.deployment.topology", content)
                self.assertIn("--validate-hosted-deploy", content)
                self.assertIn("deploy_hosted_agent_orchestration", content)
                self.assertIn("azd deploy orchestrator-agent", content)
                self.assertIn(
                    "AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT", content
                )

    def test_both_predeploy_hooks_fail_closed_on_missing_hosted_prerequisites(
        self,
    ) -> None:
        # preDeploy accepts only the second, digest-backed handoff phase.
        scripts = ROOT / "scripts"

        ps1 = (scripts / "preDeploy.ps1").read_text(encoding="utf-8-sig")
        self.assertIn("HOSTED_AGENT_RESOURCE_SCOPE", ps1)
        self.assertIn("AZURE_AI_PROJECT_ENDPOINT", ps1)
        self.assertIn("AZURE_AI_PROJECT_RESOURCE_ID", ps1)
        self.assertIn("FOUNDRY_PROJECT_ENDPOINT", ps1)
        self.assertIn("--validate-hosted-deploy", ps1)
        self.assertIn("HOSTED_AGENT_PREPARED", ps1)
        self.assertIn("DEPLOY_HOSTED_AGENT", ps1)

        sh = (scripts / "preDeploy.sh").read_text(encoding="utf-8-sig")
        self.assertIn("HOSTED_AGENT_RESOURCE_SCOPE", sh)
        self.assertIn("AZURE_AI_PROJECT_ENDPOINT", sh)
        self.assertIn("AZURE_AI_PROJECT_RESOURCE_ID", sh)
        self.assertIn("FOUNDRY_PROJECT_ENDPOINT", sh)
        self.assertIn("--validate-hosted-deploy", sh)
        self.assertIn("HOSTED_AGENT_PREPARED", sh)
        self.assertIn("DEPLOY_HOSTED_AGENT", sh)

    def test_hosted_image_preparation_is_pinned_parity_safe_and_classic_build_free(
        self,
    ) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "prepareHostedDeployment.ps1").read_text(
            encoding="utf-8-sig"
        )
        sh = (scripts / "prepareHostedDeployment.sh").read_text(
            encoding="utf-8-sig"
        )

        for token in (
            "config.deployment.hosted_prepare",
            "manifest.json",
            "azd env get-values",
        ):
            with self.subTest(token=token):
                self.assertIn(token, ps1)
                self.assertIn(token, sh)

        for name in ("preDeploy.ps1", "preDeploy.sh"):
            content = (scripts / name).read_text(encoding="utf-8-sig")
            self.assertNotIn("config.deployment.hosted_image", content)
            self.assertNotIn("azd provision --environment", content)

    def test_exact_upstream_prepare_deploy_contract_is_mapped(self) -> None:
        parameters = json.loads(
            (ROOT / "main.parameters.json").read_text(encoding="utf-8")
        )["parameters"]
        self.assertEqual(
            "${PREPARE_HOSTED_AGENT=false}",
            parameters["prepareHostedAgent"]["value"],
        )
        self.assertEqual(
            "${DEPLOY_HOSTED_AGENT=false}",
            parameters["deployHostedAgent"]["value"],
        )
        self.assertEqual(
            "${DEPLOY_ACR_TASK_AGENT_POOL=false}",
            parameters["deployAcrTaskAgentPool"]["value"],
        )

    def test_preprovision_fetches_exact_manifest_infra_commit(self) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "preProvision.ps1").read_text(encoding="utf-8-sig")
        sh = (scripts / "preProvision.sh").read_text(encoding="utf-8-sig")

        for content in (ps1, sh):
            with self.subTest(script="powershell" if content is ps1 else "shell"):
                self.assertIn("ailz_commit", content)
                self.assertIn("fetch --depth 1 origin", content)
                self.assertIn("checkout --detach --force FETCH_HEAD", content)
                self.assertIn("clean -ffdx", content)
                self.assertNotIn("clone --depth 1 --branch", content)

    def test_both_predeploy_hooks_filter_manifest_components_by_topology(
        self,
    ) -> None:
        # Component selection now flows from
        # config.deployment.composition.selected_components (exercised in
        # tests/test_deployment_modes.py) instead of being hardcoded per
        # script, so assert each hook filters manifest.json's components list
        # against the topology-provided selection rather than embedding a
        # duplicate ["gpt-rag-ui", "gpt-rag-orchestrator", "gpt-rag-ingestion"]
        # literal.
        scripts = ROOT / "scripts"
        ps1 = (scripts / "preDeploy.ps1").read_text(encoding="utf-8-sig")
        self.assertIn("$selectedComponents = @($topologyInfo.components)", ps1)
        self.assertIn("manifest.components", ps1)

        sh = (scripts / "preDeploy.sh").read_text(encoding="utf-8-sig")
        self.assertIn("selected_components", sh)
        self.assertIn(".components | join(\" \")", sh)
        self.assertIn(".name", sh)

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
