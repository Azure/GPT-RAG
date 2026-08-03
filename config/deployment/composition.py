"""Compose GPT-RAG infrastructure parameters for classic and hosted modes."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
from enum import Enum
from pathlib import Path
from typing import Mapping


APP_CONFIG_LABEL = "gpt-rag"
HOSTED_IMAGE_DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-fA-F]{64}$")


class DeploymentMode(str, Enum):
    CLASSIC = "classic"
    HOSTED_NO_PANEL = "hosted-no-panel"
    HOSTED_PANEL = "hosted-panel"


def is_truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "t", "yes", "y"}


def resolve_mode(environment: Mapping[str, str]) -> DeploymentMode:
    hosted = is_truthy(environment.get("DEPLOY_HOSTED_AGENT_ORCHESTRATION"))
    panel = is_truthy(environment.get("DEPLOY_ADMINISTRATIVE_PANEL"))
    if not hosted:
        return DeploymentMode.CLASSIC
    if panel:
        return DeploymentMode.HOSTED_PANEL
    return DeploymentMode.HOSTED_NO_PANEL


def selected_components(mode: DeploymentMode) -> tuple[str, ...]:
    if mode is DeploymentMode.CLASSIC:
        return (
            "gpt-rag-ui",
            "gpt-rag-orchestrator",
            "gpt-rag-ingestion",
        )
    return ("gpt-rag-ui", "gpt-rag-ingestion")


def _setting(name: str, value: str) -> dict[str, str]:
    return {
        "name": name,
        "value": value,
        "label": APP_CONFIG_LABEL,
        "contentType": "text/plain",
    }


def compose_parameters(
    source: Mapping[str, object],
    environment: Mapping[str, str],
) -> dict[str, object]:
    result = copy.deepcopy(source)
    parameters = result.get("parameters")
    if not isinstance(parameters, dict):
        raise ValueError("Parameter document must contain a 'parameters' object.")

    mode = resolve_mode(environment)
    hosted = mode is not DeploymentMode.CLASSIC
    panel = mode is not DeploymentMode.HOSTED_NO_PANEL

    parameters["deployHostedAgent"] = {"value": hosted}
    parameters["deployCosmosDb"] = {"value": panel}

    if hosted:
        # This digest only feeds the landing-zone parameter document at
        # provision time; it is informational and does not run a container.
        # The digest that is actually deployed as the hosted agent's image is
        # whatever HOSTED_AGENT_IMAGE_VERSION resolves to later, at `azd
        # deploy` time, in hosted-agent/azure.yaml. When
        # HOSTED_AGENT_AUTO_BUILD_IMAGE=true, scripts/preDeploy re-pins that
        # env var to a freshly built derivative image before deploying (see
        # config/deployment/hosted_image.py and ADR-0001), so the two digests
        # may legitimately differ across a provision+deploy cycle.
        digest = (environment.get("HOSTED_AGENT_IMAGE_VERSION") or "").strip()
        if not HOSTED_IMAGE_DIGEST_PATTERN.fullmatch(digest):
            raise ValueError(
                "Hosted mode requires HOSTED_AGENT_IMAGE_VERSION as an immutable "
                "OCI digest in sha256:<64 hex characters> form."
            )
        parameters["hostedAgent"] = {
            "value": {
                "name": (
                    environment.get("HOSTED_AGENT_NAME")
                    or "gpt-rag-orchestrator"
                ),
                "image": (
                    environment.get("HOSTED_AGENT_IMAGE")
                    or "gpt-rag-orchestrator"
                ),
                "version": digest,
                "startupCommand": (
                    environment.get("HOSTED_AGENT_STARTUP_COMMAND")
                    or "uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088"
                ),
                "runtime": {
                    "cpu": environment.get("HOSTED_AGENT_CONTAINER_CPU") or "2",
                    "memory": (
                        environment.get("HOSTED_AGENT_CONTAINER_MEMORY") or "4Gi"
                    ),
                },
                "protocols": [
                    {
                        "protocol": "responses",
                        "version": (
                            environment.get(
                                "HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION"
                            )
                            or "2.0.0"
                        ),
                    },
                    {
                        "protocol": "invocations",
                        "version": (
                            environment.get(
                                "HOSTED_AGENT_INVOCATIONS_PROTOCOL_VERSION"
                            )
                            or "1.0.0"
                        ),
                    },
                ],
            }
        }

    apps_parameter = parameters.get("containerAppsList")
    if not isinstance(apps_parameter, dict) or not isinstance(
        apps_parameter.get("value"), list
    ):
        raise ValueError("containerAppsList must contain an array value.")

    apps = apps_parameter["value"]
    if hosted:
        apps = [
            app
            for app in apps
            if isinstance(app, dict) and app.get("service_name") != "orchestrator"
        ]
    if mode is DeploymentMode.HOSTED_NO_PANEL:
        for app in apps:
            if app.get("service_name") == "dataingest":
                app["roles"] = [
                    role
                    for role in app.get("roles", [])
                    if role != "CosmosDBBuiltInDataContributor"
                ]
    parameters["containerAppsList"] = {"value": apps}

    if mode is DeploymentMode.HOSTED_NO_PANEL:
        parameters["databaseContainersList"] = {"value": []}

    parameters["additionalAppConfigurationSettings"] = {
        "value": [
            _setting(
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION",
                str(hosted).lower(),
            ),
            _setting(
                "DEPLOY_ADMINISTRATIVE_PANEL",
                str(panel and hosted).lower(),
            ),
            _setting("DEPLOYMENT_TOPOLOGY", mode.value),
            _setting("CHAT_BACKEND", "hosted_agent" if hosted else "orchestrator"),
            _setting(
                "HOSTED_AGENT_BASE_URL",
                environment.get("HOSTED_AGENT_BASE_URL", ""),
            ),
            _setting(
                "HOSTED_AGENT_RESOURCE_SCOPE",
                environment.get("HOSTED_AGENT_RESOURCE_SCOPE", ""),
            ),
            _setting(
                "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS",
                environment.get(
                    "HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS", "60"
                ),
            ),
        ]
    }
    return result


def compose_file(
    input_path: Path,
    output_path: Path,
    environment: Mapping[str, str],
) -> DeploymentMode:
    source = json.loads(input_path.read_text(encoding="utf-8-sig"))
    composed = compose_parameters(source, environment)
    output_path.write_text(
        json.dumps(composed, indent=2) + "\n",
        encoding="utf-8",
    )
    return resolve_mode(environment)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    mode = compose_file(args.input, args.output, os.environ)
    print(mode.value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
