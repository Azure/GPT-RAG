"""Optional real Azure CLI parser regression; no validators/handlers/network.

Run with the already-installed Azure CLI Python interpreter and this repository
on sys.path. The ordinary dependency-free test environment may skip this suite;
do not install Azure CLI packages just to run it.
"""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import os
import socket
import tempfile
import unittest
from unittest.mock import patch

from tests.test_hosted_access import ACCOUNT, ENV, AzureFixture
from config.deployment import hosted_access as access


class _ParsedOnly(BaseException):
    """Escape CLI error handling immediately after argument parsing."""


class HostedAccessCliParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            available = importlib.util.find_spec("azure.cli.core") is not None
        except ModuleNotFoundError:
            available = False
        if not available:
            raise unittest.SkipTest("Run with the existing Azure CLI Python for parser-only validation.")
        directory = cls.enterClassContext(tempfile.TemporaryDirectory(prefix="hosted-cli-parser-"))
        cls.enterClassContext(patch.dict(os.environ, {
            "AZURE_CONFIG_DIR": directory,
            "AZURE_CORE_COLLECT_TELEMETRY": "false",
        }))
        for owner, name in (
            (socket.socket, "connect"), (socket.socket, "connect_ex"),
            (socket, "create_connection"), (socket, "getaddrinfo"),
        ):
            cls.enterClassContext(patch.object(owner, name, side_effect=AssertionError("Network forbidden in CLI parser tests")))

        from azure.cli.core import AzCli, MainCommandsLoader
        from azure.cli.core.commands import AzCliCommandInvoker
        from azure.cli.core.parser import AzCliCommandParser
        from azure.cli.core._help import AzCliHelp
        from knack.events import EVENT_INVOKER_POST_PARSE_ARGS

        # Independent defense: not even a local SDK command job may run.
        cls.enterClassContext(patch.object(
            AzCliCommandInvoker, "_run_job",
            side_effect=AssertionError("Command execution forbidden in parser tests"),
        ))
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            cls.cli = AzCli(
                cli_name="az", config_dir=directory, config_env_var_prefix="AZURE",
                commands_loader_cls=MainCommandsLoader, invocation_cls=AzCliCommandInvoker,
                parser_cls=AzCliCommandParser, help_cls=AzCliHelp,
            )

        def stop_after_parse(cli_ctx, **kwargs):
            raise _ParsedOnly()

        cls.cli.register_event(EVENT_INVOKER_POST_PARSE_ARGS, stop_after_parse)

    def parse_only(self, arguments):
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            try:
                self.cli.invoke(arguments + ["--output", "json", "--only-show-errors"])
            except _ParsedOnly:
                return True
        return False

    def test_old_ids_only_account_command_is_rejected(self):
        self.assertFalse(self.parse_only(["cognitiveservices", "account", "show", "--ids", ACCOUNT]))

    def test_generated_raw_arm_and_named_resource_reads_parse_with_installed_cli(self):
        azure = AzureFixture()
        access.discover(ENV, run=azure)
        commands = [
            command for command in azure.calls
            if command[:3] == ["rest", "--method", "get"]
            or command[:2] in (["appconfig", "show"], ["keyvault", "show"], ["resource", "show"])
        ]
        self.assertEqual(5, len(commands))
        for command in commands:
            with self.subTest(operation=command[:2]):
                self.assertTrue(self.parse_only(command))


class HostedAccessCliSerializationTests(unittest.TestCase):
    def test_appconfig_reference_uses_real_cli_json_shape(self):
        try:
            available = importlib.util.find_spec("azure.cli.core") is not None
        except ModuleNotFoundError:
            available = False
        if not available:
            self.skipTest("Run with the existing Azure CLI Python for serialization validation.")

        from azure.cli.core import AzCli, MainCommandsLoader
        from azure.cli.core.commands import AzCliCommandInvoker
        from azure.cli.core.parser import AzCliCommandParser
        from azure.cli.core._help import AzCliHelp
        from azure.cli.command_modules.appconfig import keyvalue
        from azure.cli.command_modules.appconfig._models import KeyValue

        azure = AzureFixture()
        reference = azure.settings["AUDIT_HMAC_KEY"]
        sample = KeyValue(
            key=reference["key"], label=reference["label"],
            content_type=reference["contentType"], value=reference["value"],
        )
        output, errors = io.StringIO(), io.StringIO()
        with tempfile.TemporaryDirectory(prefix="hosted-cli-json-") as directory:
            with patch.dict(os.environ, {
                "AZURE_CONFIG_DIR": directory, "AZURE_CORE_COLLECT_TELEMETRY": "false",
            }), patch.object(socket.socket, "connect", side_effect=AssertionError("Network forbidden")), \
                    patch.object(socket, "create_connection", side_effect=AssertionError("Network forbidden")), \
                    patch.object(socket, "getaddrinfo", side_effect=AssertionError("Network forbidden")), \
                    patch.object(keyvalue, "list_key", autospec=True, return_value=[sample]) as handler, \
                    redirect_stdout(io.StringIO()), redirect_stderr(errors):
                cli = AzCli(
                    cli_name="az", config_dir=directory, config_env_var_prefix="AZURE",
                    commands_loader_cls=MainCommandsLoader, invocation_cls=AzCliCommandInvoker,
                    parser_cls=AzCliCommandParser, help_cls=AzCliHelp,
                )
                code = cli.invoke([
                    "appconfig", "kv", "list", "--endpoint", ENV["APP_CONFIG_ENDPOINT"],
                    "--auth-mode", "login", "--key", "AUDIT_HMAC_KEY",
                    "--label", "gpt-rag", "--output", "json",
                ], out_file=output)
        self.assertEqual(0, code)
        handler.assert_called_once()
        row = json.loads(output.getvalue())[0]
        self.assertEqual(reference["contentType"], row["contentType"])
        self.assertNotIn("content_type", row)
        azure.settings["AUDIT_HMAC_KEY"] = row
        plan = access.discover(ENV, run=azure)
        self.assertEqual("configured", plan.audit)
        self.assertEqual(3, len(plan.grants))
        self.assertFalse(azure.writes)


if __name__ == "__main__":
    unittest.main()
