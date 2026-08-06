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
from typing import Mapping

from config.deployment.composition import (
    APP_CONFIG_LABEL,
    DeploymentMode,
    DeploymentTopologyError,
    describe_mode,
    effective_runtime_mode,
    is_truthy,
    materialized_settings,
    resolve_explicit_topology,
    resolve_mode,
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


def resolve_environment_topology(
    environment: Mapping[str, str],
    *,
    resource_group_name: str | None = None,
    subscription_id: str | None = None,
    app_config_endpoint: str | None = None,
) -> DeploymentMode:
    """I/O-aware wrapper around ``resolve_topology`` for use at preProvision time.

    Detects whether the environment is fresh (no resource group yet) or
    existing, reads any persisted topology markers for existing
    environments, and delegates the actual decision to the pure
    ``resolve_topology`` function. An explicit signal in ``environment``
    always wins (see ``resolve_topology``), so this skips the Azure CLI
    lookups entirely in that case -- an explicit request must never depend
    on, or be delayed by, being able to reach Azure to classify the
    environment as fresh or existing.
    """
    return resolve_environment_contract(
        environment,
        resource_group_name=resource_group_name,
        subscription_id=subscription_id,
        app_config_endpoint=app_config_endpoint,
    )[0]


def resolve_environment_contract(
    environment: Mapping[str, str],
    *,
    resource_group_name: str | None = None,
    subscription_id: str | None = None,
    app_config_endpoint: str | None = None,
) -> tuple[DeploymentMode, str]:
    """Resolve target topology and the runtime backend safe to materialize."""
    explicit = resolve_explicit_topology(environment)
    current_backend = (environment.get("CHAT_BACKEND") or "").strip().lower()
    if current_backend not in {"", "orchestrator", "hosted_agent"}:
        raise DeploymentTopologyError(
            f"Unknown CHAT_BACKEND={current_backend!r}; expected 'orchestrator' "
            "or 'hosted_agent'."
        )

    if explicit is DeploymentMode.CLASSIC:
        return explicit, "orchestrator"
    if explicit is not None and current_backend == "hosted_agent":
        return explicit, current_backend
    if explicit is not None:
        rg_exists = resource_group_exists(resource_group_name, subscription_id)
        return explicit, "orchestrator" if rg_exists else "hosted_agent"

    rg_exists = resource_group_exists(resource_group_name, subscription_id)
    persisted = read_persisted_settings(app_config_endpoint) if rg_exists else {}
    mode = resolve_topology(
        environment,
        resource_group_exists=rg_exists,
        persisted_settings=persisted,
    )
    return mode, str(describe_mode(mode)["chat_backend"])


def _print_materialized(
    mode: DeploymentMode,
    *,
    environment: Mapping[str, str],
) -> None:
    settings = materialized_settings(mode)
    deploy_hosted = (
        is_truthy(environment.get("DEPLOY_HOSTED_AGENT"))
        and bool((environment.get("HOSTED_AGENT_IMAGE_VERSION") or "").strip())
    )
    runtime_mode = effective_runtime_mode(
        mode,
        environment,
        deploy_hosted=deploy_hosted,
    )
    settings["CHAT_BACKEND"] = (
        "orchestrator"
        if runtime_mode is DeploymentMode.CLASSIC
        else "hosted_agent"
    )
    for key, value in settings.items():
        print(f"{key}={value}")


def _print_description(mode: DeploymentMode) -> None:
    print(json.dumps(describe_mode(mode)))


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
            mode, runtime_backend = resolve_environment_contract(
                os.environ,
                resource_group_name=resource_group_name,
                subscription_id=subscription_id,
                app_config_endpoint=app_config_endpoint,
            )
            materialized_environment = dict(os.environ)
            materialized_environment["CHAT_BACKEND"] = runtime_backend
            _print_materialized(
                mode,
                environment=materialized_environment,
            )
    except DeploymentTopologyError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
