from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

from config.deployment.composition import (
    DeploymentMode,
    compose_parameters,
    materialized_settings,
    resolve_mode,
)


ROOT = Path(__file__).resolve().parents[1]


class IntegrationPinTests(unittest.TestCase):
    def test_manifest_contains_exact_integration_pins(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        components = {item["name"]: item for item in manifest["components"]}

        self.assertEqual("unreleased", manifest["tag"])
        self.assertEqual(
            "v2.5.0",
            manifest["ailz_tag"],
        )
        self.assertEqual(
            "cacf418216ce7381d06263e0dd704a86b8a6f225",
            manifest["ailz_commit"],
        )
        self.assertEqual(
            ("v4.0.0", "1033d0690736f9787e5f227559dc4071d2043b79"),
            (
                components["gpt-rag-orchestrator"]["tag"],
                components["gpt-rag-orchestrator"]["commit"],
            ),
        )
        self.assertEqual(
            ("v2.7.0", "84b927769ef0839110f2d68e3ca471e2260567cf"),
            (
                components["gpt-rag-ingestion"]["tag"],
                components["gpt-rag-ingestion"]["commit"],
            ),
        )
        self.assertEqual(
            ("v2.6.0", "81d6515d8fc365402e958e861b671af037a4cc75"),
            (
                components["gpt-rag-ui"]["tag"],
                components["gpt-rag-ui"]["commit"],
            ),
        )

    def test_gitmodule_and_gitlink_match_landing_zone_integration_pin(self) -> None:
        gitmodules = (ROOT / ".gitmodules").read_text(encoding="utf-8")
        self.assertIn(
            "branch = v2.5.0",
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
            "cacf418216ce7381d06263e0dd704a86b8a6f225",
            completed.stdout.strip(),
        )

    def test_zip_fallback_materializes_exact_landing_zone_commit(self) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "preProvision.ps1").read_text(encoding="utf-8-sig")
        sh = (scripts / "preProvision.sh").read_text(encoding="utf-8-sig")

        self.assertIn(
            "git -C $infraDir fetch --depth 1 origin $expectedInfraCommit",
            ps1,
        )
        self.assertIn(
            "checkout --detach $expectedInfraCommit",
            ps1,
        )
        self.assertIn(
            'git -C "$INFRA_DIR" fetch --depth 1 origin "$EXPECTED_INFRA_COMMIT"',
            sh,
        )
        self.assertIn(
            'checkout --detach "$EXPECTED_INFRA_COMMIT"',
            sh,
        )

    def test_preprovision_fails_when_topology_persistence_fails(self) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "preProvision.ps1").read_text(encoding="utf-8-sig")
        sh = (scripts / "preProvision.sh").read_text(encoding="utf-8-sig")

        self.assertIn(
            "Failed to persist resolved topology setting $name",
            ps1,
        )
        self.assertIn(
            "if ($LASTEXITCODE -ne 0)",
            ps1,
        )
        self.assertIn(
            "Failed to persist the resolved deployment topology",
            sh,
        )
        self.assertIn('if ! azd env set "$TOPO_KEY" "$TOPO_VALUE"', sh)

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
        self.assertEqual("classic", rollback["azd"]["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("orchestrator", rollback["azd"]["CHAT_BACKEND"])
        self.assertEqual("false", rollback["azd"]["PREPARE_HOSTED_AGENT"])
        self.assertEqual("false", rollback["azd"]["DEPLOY_HOSTED_AGENT"])
        self.assertEqual(
            "",
            rollback["azd"]["HOSTED_AGENT_IMAGE_STARTUP_COMMAND_SHA256"],
        )
        self.assertEqual(
            "false", rollback["azd"]["DEPLOY_ADMINISTRATIVE_PANEL"]
        )
        self.assertEqual("classic", rollback["azd"]["DEPLOYMENT_TOPOLOGY"])
        self.assertEqual("orchestrator", rollback["azd"]["CHAT_BACKEND"])
        self.assertEqual(
            "false", rollback["azd"]["PRESERVE_CLASSIC_RUNTIME"]
        )
        self.assertEqual(
            "false", rollback["azd"]["HOSTED_CUTOVER_COMPLETE"]
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
                "HOSTED_AGENT_IMAGE_VERSION": "",
                "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS": "60",
            },
            {
                key: value
                for key, value in rollback["appConfiguration"].items()
                if key != "label"
            },
        )

    def test_rollback_overrides_materialized_hosted_state_before_composition(
        self,
    ) -> None:
        rollback = json.loads(
            (ROOT / "config" / "deployment" / "rollback.json").read_text(
                encoding="utf-8"
            )
        )
        environment = materialized_settings(
            DeploymentMode.HOSTED_NO_PANEL,
            hosted_cutover_complete=True,
        )
        environment.update(
            {
                "PREPARE_HOSTED_AGENT": "true",
                "DEPLOY_HOSTED_AGENT": "true",
                "HOSTED_AGENT_BASE_URL": (
                    "https://agent.example.test/protocols"
                ),
                "HOSTED_AGENT_IMAGE_VERSION": "sha256:" + ("a" * 64),
                "HOSTED_AGENT_RESOURCE_SCOPE": "api://agent/.default",
            }
        )

        environment.update(rollback["azd"])
        composed = compose_parameters(
            json.loads(
                (ROOT / "main.parameters.json").read_text(encoding="utf-8")
            ),
            environment,
        )
        parameters = composed["parameters"]

        self.assertEqual(DeploymentMode.CLASSIC, resolve_mode(environment))
        self.assertFalse(parameters["prepareHostedAgent"]["value"])
        self.assertFalse(parameters["deployHostedAgent"]["value"])
        self.assertIn(
            "orchestrator",
            [
                app["service_name"]
                for app in parameters["containerAppsList"]["value"]
            ],
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

    def test_postprovision_hooks_invoke_panel_setup_module(self) -> None:
        # Issue #611 / ADR-0004: the container-scoped panel Cosmos RBAC
        # script must run from both the PowerShell and POSIX shell
        # postProvision hooks, with parity, exactly like every other
        # config.*.setup module.
        scripts = ROOT / "scripts"
        ps1 = (scripts / "postProvision.ps1").read_text(encoding="utf-8-sig")
        sh = (scripts / "postProvision.sh").read_text(encoding="utf-8-sig")

        self.assertIn("config.panel.setup", ps1)
        self.assertIn("config.panel.setup", sh)

    def test_preprovision_hooks_fetch_and_checkout_exact_manifest_commit(
        self,
    ) -> None:
        scripts = ROOT / "scripts"
        for name in ("preProvision.ps1", "preProvision.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                self.assertIn("ailz_commit", content)
                self.assertIn("fetch --depth 1 origin", content)
                self.assertIn("checkout --detach", content)
                self.assertIn("^[0-9a-f]{40}$", content)
                self.assertNotIn("clone --depth 1 --branch", content)

    def test_preprovision_hooks_prepare_infra_before_moving_the_pin(self) -> None:
        scripts = ROOT / "scripts"
        for name in ("preProvision.ps1", "preProvision.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                prepare = content.index("config.deployment.infra_checkout")
                submodule_update = content.index("git submodule update")
                exact_checkout = content.index("checkout --detach")
                self.assertLess(prepare, submodule_update)
                self.assertLess(prepare, exact_checkout)
        shell = (scripts / "preProvision.sh").read_text(encoding="utf-8-sig")
        self.assertIn("exit $INFRA_CHECKOUT_EXIT", shell)

    def test_postprovision_hooks_delegate_runtime_switch_to_shared_publisher(
        self,
    ) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "postProvision.ps1").read_text(encoding="utf-8-sig")
        settings_block = ps1.split("$settings = [ordered]@{", 1)[1].split(
            "}", 1
        )[0]
        self.assertNotIn("CHAT_BACKEND", settings_block)
        self.assertIn("config.deployment.appconfig", ps1)
        self.assertIn("$topologyInfo.runtime_topology", ps1)
        self.assertIn(
            "config.deployment.appconfig",
            (scripts / "postProvision.sh").read_text(encoding="utf-8-sig"),
        )

    def test_postprovision_fails_closed_when_foundry_project_is_unresolved(
        self,
    ) -> None:
        content = (ROOT / "scripts" / "postProvision.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn(
            "Microsoft.CognitiveServices/accounts/projects",
            content,
        )

    def test_postprovision_preserves_search_user_assigned_identity(self) -> None:
        content = (ROOT / "scripts" / "postProvision.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("Get-UserAssignedIdentityResourceId", content)
        self.assertIn(
            "SEARCH_SERVICE_UAI_RESOURCE_ID = $searchServiceUaiResourceId",
            content,
        )
        self.assertNotIn("SEARCH_SERVICE_UAI_RESOURCE_ID = ''", content)
        self.assertIn('Set-Item -Path "Env:$key" -Value $flatSettings[$key]', content)
        self.assertIn("$foundryProjects.Count -ne 1", content)
        self.assertIn("AI_FOUNDRY_PROJECT_NAME", content)
        self.assertNotIn("aifoundry-default-project", content)
        self.assertNotIn("cognitiveservices account list-projects", content)

    def test_predeploy_hooks_gate_cutover_on_success_marker(self) -> None:
        scripts = ROOT / "scripts"
        for name in ("preDeploy.ps1", "preDeploy.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                self.assertIn("HOSTED_CUTOVER_COMPLETE", content)
                if name == "preDeploy.ps1":
                    self.assertIn(
                        "Invoke-PythonModule -ModuleName "
                        "'config.deployment.appconfig' -Arguments "
                        "@('--require-hosted-endpoint')",
                        content,
                    )
                else:
                    self.assertIn(
                        "config.deployment.appconfig --require-hosted-endpoint",
                        content,
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
                self.assertIn("AZD_AGENT_SKIP_ACR", content)
                self.assertIn("PYTHONPATH", content)
                if name == "preDeploy.ps1":
                    self.assertIn("runpy.run_module", content)
                self.assertIn(
                    "AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT", content
                )

    def test_both_predeploy_hooks_export_azd_values_for_final_cutover(
        self,
    ) -> None:
        scripts = ROOT / "scripts"
        ps1 = (scripts / "preDeploy.ps1").read_text(encoding="utf-8-sig")
        sh = (scripts / "preDeploy.sh").read_text(encoding="utf-8-sig")

        self.assertIn('Set-Item -Path "Env:$($prop.Name)"', ps1)
        self.assertIn("azd env get-values", sh)
        self.assertIn('export "$key=$value"', sh)
        for content in (ps1, sh):
            self.assertIn("config.deployment.appconfig", content)

    def test_both_predeploy_hooks_cut_over_after_components_and_persist_last(
        self,
    ) -> None:
        scripts = ROOT / "scripts"
        for name in ("preDeploy.ps1", "preDeploy.sh"):
            with self.subTest(script=name):
                content = (scripts / name).read_text(encoding="utf-8-sig")
                component_failure_gate = content.rindex(
                    "One or more components failed"
                )
                publisher = content.index(
                    "config.deployment.appconfig",
                    component_failure_gate,
                )
                endpoint_persistence = content.index(
                    "azd env set HOSTED_AGENT_BASE_URL",
                    publisher,
                )
                marker_persistence = content.index(
                    "azd env set HOSTED_CUTOVER_COMPLETE true",
                    publisher,
                )
                self.assertLess(component_failure_gate, publisher)
                self.assertLess(publisher, endpoint_persistence)
                self.assertLess(endpoint_persistence, marker_persistence)

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
        self.assertIn(
            'export HOSTED_AGENT_PREPARED="$hosted_prepared"',
            sh,
        )
        self.assertIn(
            'export DEPLOY_HOSTED_AGENT="$deploy_hosted"',
            sh,
        )
        self.assertIn(
            'export HOSTED_AGENT_STARTUP_COMMAND="$hosted_startup_command"',
            sh,
        )

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
        self.assertIn('then join(" ")', sh)
        self.assertIn(".name", sh)

    def test_hosted_manifest_contains_no_secret_values(self) -> None:
        content = (ROOT / "hosted-agent" / "azure.yaml").read_text(
            encoding="utf-8"
        )
        self.assertIn("host: azure.ai.agent", content)
        self.assertIn("language: docker", content)
        self.assertIn("remoteBuild: true", content)
        self.assertIn("protocol: responses", content)
        self.assertIn("protocol: invocations", content)
        self.assertNotIn("API_KEY", content)
        self.assertNotIn("PASSWORD", content)
        self.assertNotIn("InstrumentationKey=", content)
        self.assertNotIn("AccountKey=", content)


if __name__ == "__main__":
    unittest.main()
