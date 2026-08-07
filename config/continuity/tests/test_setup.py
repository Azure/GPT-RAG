from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

from azure.core.exceptions import ResourceNotFoundError

from config.continuity import setup


REPO_ROOT = Path(__file__).resolve().parents[3]


class ContinuitySetupTests(TestCase):
    def test_safe_defaults_disable_continuity_and_require_capabilities(self):
        values = dict(setup.DEFAULT_SETTINGS)

        settings = setup.validate_continuity_settings(values)

        self.assertFalse(settings.enabled)
        self.assertEqual(settings.owner_binding, "capability")
        self.assertFalse(settings.owner_binding_validated)
        self.assertEqual(
            settings.token_audience,
            "https://ai.azure.com",
        )
        self.assertEqual(settings.history_truncation, "drop_oldest")

    def test_enabled_continuity_fails_closed_without_validated_binding(self):
        values = {
            **setup.DEFAULT_SETTINGS,
            "HOSTED_CONTINUITY_ENABLED": "true",
        }

        with self.assertRaisesRegex(ValueError, "OWNER_BINDING_VALIDATED=true"):
            setup.validate_continuity_settings(
                values,
                deployment_topology="hosted-no-panel",
                chat_backend="hosted_agent",
            )

    def test_raw_caller_identity_binding_is_rejected_even_while_disabled(self):
        values = {
            **setup.DEFAULT_SETTINGS,
            "HOSTED_CONVERSATION_OWNER_BINDING": "oid",
        }

        with self.assertRaisesRegex(ValueError, "raw caller identifiers"):
            setup.validate_continuity_settings(values)

    def test_enabled_continuity_requires_hosted_no_panel_contract(self):
        values = {
            **setup.DEFAULT_SETTINGS,
            "HOSTED_CONTINUITY_ENABLED": "true",
            "HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED": "true",
        }

        with self.assertRaisesRegex(ValueError, "hosted deployment topology"):
            setup.validate_continuity_settings(
                values,
                deployment_topology="classic",
                chat_backend="orchestrator",
            )

    @patch.object(setup, "create_credential")
    @patch.object(setup, "AzureAppConfigurationClient")
    def test_invalid_environment_is_forced_disabled_before_any_publication(
        self,
        app_config_client_type,
        create_credential,
    ):
        app_config_client = app_config_client_type.return_value
        environment = {
            **setup.DEFAULT_SETTINGS,
            "APP_CONFIG_ENDPOINT": "https://appcs.example.azconfig.io",
            "HOSTED_CONTINUITY_ENABLED": "true",
            "HOSTED_CONVERSATION_OWNER_BINDING": "oid",
            "DEPLOYMENT_TOPOLOGY": "hosted-no-panel",
            "CHAT_BACKEND": "hosted_agent",
        }

        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(ValueError, "raw caller identifiers"):
                setup.main()

        create_credential.assert_called_once()
        published = [
            call.args[0]
            for call in app_config_client.set_configuration_setting.call_args_list
        ]
        self.assertEqual(len(published), 1)
        self.assertEqual(published[0].key, "HOSTED_CONTINUITY_ENABLED")
        self.assertEqual(published[0].value, "false")

    def test_secret_creation_and_rotation_are_idempotent_by_key_id(self):
        missing = Mock()
        missing.get_secret.side_effect = ResourceNotFoundError("missing")
        with patch.object(
            setup.secrets,
            "token_bytes",
            return_value=b"x" * 32,
        ):
            self.assertEqual(
                setup.ensure_capability_secret(missing, "v1"),
                "created",
            )
        secret_value = missing.set_secret.call_args.args[1]
        self.assertEqual(
            base64.urlsafe_b64decode(secret_value + "="),
            b"x" * 32,
        )
        self.assertNotIn(secret_value, str(missing.set_secret.call_args.kwargs))

        current = SimpleNamespace(
            value=secret_value,
            properties=SimpleNamespace(tags={"key_id": "v1"}),
        )
        reused = Mock()
        reused.get_secret.return_value = current
        self.assertEqual(
            setup.ensure_capability_secret(reused, "v1"),
            "reused",
        )
        reused.set_secret.assert_not_called()

        rotated = Mock()
        rotated.get_secret.return_value = current
        with patch.object(
            setup.secrets,
            "token_bytes",
            return_value=b"y" * 32,
        ):
            self.assertEqual(
                setup.ensure_capability_secret(rotated, "v2"),
                "rotated",
            )
        self.assertEqual(
            rotated.set_secret.call_args.kwargs["tags"]["key_id"],
            "v2",
        )

        untagged = Mock()
        untagged.get_secret.return_value = SimpleNamespace(
            value=secret_value,
            properties=SimpleNamespace(tags={}),
        )
        with patch.object(
            setup.secrets,
            "token_bytes",
            return_value=b"w" * 32,
        ):
            self.assertEqual(
                setup.ensure_capability_secret(untagged, "v1"),
                "rotated",
            )
        self.assertEqual(
            untagged.set_secret.call_args.kwargs["tags"]["key_id"],
            "v1",
        )

    def test_app_configuration_publishes_only_key_vault_reference(self):
        app_config_client = Mock()
        app_config_client.get_configuration_setting.return_value = None
        secret_client = Mock()
        secret_client.get_secret.side_effect = ResourceNotFoundError("missing")

        with patch.object(
            setup.secrets,
            "token_bytes",
            return_value=b"z" * 32,
        ):
            action = setup.apply_capability_key_reference(
                app_config_client,
                secret_client,
                "https://kv-ui.vault.azure.net/",
                "v1",
            )

        self.assertEqual(action, "created")
        setting = app_config_client.set_configuration_setting.call_args.args[0]
        self.assertEqual(setting.key, setup.CAPABILITY_CONFIG_KEY)
        self.assertEqual(
            setting.value,
            '{"uri":"https://kv-ui.vault.azure.net/secrets/'
            'HOSTED-CONVERSATION-CAPABILITY-KEY"}',
        )
        self.assertEqual(
            setting.content_type,
            setup.KEY_VAULT_REFERENCE_CONTENT_TYPE,
        )
        self.assertNotIn(
            secret_client.set_secret.call_args.args[1],
            setting.value,
        )

    def test_plaintext_capability_key_is_rejected(self):
        app_config_client = Mock()
        app_config_client.get_configuration_setting.return_value = SimpleNamespace(
            value="not-allowed",
            content_type="text/plain",
        )

        with self.assertRaisesRegex(ValueError, "plaintext"):
            setup.apply_capability_key_reference(
                app_config_client,
                Mock(),
                "https://kv-ui.vault.azure.net/",
                "v1",
            )

    def test_key_vault_reference_hostname_comparison_is_case_insensitive(self):
        self.assertTrue(
            setup._same_key_vault_reference(
                (
                    '{"uri":"https://KV-UI.vault.azure.net/secrets/'
                    'HOSTED-CONVERSATION-CAPABILITY-KEY"}'
                ),
                (
                    '{"uri":"https://kv-ui.vault.azure.net/secrets/'
                    'HOSTED-CONVERSATION-CAPABILITY-KEY"}'
                ),
            )
        )
        self.assertFalse(
            setup._same_key_vault_reference(
                (
                    '{"uri":"https://kv-ui.vault.azure.net:444/secrets/'
                    'HOSTED-CONVERSATION-CAPABILITY-KEY"}'
                ),
                (
                    '{"uri":"https://kv-ui.vault.azure.net/secrets/'
                    'HOSTED-CONVERSATION-CAPABILITY-KEY"}'
                ),
            )
        )

    def test_capability_vault_must_be_dedicated_to_the_ui_bff(self):
        with self.assertRaisesRegex(ValueError, "dedicated UI BFF Key Vault"):
            setup.resolve_capability_vault_uri(
                {
                    "KEY_VAULT_URI": "https://kv-shared.vault.azure.net/",
                    "HOSTED_CONTINUITY_KEY_VAULT_URI": (
                        "https://kv-shared.vault.azure.net/"
                    ),
                }
            )

        with self.assertRaisesRegex(ValueError, "dedicated UI BFF Key Vault"):
            setup.resolve_capability_vault_uri(
                {
                    "KEY_VAULT_URI": "https://kv-shared.vault.azure.net/",
                    "HOSTED_CONTINUITY_KEY_VAULT_URI": (
                        "https://KV-SHARED.vault.azure.net/"
                    ),
                }
            )

        self.assertEqual(
            setup.resolve_capability_vault_uri(
                {
                    "KEY_VAULT_URI": "https://kv-shared.vault.azure.net/",
                    "HOSTED_CONTINUITY_KEY_VAULT_NAME": "kv-ui",
                }
            ),
            "https://kv-ui.vault.azure.net/",
        )

    @patch.object(setup, "_run_az")
    def test_role_assignment_list_uses_valid_inherited_switch(self, run_az):
        run_az.return_value = "[]"

        setup._role_assignments(
            "principal",
            "/subscriptions/sub",
            include_inherited=True,
        )

        arguments = run_az.call_args.args[0]
        self.assertIn("--include-inherited", arguments)
        self.assertIn("--include-groups", arguments)
        self.assertNotIn("false", arguments)

    @patch.object(setup, "_role_assignments")
    @patch.object(setup, "_run_az")
    def test_capability_secret_access_is_frontend_only_and_secret_scoped(
        self,
        run_az,
        role_assignments,
    ):
        secret_scope = (
            "/subscriptions/sub/resourceGroups/rg/providers/"
            "Microsoft.KeyVault/vaults/kv-ui/secrets/"
            "HOSTED-CONVERSATION-CAPABILITY-KEY"
        )
        role_assignments.side_effect = [
            [],
            [
                {
                    "roleDefinitionId": (
                        "/subscriptions/sub/providers/Microsoft.Authorization/"
                        "roleDefinitions/"
                        f"{setup.KEY_VAULT_SECRETS_USER_ROLE_ID}"
                    ),
                    "scope": secret_scope,
                    "principalId": "frontend-principal",
                    "principalType": "ServicePrincipal",
                }
            ],
        ]
        run_az.return_value = ""

        self.assertTrue(
            setup.ensure_frontend_capability_secret_access(
                "frontend-principal",
                secret_scope,
            )
        )

        arguments = run_az.call_args.args[0]
        self.assertIn("frontend-principal", arguments)
        self.assertEqual(arguments[arguments.index("--scope") + 1], secret_scope)

    @patch.object(setup, "_role_assignments")
    def test_group_derived_secret_access_is_rejected(self, role_assignments):
        secret_scope = (
            "/subscriptions/sub/resourceGroups/rg/providers/"
            "Microsoft.KeyVault/vaults/kv-ui/secrets/"
            "HOSTED-CONVERSATION-CAPABILITY-KEY"
        )
        role_assignments.return_value = [
            {
                "roleDefinitionId": (
                    "/subscriptions/sub/providers/Microsoft.Authorization/"
                    "roleDefinitions/"
                    f"{setup.KEY_VAULT_SECRETS_USER_ROLE_ID}"
                ),
                "scope": secret_scope,
                "principalId": "group-principal",
                "principalType": "Group",
            }
        ]

        with self.assertRaisesRegex(RuntimeError, "UI BFF capability secret"):
            setup.ensure_frontend_capability_secret_access(
                "frontend-principal",
                secret_scope,
            )

    def test_live_role_definition_must_match_reviewed_single_data_action(self):
        role = {
            "name": setup.FOUNDRY_AGENT_CONSUMER_ROLE_ID,
            "roleName": setup.FOUNDRY_AGENT_CONSUMER_ROLE_NAME,
            "roleType": "BuiltInRole",
            "permissions": [
                {
                    "actions": [],
                    "notActions": [],
                    "dataActions": [setup.FOUNDRY_AGENT_INTERACT_DATA_ACTION],
                    "notDataActions": [],
                }
            ],
        }

        setup.validate_foundry_agent_consumer_role(role)

        role["permissions"][0]["dataActions"].append(
            "Microsoft.CognitiveServices/accounts/AIServices/*"
        )
        with self.assertRaisesRegex(RuntimeError, "least-privilege"):
            setup.validate_foundry_agent_consumer_role(role)

    @patch.object(setup, "_run_az")
    def test_role_assignment_targets_only_frontend_at_agent_scope(self, run_az):
        role = {
            "name": setup.FOUNDRY_AGENT_CONSUMER_ROLE_ID,
            "roleName": setup.FOUNDRY_AGENT_CONSUMER_ROLE_NAME,
            "roleType": "BuiltInRole",
            "permissions": [
                {
                    "actions": [],
                    "notActions": [],
                    "dataActions": [setup.FOUNDRY_AGENT_INTERACT_DATA_ACTION],
                    "notDataActions": [],
                }
            ],
        }
        assignment = [
            {
                "roleDefinitionId": (
                    "/subscriptions/sub/providers/Microsoft.Authorization/"
                    "roleDefinitions/"
                    f"{setup.FOUNDRY_AGENT_CONSUMER_ROLE_ID}"
                ),
                "scope": (
                    "/subscriptions/sub/resourceGroups/rg/providers/"
                    "Microsoft.CognitiveServices/accounts/aif/projects/project/"
                    "agents/gpt-rag-orchestrator"
                ),
                "principalId": "frontend-principal",
                "principalType": "ServicePrincipal",
            }
        ]
        run_az.side_effect = [
            json.dumps([role]),
            "[]",
            "[]",
            "",
            json.dumps(assignment),
        ]
        scope = (
            "/subscriptions/sub/resourceGroups/rg/providers/"
            "Microsoft.CognitiveServices/accounts/aif/projects/project/"
            "agents/gpt-rag-orchestrator"
        )

        created = setup.ensure_frontend_agent_consumer_assignment(
            "frontend-principal",
            scope,
            hosted_agent_principal_id="hosted-principal",
        )

        self.assertTrue(created)
        create_call = run_az.call_args_list[3]
        arguments = create_call.args[0]
        self.assertIn("frontend-principal", arguments)
        self.assertNotIn("hosted-principal", arguments)
        self.assertEqual(arguments[arguments.index("--scope") + 1], scope)
        self.assertEqual(
            arguments[arguments.index("--role") + 1],
            setup.FOUNDRY_AGENT_CONSUMER_ROLE_ID,
        )

    @patch.object(setup, "_role_assignments")
    @patch.object(setup, "verify_live_foundry_agent_consumer_role")
    def test_hosted_container_with_conversation_role_fails_closed(
        self,
        verify_role,
        role_assignments,
    ):
        role_assignments.return_value = [
            {
                "roleDefinitionId": (
                    "/subscriptions/sub/providers/Microsoft.Authorization/"
                    "roleDefinitions/"
                    f"{setup.FOUNDRY_AGENT_CONSUMER_ROLE_ID}"
                )
            }
        ]

        with self.assertRaisesRegex(RuntimeError, "hosted container identity"):
            setup.ensure_frontend_agent_consumer_assignment(
                "frontend-principal",
                (
                    "/subscriptions/sub/resourceGroups/rg/providers/"
                    "Microsoft.CognitiveServices/accounts/aif/projects/project/"
                    "agents/gpt-rag-orchestrator"
                ),
                hosted_agent_principal_id="hosted-principal",
            )

        verify_role.assert_called_once()

    def test_no_panel_composition_has_no_cosmos_or_hosted_container_rbac(self):
        parameters = json.loads(
            (REPO_ROOT / "main.parameters.json").read_text(encoding="utf-8")
        )["parameters"]
        hosted_agent = parameters["hostedAgent"]["value"]
        self.assertNotIn("roles", hosted_agent)
        self.assertNotIn("principalId", hosted_agent)

        post_provision = (
            REPO_ROOT / "scripts" / "postProvision.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("config.continuity.setup", post_provision)
        self.assertNotIn(
            "HOSTED_CONVERSATION_CAPABILITY_KEY=",
            post_provision,
        )

    def test_capability_contract_checksum_and_canonical_framing(self):
        schema_path = (
            REPO_ROOT
            / "contracts"
            / "hosted-conversation-capability-v1.schema.json"
        )
        checksum_path = (
            REPO_ROOT
            / "contracts"
            / "hosted-conversation-capability-v1.sha256"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        checksum = checksum_path.read_text(encoding="utf-8").split()[0]

        self.assertEqual(
            hashlib.sha256(
                schema_path.read_bytes().replace(b"\r\n", b"\n")
            ).hexdigest(),
            checksum,
        )
        self.assertEqual(schema["properties"]["schema_version"]["const"], 1)
        self.assertEqual(
            schema["x-canonical-framing"]["field_order"],
            [
                "schema_version",
                "oid",
                "conversation_resource_id",
                "issued_at",
                "expiry",
                "key_id",
            ],
        )
        self.assertNotIn("secret", schema["required"])
        self.assertNotIn("key", schema["required"])

    def test_hooks_keep_powershell_and_shell_continuity_parity(self):
        powershell_script = (REPO_ROOT / "scripts" / "postProvision.ps1").read_text(
            encoding="utf-8"
        )
        shell_script = (REPO_ROOT / "scripts" / "postProvision.sh").read_text(
            encoding="utf-8"
        )

        self.assertEqual(
            powershell_script.count(
                "Invoke-PythonModule -ModuleName 'config.continuity.setup'"
            ),
            1,
        )
        self.assertEqual(shell_script.count("python -m config.continuity.setup"), 1)

        powershell_predeploy = (
            REPO_ROOT / "scripts" / "preDeploy.ps1"
        ).read_text(encoding="utf-8")
        shell_predeploy = (REPO_ROOT / "scripts" / "preDeploy.sh").read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            powershell_predeploy.count(
                "sys.argv = ['config.continuity.setup', '--activate']"
            ),
            1,
        )
        self.assertEqual(
            shell_predeploy.count(
                "-m config.continuity.setup --activate"
            ),
            1,
        )
