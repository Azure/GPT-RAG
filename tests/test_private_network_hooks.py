"""Execute lifecycle hooks with fake CLIs; never call Azure or live networking."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PWSH = shutil.which("pwsh")
BASH = shutil.which("bash")
VALUES = """NETWORK_ISOLATION="true"
DEPLOYMENT_TOPOLOGY="classic"
APP_CONFIG_ENDPOINT="https://config.azconfig.io"
AZURE_RESOURCE_GROUP="test-group"
AZURE_SUBSCRIPTION_ID="test-subscription"
AZURE_LOCATION="westus3"
RESOURCE_TOKEN="test"
"""
TOPOLOGY = '{"deploy_hosted_agent_orchestration":false,"deploy_administrative_panel":false,"topology":"classic","components":["gpt-rag-ui","gpt-rag-orchestrator","gpt-rag-ingestion"]}'

# Only the DNS/TLS boundary is replaced for the integrated flag/endpoint cases.
PROBE_DRIVER = r"""
import os, sys
sys.path.insert(0, os.environ["REAL_REPO"])
from config.deployment import private_network as network

def probe(key, endpoint):
    with open(os.environ["FAKE_TRACE"], "a", encoding="utf-8") as stream:
        stream.write("endpoint:" + key + "\n")
    if os.environ.get("FAKE_ENDPOINT_FAIL") == "1":
        raise network.PrivateNetworkError("offline unreachable fixture")

network.check_endpoint = probe
raise SystemExit(network.main(["--stage", sys.argv[1]]))
"""

PS_WRAPPER = r"""
function azd {
    if ($env:FAKE_AZD_FAIL -eq '1') { $global:LASTEXITCODE = 1; return }
    if (Test-Path (Join-Path $env:FAKE_ROOT 'env-read')) {
        throw 'Unexpected repeated environment read before deployment'
    }
    New-Item -ItemType File -Path (Join-Path $env:FAKE_ROOT 'env-read') | Out-Null
    Get-Content -LiteralPath (Join-Path $env:FAKE_ROOT 'values.txt')
    $global:LASTEXITCODE = [int]$env:FAKE_AZD_EXIT
}
function git { $global:LASTEXITCODE = 0 }
function docker { $global:LASTEXITCODE = 0 }
function python {
    $call = $args -join ' '
    if ($call -match 'config.deployment.private_network') {
        Add-Content -LiteralPath $env:FAKE_TRACE -Value 'probe'
        if ($env:FAKE_REAL_PROBE -eq '1') {
            $stage = if ($call -match 'post-provision') { 'post-provision' } else { 'pre-deploy' }
            & $env:REAL_PYTHON (Join-Path $env:FAKE_ROOT 'probe.py') $stage
            return
        }
        if ($env:NETWORK_ISOLATION -ne 'true' -or $env:APP_CONFIG_ENDPOINT -ne 'https://config.azconfig.io') {
            throw 'The selected environment was not mirrored correctly'
        }
        $global:LASTEXITCODE = [int]$env:FAKE_PROBE_EXIT
        return
    }
    if ($call -match 'config.deployment.topology') {
        Get-Content -LiteralPath (Join-Path $env:FAKE_ROOT 'topology.json')
        $global:LASTEXITCODE = 0
        return
    }
    throw "Unexpected Python operation in hook test: $call"
}
function az {
    Add-Content -LiteralPath $env:FAKE_TRACE -Value 'azure-boundary'
    exit 93
}
& (Join-Path $env:FAKE_ROOT "scripts/$($env:FAKE_HOOK).ps1")
exit $LASTEXITCODE
"""

SH_CLIS = {
    "azd": """#!/usr/bin/env bash
[ "${FAKE_AZD_FAIL:-0}" = 1 ] && exit 1
[ -f "$FAKE_ROOT/env-read" ] && { echo unexpected-env-read >> "$FAKE_TRACE"; exit 95; }
touch "$FAKE_ROOT/env-read"
cat "$FAKE_ROOT/values.txt"
exit "$FAKE_AZD_EXIT"
""",
    "python3": """#!/usr/bin/env bash
case "$*" in
  *config.deployment.private_network*)
    echo probe >> "$FAKE_TRACE"
    if [ "$FAKE_REAL_PROBE" = 1 ]; then
      exec "$REAL_PYTHON" "$FAKE_ROOT/probe.py" "$4"
    fi
    [ "$NETWORK_ISOLATION" = true ] && [ "$APP_CONFIG_ENDPOINT" = https://config.azconfig.io ] || exit 96
    exit "$FAKE_PROBE_EXIT" ;;
  *config.deployment.topology*) cat "$FAKE_ROOT/topology.json"; exit 0 ;;
  *config.deployment.appconfig*) echo azure-boundary >> "$FAKE_TRACE"; exit 93 ;;
  *) echo "Unexpected Python operation" >&2; exit 94 ;;
esac
""",
    "az": """#!/usr/bin/env bash
echo azure-boundary >> "$FAKE_TRACE"
exit 93
""",
    "git": "#!/usr/bin/env bash\nexit 0\n",
    "docker": "#!/usr/bin/env bash\nexit 0\n",
    "jq": """#!/usr/bin/env bash
case "$*" in
  *deploy_hosted_agent_orchestration*|*deploy_administrative_panel*) echo false ;;
  *'.topology'*) echo classic ;;
  *'.components'*) echo 'gpt-rag-ui gpt-rag-orchestrator gpt-rag-ingestion' ;;
  *) exit 94 ;;
esac
""",
}


class HookExecutionTests(unittest.TestCase):
    def run_hook(
        self, shell: str, hook: str, probe_exit: int, *, env_fail: bool = False,
        values: str = VALUES, azd_exit: int = 0, real_probe: bool = False,
        endpoint_fail: bool = False, process_env: dict[str, str] | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], list[str]]:
        with tempfile.TemporaryDirectory(prefix="gptrag-hook-test-") as directory:
            root = Path(directory) / "gpt-rag"
            scripts = root / "scripts"
            scripts.mkdir(parents=True)
            suffix = "ps1" if shell == "powershell" else "sh"
            shutil.copyfile(ROOT / "scripts" / f"{hook}.{suffix}", scripts / f"{hook}.{suffix}")
            (root / "manifest.json").write_text("{}", encoding="utf-8")
            (root / "values.txt").write_text(values, encoding="utf-8")
            (root / "topology.json").write_text(TOPOLOGY, encoding="utf-8")
            (root / "probe.py").write_text(PROBE_DRIVER, encoding="utf-8")
            trace = root / "trace.txt"
            env = dict(os.environ)
            env.update({
                "FAKE_ROOT": str(root), "FAKE_TRACE": str(trace), "FAKE_HOOK": hook,
                "FAKE_PROBE_EXIT": str(probe_exit), "FAKE_AZD_FAIL": "1" if env_fail else "0",
                "RUN_FROM_JUMPBOX": "", "AZURE_SKIP_NETWORK_ISOLATION_WARNING": "",
                "PYTHONPATH": "", "USE_CAPP_API_KEY": "", "FOUNDRY_IQ_MCP_ENABLED": "",
                "REAL_PYTHON": sys.executable, "REAL_REPO": str(ROOT),
                "FAKE_REAL_PROBE": "1" if real_probe else "0",
                "FAKE_ENDPOINT_FAIL": "1" if endpoint_fail else "0",
                "FAKE_AZD_EXIT": str(azd_exit),
            })
            env.update(process_env or {})
            if shell == "powershell":
                assert PWSH is not None
                wrapper = root / "run.ps1"
                wrapper.write_text(PS_WRAPPER, encoding="utf-8")
                command = [PWSH, "-NoProfile", "-NonInteractive", "-File", str(wrapper)]
            else:
                assert BASH is not None
                fake_bin = root / ".fake-bin"
                fake_bin.mkdir()
                for name, content in SH_CLIS.items():
                    file = fake_bin / name
                    file.write_text(content, encoding="utf-8", newline="\n")
                    file.chmod(0o755)
                command = [BASH, "-c",
                           'export FAKE_ROOT="$PWD" FAKE_TRACE="$PWD/trace.txt"; '
                           'export PATH="$PWD/.fake-bin:$PATH"; '
                           f'exec bash "scripts/{hook}.sh"']
            result = subprocess.run(
                command, cwd=root, env=env, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=30, check=False,
            )
            events = trace.read_text(encoding="utf-8-sig").splitlines() if trace.exists() else []
            return result, events

    def check_cases(self, shell: str) -> None:
        for hook in ("postProvision", "preDeploy"):
            for probe_exit in (4, 7, 0):
                with self.subTest(shell=shell, hook=hook, probe_exit=probe_exit):
                    result, events = self.run_hook(shell, hook, probe_exit)
                    output = result.stdout + result.stderr
                    self.assertIn("probe", events, output)
                    if probe_exit:
                        self.assertEqual(probe_exit, result.returncode, output)
                        self.assertNotIn("azure-boundary", events, output)
                    else:
                        self.assertIn("azure-boundary", events, output)
                        self.assertLess(events.index("probe"), events.index("azure-boundary"))
            with self.subTest(shell=shell, hook=hook, env_fail=True):
                result, events = self.run_hook(shell, hook, 0, env_fail=True)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertEqual([], events, result.stdout + result.stderr)
            for values, azd_exit in (
                ("", 0), (" \n", 0), ("INVALID OUTPUT", 0),
                (VALUES + "MALFORMED\n", 0), (VALUES, 7),
            ):
                with self.subTest(shell=shell, hook=hook, values=values, azd_exit=azd_exit):
                    result, events = self.run_hook(
                        shell, hook, 0, values=values, azd_exit=azd_exit,
                    )
                    self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
                    self.assertEqual([], events, result.stdout + result.stderr)
        result, events = self.run_hook(shell, "postProvision", 20)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(["probe"], events)
        self.assertIn("incomplete", result.stdout)
        result, events = self.run_hook(shell, "preDeploy", 20)
        self.assertEqual(20, result.returncode, result.stdout + result.stderr)
        self.assertEqual(["probe"], events)

    def integrated_cases(self, shell: str) -> None:
        for hook in ("postProvision", "preDeploy"):
            for extra, process, endpoint_fail, expected in (
                ("", {}, False, "connected"),
                ("", {}, True, "failed"),
                ('RUN_FROM_JUMPBOX="false"\n', {}, False, "deferred"),
                ('AZURE_SKIP_NETWORK_ISOLATION_WARNING="true"\n', {}, False, "deferred"),
                (
                    'RUN_FROM_JUMPBOX="true"\nAZURE_SKIP_NETWORK_ISOLATION_WARNING="true"\n',
                    {}, True, "failed",
                ),
                ("", {"AZURE_SKIP_NETWORK_ISOLATION_WARNING": "true"}, False, "deferred"),
                (
                    'RUN_FROM_JUMPBOX=""\nAZURE_SKIP_NETWORK_ISOLATION_WARNING=""\n',
                    {"RUN_FROM_JUMPBOX": "false", "AZURE_SKIP_NETWORK_ISOLATION_WARNING": "true"},
                    False, "connected",
                ),
                ('NETWORK_ISOLATION="false"\nAPP_CONFIG_ENDPOINT=""\n', {}, True, "public"),
                ('APP_CONFIG_ENDPOINT=""\n', {}, False, "missing"),
            ):
                with self.subTest(shell=shell, hook=hook, extra=extra, process=process,
                                  endpoint_fail=endpoint_fail):
                    result, events = self.run_hook(
                        shell, hook, 0, values=VALUES + extra, real_probe=True,
                        endpoint_fail=endpoint_fail, process_env=process,
                    )
                    output = result.stdout + result.stderr
                    self.assertIn("probe", events, output)
                    if expected == "deferred" and hook == "postProvision":
                        self.assertEqual(0, result.returncode, output)
                        self.assertEqual(["probe"], events, output)
                        self.assertIn("incomplete", output)
                    elif expected in {"failed", "missing"}:
                        self.assertEqual(4, result.returncode, output)
                        self.assertNotIn("azure-boundary", events, output)
                    elif expected == "public":
                        self.assertNotIn("endpoint:APP_CONFIG_ENDPOINT", events, output)
                    else:
                        self.assertIn("endpoint:APP_CONFIG_ENDPOINT", events, output)
                        self.assertIn("azure-boundary", events, output)
                        self.assertLess(events.index("endpoint:APP_CONFIG_ENDPOINT"),
                                        events.index("azure-boundary"))

    @unittest.skipUnless(PWSH, "PowerShell 7 is not installed")
    def test_powershell_hooks(self) -> None:
        self.check_cases("powershell")

    @unittest.skipUnless(BASH, "bash is not installed")
    def test_shell_hooks(self) -> None:
        self.check_cases("bash")

    @unittest.skipUnless(PWSH, "PowerShell 7 is not installed")
    def test_powershell_shared_helper(self) -> None:
        self.integrated_cases("powershell")

    @unittest.skipUnless(BASH, "bash is not installed")
    def test_shell_shared_helper(self) -> None:
        self.integrated_cases("bash")


if __name__ == "__main__":
    unittest.main()
