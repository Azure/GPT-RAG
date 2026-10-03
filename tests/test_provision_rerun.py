"""T097: idempotent re-run and partial-failure recovery (FR-016)."""

from __future__ import annotations

import json
from unittest import mock

import pytest

from config.deployment import outputs
from config.deployment.existing_images import PLACEHOLDER_IMAGE, placeholder_plan

COMPONENTS = [
    {"name": "ui", "kind": "containerapp"},
    {"name": "orchestrator", "kind": "azure.ai.agent"},
    {"name": "ingestion", "kind": "containerapp"},
]
ENVIRONMENT = {
    "AZURE_RESOURCE_GROUP": "rg-test",
    "AZURE_AI_PROJECT_ENDPOINT": "https://aif.services.ai.azure.com/api/projects/p1",
    "AI_FOUNDRY_ACCOUNT_NAME": "aif-test",
    "AZURE_CONTAINER_REGISTRY_ENDPOINT": "crtest.azurecr.io",
    "APP_CONFIG_ENDPOINT": "https://appcs-test.azconfig.io",
    "STORAGE_BLOB_ENDPOINT": "https://sttest.blob.core.windows.net/",
    "KEY_VAULT_URI": "https://kv-test.vault.azure.net/",
    "NETWORK_ISOLATION": "false",
}


class FakeAppConfig:
    """In-memory App Configuration keyed by (key, label); ``kv set`` upserts."""

    def __init__(self, fail_on_call: int | None = None) -> None:
        self.store: dict[tuple[str, str], str] = {}
        self.calls = 0
        self.fail_on_call = fail_on_call

    def run_az(self, args: list[str], required: bool = True) -> str:
        self.calls += 1
        if self.fail_on_call == self.calls:
            raise RuntimeError("Azure CLI command failed: simulated throttling")
        assert args[:3] == ["appconfig", "kv", "set"]
        key = args[args.index("--key") + 1]
        label = args[args.index("--label") + 1]
        self.store[(key, label)] = args[args.index("--value") + 1]
        return ""


def _provision(fake: FakeAppConfig) -> None:
    document = outputs.build_platform_outputs(ENVIRONMENT, {"ui": "11111111-2222-3333-4444-555555555555"})
    outputs.validate_platform_outputs(document)
    with mock.patch("config.deployment.appconfig._run_az", side_effect=fake.run_az):
        outputs.publish(ENVIRONMENT["APP_CONFIG_ENDPOINT"], outputs.platform_settings(document))


def test_second_provision_creates_no_duplicates_and_no_errors():
    fake = FakeAppConfig()
    _provision(fake)
    first = dict(fake.store)
    _provision(fake)
    assert fake.store == first
    assert {label for _, label in fake.store} == {"agent-lz"}
    assert json.loads(fake.store[("AGENTLZ_PLATFORM_OUTPUTS", "agent-lz")])["schemaVersion"] == 1


def test_rerun_after_partial_failure_converges():
    fake = FakeAppConfig(fail_on_call=3)
    with pytest.raises(RuntimeError, match="simulated"):
        _provision(fake)
    assert 0 < len(fake.store) < 3
    fake.fail_on_call = None
    _provision(fake)
    reference = FakeAppConfig()
    _provision(reference)
    assert fake.store == reference.store


def test_placeholder_plan_is_stable_across_reruns():
    first = placeholder_plan(COMPONENTS, {})
    deployed = {"ui": "cr.azurecr.io/agent-app-ui:2"}
    second = placeholder_plan(COMPONENTS, deployed)
    third = placeholder_plan(COMPONENTS, deployed)
    assert set(first) == set(second) == {"ui", "ingestion"}
    assert second == third == {"ui": "cr.azurecr.io/agent-app-ui:2", "ingestion": PLACEHOLDER_IMAGE}
