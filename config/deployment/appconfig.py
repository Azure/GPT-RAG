"""Publish mode-specific GPT-RAG runtime references to App Configuration."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from typing import Mapping

from config.deployment.composition import (
    APP_CONFIG_LABEL,
    DeploymentMode,
    resolve_mode,
)
from util.azure_cli import resolve_az_command


def _resolve_az_command() -> str:
    return resolve_az_command()


def _run_az(arguments: list[str], *, required: bool = True) -> str:
    completed = subprocess.run(
        [_resolve_az_command(), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    output = completed.stdout.strip()
    if completed.returncode != 0 or (required and not output):
        detail = completed.stderr.strip() or output
        raise RuntimeError(
            f"Azure CLI command failed: az {' '.join(arguments)}: {detail}"
        )
    return output


def _container_app(
    resource_group: str,
    name: str,
    *,
    required: bool,
) -> dict[str, str]:
    query = "{fqdn:properties.configuration.ingress.fqdn,principalId:identity.principalId}"
    output = _run_az(
        [
            "containerapp",
            "show",
            "--resource-group",
            resource_group,
            "--name",
            name,
            "--query",
            query,
            "--output",
            "json",
        ],
        required=required,
    )
    if not output:
        return {"fqdn": "", "principalId": ""}
    value = json.loads(output)
    return {
        "fqdn": value.get("fqdn") or "",
        "principalId": value.get("principalId") or "",
    }


def _required(environment: Mapping[str, str], name: str) -> str:
    value = (environment.get(name) or "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable {name}.")
    return value


def build_settings(
    environment: Mapping[str, str],
    *,
    require_hosted_endpoint: bool = False,
) -> dict[str, str]:
    mode = resolve_mode(environment)
    hosted = mode is not DeploymentMode.CLASSIC
    resource_group = _required(environment, "AZURE_RESOURCE_GROUP")
    resource_token = _required(environment, "RESOURCE_TOKEN")

    app_names = {
        "frontend": f"ca-{resource_token}-frontend",
        "dataingest": f"ca-{resource_token}-dataingest",
        "orchestrator": f"ca-{resource_token}-orchestrator",
    }
    frontend = _container_app(
        resource_group, app_names["frontend"], required=True
    )
    dataingest = _container_app(
        resource_group, app_names["dataingest"], required=True
    )
    orchestrator = (
        _container_app(
            resource_group, app_names["orchestrator"], required=True
        )
        if mode is DeploymentMode.CLASSIC
        else {"fqdn": "", "principalId": ""}
    )

    hosted_base_url = (environment.get("HOSTED_AGENT_BASE_URL") or "").strip()
    hosted_scope = (environment.get("HOSTED_AGENT_RESOURCE_SCOPE") or "").strip()
    if hosted and require_hosted_endpoint:
        if not hosted_base_url:
            raise ValueError(
                "Hosted deployment completed without HOSTED_AGENT_BASE_URL."
            )
        if not hosted_scope.endswith("/.default"):
            raise ValueError(
                "HOSTED_AGENT_RESOURCE_SCOPE must be the explicit data-plane "
                "scope ending in '/.default'."
            )

    container_apps = [
        {
            "name": app_names["frontend"],
            "serviceName": "frontend",
            "canonical_name": "FRONTEND_APP",
            "principalId": frontend["principalId"],
            "fqdn": frontend["fqdn"],
        },
        {
            "name": app_names["dataingest"],
            "serviceName": "dataingest",
            "canonical_name": "DATA_INGEST_APP",
            "principalId": dataingest["principalId"],
            "fqdn": dataingest["fqdn"],
        },
    ]
    if mode is DeploymentMode.CLASSIC:
        container_apps.insert(
            0,
            {
                "name": app_names["orchestrator"],
                "serviceName": "orchestrator",
                "canonical_name": "ORCHESTRATOR_APP",
                "principalId": orchestrator["principalId"],
                "fqdn": orchestrator["fqdn"],
            },
        )

    return {
        "DEPLOY_HOSTED_AGENT_ORCHESTRATION": str(hosted).lower(),
        "DEPLOY_ADMINISTRATIVE_PANEL": str(
            mode is DeploymentMode.HOSTED_PANEL
        ).lower(),
        "DEPLOYMENT_TOPOLOGY": mode.value,
        "CHAT_BACKEND": "hosted_agent" if hosted else "orchestrator",
        "ORCHESTRATOR_BASE_URL": (
            f"https://{orchestrator['fqdn']}" if orchestrator["fqdn"] else ""
        ),
        "INGESTION_BASE_URL": f"https://{dataingest['fqdn']}",
        "HOSTED_AGENT_BASE_URL": hosted_base_url,
        "HOSTED_AGENT_RESOURCE_SCOPE": hosted_scope,
        "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS": (
            environment.get("HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS") or "60"
        ),
        "ORCHESTRATOR_APP_ENDPOINT": (
            f"https://{orchestrator['fqdn']}" if orchestrator["fqdn"] else ""
        ),
        "FRONTEND_APP_ENDPOINT": f"https://{frontend['fqdn']}",
        "DATA_INGEST_APP_ENDPOINT": f"https://{dataingest['fqdn']}",
        "ORCHESTRATOR_APP_NAME": (
            app_names["orchestrator"]
            if mode is DeploymentMode.CLASSIC
            else ""
        ),
        "FRONTEND_APP_NAME": app_names["frontend"],
        "DATA_INGEST_APP_NAME": app_names["dataingest"],
        "CONTAINER_APPS": json.dumps(
            container_apps, separators=(",", ":")
        ),
    }


def publish_settings(endpoint: str, settings: Mapping[str, str]) -> None:
    for key, value in settings.items():
        _run_az(
            [
                "appconfig",
                "kv",
                "set",
                "--endpoint",
                endpoint,
                "--key",
                key,
                "--value",
                value,
                "--label",
                APP_CONFIG_LABEL,
                "--content-type",
                "text/plain",
                "--auth-mode",
                "login",
                "--yes",
                "--output",
                "none",
            ],
            required=False,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-hosted-endpoint", action="store_true")
    args = parser.parse_args()
    endpoint = _required(os.environ, "APP_CONFIG_ENDPOINT")
    settings = build_settings(
        os.environ,
        require_hosted_endpoint=args.require_hosted_endpoint,
    )
    publish_settings(endpoint, settings)
    print(resolve_mode(os.environ).value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
