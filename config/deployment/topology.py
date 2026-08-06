"""Resolve and materialize the GPT-RAG deployment topology (ADR-0001 rev. 5).

This is the single shared CLI/integration point used by both
``scripts/preProvision`` implementations (PowerShell and POSIX shell) so the
fresh-vs-existing default/sticky/conflict decision is made in exactly one
place -- see ``config.deployment.composition.resolve_topology`` for the pure
resolution logic. ``preProvision`` calls this module without ``--describe``
to resolve the topology (performing the Azure CLI lookups needed to detect a
fresh vs. existing environment) and materializes the result into the azd
environment. ``preDeploy`` and ``postProvision`` then call this module with
``--describe`` to read back the already-materialized topology, purely from
the environment, with no further Azure CLI lookups -- avoiding any
duplicated detection logic across hooks.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Mapping

from config.deployment.composition import (
    APP_CONFIG_LABEL,
    DeploymentMode,
    DeploymentTopologyError,
    HOSTED_CUTOVER_COMPLETE,
    PRESERVE_CLASSIC_RUNTIME,
    describe_mode,
    hosted_cutover_ready,
    is_truthy,
    materialized_settings,
    resolve_explicit_topology,
    resolve_mode,
    resolve_runtime_mode,
    resolve_topology,
    validate_hosted_prerequisites,
)
from util.azure_cli import resolve_az_command

_PERSISTED_KEYS = (
    "DEPLOYMENT_TOPOLOGY",
    "DEPLOY_HOSTED_AGENT_ORCHESTRATION",
    "DEPLOY_ADMINISTRATIVE_PANEL",
    "CHAT_BACKEND",
)


@dataclass(frozen=True)
class TopologyResolution:
    mode: DeploymentMode
    preserve_classic_runtime: bool = False


def _local_migration_state(
    environment: Mapping[str, str],
    mode: DeploymentMode,
) -> bool | None:
    """Classify explicit hosted migration without private data-plane I/O."""
    raw_preserve = environment.get(PRESERVE_CLASSIC_RUNTIME)
    if raw_preserve is None:
        backend = (environment.get("CHAT_BACKEND") or "").strip().lower()
        if backend == "hosted_agent" or hosted_cutover_ready(environment):
            return False
        # Existing environments without a hosted marker are pre-cutover
        # classic by ADR-0001. Preserve them without requiring access to a
        # private App Configuration endpoint from the provisioning client.
        return mode is not DeploymentMode.CLASSIC
    normalized_preserve = raw_preserve.strip().lower()
    if normalized_preserve not in {"true", "false"}:
        raise DeploymentTopologyError(
            f"{PRESERVE_CLASSIC_RUNTIME} must be 'true' or 'false'."
        )
    if is_truthy(normalized_preserve):
        return resolve_runtime_mode(mode, environment) is DeploymentMode.CLASSIC

    backend = (environment.get("CHAT_BACKEND") or "").strip().lower()
    if backend == "orchestrator":
        return mode is not DeploymentMode.CLASSIC
    if backend == "hosted_agent":
        return False
    return None


def _run_az(arguments: list[str]) -> tuple[int, str, str]:
    completed = subprocess.run(
        [resolve_az_command(), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode, completed.stdout.strip(), completed.stderr.strip()


def resource_group_exists(
    name: str | None,
    subscription_id: str | None = None,
) -> bool:
    """Return ``True`` only when ``name`` is non-empty and Azure confirms it exists.

    A genuinely fresh azd environment has no resource-group name at all yet
    (Bicep has not run), so this short-circuits to ``False`` without any
    Azure CLI call in that case.
    """
    name = (name or "").strip()
    if not name:
        return False
    arguments = ["group", "exists", "--name", name, "--output", "tsv"]
    if (subscription_id or "").strip():
        arguments.extend(["--subscription", subscription_id.strip()])
    returncode, stdout, stderr = _run_az(arguments)
    if returncode != 0:
        raise DeploymentTopologyError(
            "Unable to determine whether the Azure resource group exists; "
            f"topology selection cannot safely continue: {stderr or stdout}"
        )
    normalized = stdout.strip().lower()
    if normalized not in {"true", "false"}:
        raise DeploymentTopologyError(
            "Azure CLI returned an unexpected resource-group existence result: "
            f"{stdout!r}."
        )
    return normalized == "true"


def read_persisted_settings(endpoint: str | None) -> dict[str, str]:
    """Read persisted GPT-RAG topology markers, failing closed on access errors.

    A missing endpoint means the environment predates the App Configuration
    output and is handled as unmarked/classic. Once an endpoint is known,
    lookup or parse failures are fatal so an existing hosted environment is
    never mistaken for an unmarked classic environment.
    """
    endpoint = (endpoint or "").strip()
    settings: dict[str, str] = {}
    if not endpoint:
        return settings
    returncode, stdout, stderr = _run_az(
        [
            "appconfig",
            "kv",
            "list",
            "--endpoint",
            endpoint,
            "--label",
            APP_CONFIG_LABEL,
            "--fields",
            "key",
            "value",
            "--output",
            "json",
            "--auth-mode",
            "login",
        ]
    )
    if returncode != 0:
        raise DeploymentTopologyError(
            "Unable to read the existing deployment topology from App "
            f"Configuration; topology selection cannot safely continue: "
            f"{stderr or stdout}"
        )
    try:
        values = json.loads(stdout or "[]")
    except json.JSONDecodeError as exc:
        raise DeploymentTopologyError(
            "App Configuration returned invalid JSON while reading the existing "
            "deployment topology."
        ) from exc
    for item in values:
        key = item.get("key")
        value = item.get("value")
        if key in _PERSISTED_KEYS and value is not None:
            settings[key] = str(value)
    return settings


def resolve_environment_topology_context(
    environment: Mapping[str, str],
    *,
    resource_group_name: str | None = None,
    subscription_id: str | None = None,
    app_config_endpoint: str | None = None,
) -> tuple[DeploymentMode, bool]:
    """I/O-aware wrapper around ``resolve_topology`` for use at preProvision time.

    Detects whether the environment is fresh (no resource group yet) or
    existing, reads any persisted topology markers for existing
    environments, and delegates the actual decision to the pure
    ``resolve_topology`` function. An explicit classic signal wins without
    lookups. An explicit hosted signal classifies the existing persisted
    topology so a classic-to-hosted migration keeps the classic runtime
    active until the hosted endpoint has been deployed and published.
    """
    explicit = resolve_explicit_topology(environment)
    if explicit is not None:
        if explicit is DeploymentMode.CLASSIC:
            return explicit, False
        if is_truthy(environment.get("HOSTED_AGENT_MIGRATION")):
            return explicit, True
        rg_exists = resource_group_exists(resource_group_name, subscription_id)
        if not rg_exists:
            return explicit, False
        persisted = read_persisted_settings(app_config_endpoint)
        previous_mode = resolve_topology(
            {},
            resource_group_exists=True,
            persisted_settings=persisted,
        )
        return explicit, previous_mode is DeploymentMode.CLASSIC

    rg_exists = resource_group_exists(resource_group_name, subscription_id)
    persisted = read_persisted_settings(app_config_endpoint) if rg_exists else {}
    return (
        resolve_topology(
            environment,
            resource_group_exists=rg_exists,
            persisted_settings=persisted,
        ),
        False,
    )


def resolve_environment_topology(
    environment: Mapping[str, str],
    *,
    resource_group_name: str | None = None,
    subscription_id: str | None = None,
    app_config_endpoint: str | None = None,
) -> DeploymentMode:
    return resolve_environment_plan(
        environment,
        resource_group_name=resource_group_name,
        subscription_id=subscription_id,
        app_config_endpoint=app_config_endpoint,
    ).mode


def resolve_environment_plan(
    environment: Mapping[str, str],
    *,
    resource_group_name: str | None = None,
    subscription_id: str | None = None,
    app_config_endpoint: str | None = None,
) -> TopologyResolution:
    """I/O-aware wrapper around ``resolve_topology`` for use at preProvision time.

    Detects whether the environment is fresh (no resource group yet) or
    existing, reads any persisted topology markers for existing
    environments, and delegates the actual decision to the pure
    ``resolve_topology`` function. Explicit classic remains a direct rollback.
    Explicit hosted additionally classifies the current deployed runtime so a
    classic-to-hosted migration can retain classic during its prepare-only
    phase without changing the fresh-hosted fail-closed contract.
    """
    explicit = resolve_explicit_topology(environment)
    if explicit is DeploymentMode.CLASSIC:
        return TopologyResolution(explicit)

    rg_exists = resource_group_exists(resource_group_name, subscription_id)
    materialized_preservation = (
        _local_migration_state(environment, explicit)
        if explicit is not None and rg_exists
        else None
    )
    if materialized_preservation is not None:
        return TopologyResolution(explicit, materialized_preservation)

    persisted = read_persisted_settings(app_config_endpoint) if rg_exists else {}
    mode = resolve_topology(
        environment,
        resource_group_name=resource_group_name,
        subscription_id=subscription_id,
        app_config_endpoint=app_config_endpoint,
    )
    preserve_classic_runtime = False
    if explicit is not None and rg_exists:
        current_mode = resolve_topology(
            {},
            resource_group_exists=True,
            persisted_settings=persisted,
        )
        preserve_classic_runtime = current_mode is DeploymentMode.CLASSIC
    return TopologyResolution(mode, preserve_classic_runtime)


def _print_materialized(resolution: TopologyResolution) -> None:
    runtime_environment = dict(os.environ)
    runtime_environment[PRESERVE_CLASSIC_RUNTIME] = str(
        resolution.preserve_classic_runtime
    ).lower()
    for key, value in materialized_settings(
        resolution.mode,
        preserve_classic_runtime=resolution.preserve_classic_runtime,
        runtime_mode=resolve_runtime_mode(
            resolution.mode,
            runtime_environment,
        ),
        hosted_cutover_complete=is_truthy(
            os.environ.get(HOSTED_CUTOVER_COMPLETE)
        )
        and not resolution.preserve_classic_runtime,
    ).items():
        print(f"{key}={value}")


def _print_description(mode: DeploymentMode) -> None:
    preserve_classic_runtime = (
        os.environ.get(PRESERVE_CLASSIC_RUNTIME, "").lower() == "true"
    )
    print(
        json.dumps(
            describe_mode(
                mode,
                preserve_classic_runtime=preserve_classic_runtime,
                runtime_mode=resolve_runtime_mode(mode, os.environ),
            )
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve the GPT-RAG deployment topology (ADR-0001 revision 5)."
        )
    )
    parser.add_argument(
        "--describe",
        action="store_true",
        help=(
            "Do not perform any Azure CLI lookups; instead describe, as "
            "JSON, the topology already resolved into the current "
            "environment (DEPLOYMENT_TOPOLOGY / legacy flags). Intended for "
            "preDeploy/postProvision, which run after preProvision has "
            "already materialized the topology into the azd environment."
        ),
    )
    parser.add_argument(
        "--validate-hosted-deploy",
        action="store_true",
        help=(
            "Describe the already-materialized topology and, when hosted is "
            "selected, fail unless the immutable image, delegated scope, and "
            "provisioned Foundry project prerequisites are present."
        ),
    )
    parser.add_argument(
        "--validate-hosted-context",
        action="store_true",
        help=(
            "Describe the already-materialized topology and validate hosted "
            "scope and provisioned Foundry project settings without requiring "
            "an image digest. Used immediately before automatic image "
            "preparation."
        ),
    )
    parser.add_argument(
        "--resource-group-name",
        default=None,
        help=(
            "Resource group name to check for existence. Defaults to "
            "AZURE_RESOURCE_GROUP from the environment."
        ),
    )
    parser.add_argument(
        "--app-config-endpoint",
        default=None,
        help=(
            "App Configuration endpoint to read persisted settings from. "
            "Defaults to APP_CONFIG_ENDPOINT from the environment."
        ),
    )
    parser.add_argument(
        "--subscription-id",
        default=None,
        help=(
            "Subscription containing the resource group. Defaults to "
            "AZURE_SUBSCRIPTION_ID from the environment."
        ),
    )
    args = parser.parse_args()

    try:
        if (
            args.describe
            or args.validate_hosted_deploy
            or args.validate_hosted_context
        ):
            mode = resolve_mode(os.environ)
            if (
                args.validate_hosted_deploy or args.validate_hosted_context
            ) and mode is not DeploymentMode.CLASSIC:
                validate_hosted_prerequisites(
                    os.environ,
                    require_image_digest=not args.validate_hosted_context,
                    require_foundry_project=True,
                )
            _print_description(mode)
        else:
            resource_group_name = args.resource_group_name or os.environ.get(
                "AZURE_RESOURCE_GROUP"
            )
            app_config_endpoint = args.app_config_endpoint or os.environ.get(
                "APP_CONFIG_ENDPOINT"
            )
            subscription_id = args.subscription_id or os.environ.get(
                "AZURE_SUBSCRIPTION_ID"
            )
            resolution = resolve_environment_plan(
                os.environ,
                resource_group_name=resource_group_name,
                subscription_id=subscription_id,
                app_config_endpoint=app_config_endpoint,
            )
            _print_materialized(resolution)
    except DeploymentTopologyError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
