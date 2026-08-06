"""Compose GPT-RAG infrastructure parameters for classic and hosted modes."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
from enum import Enum
from pathlib import Path
from typing import Mapping


APP_CONFIG_LABEL = "gpt-rag"
HOSTED_IMAGE_DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
HOSTED_STARTUP_COMMAND_DEFAULT = (
    "uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088"
)
HOSTED_RESOURCE_SCOPE_PATTERN = re.compile(
    r"^[^\s/](?:[^\s]*[^\s/])?/\.default$"
)


class DeploymentMode(str, Enum):
    CLASSIC = "classic"
    HOSTED_NO_PANEL = "hosted-no-panel"
    HOSTED_PANEL = "hosted-panel"


_KNOWN_TOPOLOGY_VALUES = {mode.value for mode in DeploymentMode}


class DeploymentTopologyError(ValueError):
    """Base class for GPT-RAG deployment-topology resolution failures.

    Raised instead of silently falling back so operators get explicit,
    actionable guidance (see ADR-0001 revision 5) rather than an unexpected
    topology being provisioned or deployed.
    """


class HostedPanelUnsupportedError(DeploymentTopologyError):
    """Raised when a signal would select hosted-panel mode.

    The administrative-panel data plane is not implemented yet; it is
    tracked by https://github.com/Azure/gpt-rag/issues/611. Until that lands,
    any request that would actually select hosted-panel mode must fail
    closed rather than silently downgrading to hosted-no-panel or classic.
    """


class ConflictingTopologySignalsError(DeploymentTopologyError):
    """Raised when explicit or persisted topology signals disagree.

    This is a fail-closed guard: GPT-RAG never guesses which of two
    disagreeing signals "wins". The operator must resolve the conflict (in
    the azd environment and/or in App Configuration) and re-run
    provisioning.
    """


def is_truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "t", "yes", "y"}


def hosted_startup_command(environment: Mapping[str, str]) -> str:
    return (
        environment.get("HOSTED_AGENT_STARTUP_COMMAND")
        or HOSTED_STARTUP_COMMAND_DEFAULT
    )


def hosted_startup_command_sha256(environment: Mapping[str, str]) -> str:
    return hashlib.sha256(
        hosted_startup_command(environment).encode("utf-8")
    ).hexdigest()


def validate_hosted_prerequisites(
    environment: Mapping[str, str],
    *,
    require_image_digest: bool = True,
    require_foundry_project: bool = False,
) -> None:
    """Validate the fail-closed hosted deployment contract."""
    configured_startup_command = (
        environment.get("HOSTED_AGENT_STARTUP_COMMAND") or ""
    ).strip()
    if (
        configured_startup_command
        and configured_startup_command != HOSTED_STARTUP_COMMAND_DEFAULT
    ):
        raise DeploymentTopologyError(
            "Custom HOSTED_AGENT_STARTUP_COMMAND values are not supported by "
            "the azure.ai.agent deployment manifest; use the default hosted "
            "entrypoint."
        )

    scope = (environment.get("HOSTED_AGENT_RESOURCE_SCOPE") or "").strip()
    if not HOSTED_RESOURCE_SCOPE_PATTERN.fullmatch(scope):
        raise DeploymentTopologyError(
            "Hosted mode requires HOSTED_AGENT_RESOURCE_SCOPE as an explicit "
            "delegated-user data-plane scope with a non-empty resource "
            "identifier followed by '/.default'."
        )

    digest = (environment.get("HOSTED_AGENT_IMAGE_VERSION") or "").strip()
    if require_image_digest or digest:
        if not HOSTED_IMAGE_DIGEST_PATTERN.fullmatch(digest):
            raise DeploymentTopologyError(
                "Hosted mode requires HOSTED_AGENT_IMAGE_VERSION as an immutable "
                "OCI digest in sha256:<64 hex characters> form."
            )

    if require_foundry_project:
        missing = [
            name
            for name in (
                "AZURE_AI_PROJECT_ENDPOINT",
                "AZURE_AI_PROJECT_RESOURCE_ID",
            )
            if not (environment.get(name) or "").strip()
        ]
        if missing:
            raise DeploymentTopologyError(
                "Hosted mode requires provisioned Foundry project configuration: "
                + ", ".join(missing)
                + "."
            )


def _explicit_flag_topology(
    environment: Mapping[str, str],
) -> DeploymentMode | None:
    """Interpret the legacy hosted/panel boolean-flag pair, if present.

    Returns ``None`` when neither ``DEPLOY_HOSTED_AGENT_ORCHESTRATION`` nor
    ``DEPLOY_ADMINISTRATIVE_PANEL`` is present in ``environment`` -- i.e.
    there is nothing explicit to interpret from this signal. This preserves
    the legacy explicit ``DEPLOY_HOSTED_AGENT_ORCHESTRATION=false`` flag as a
    compatible way to select the classic Container Apps topology.

    A panel flag is only subject to the #611 hard-failure gate when it would
    actually select hosted-panel mode (``hosted=true and panel=true``); a
    stray/incidental panel flag alongside ``hosted=false`` is ignored and the
    result stays classic, matching pre-ADR-0001 behavior.
    """
    hosted_raw = environment.get("DEPLOY_HOSTED_AGENT_ORCHESTRATION")
    panel_raw = environment.get("DEPLOY_ADMINISTRATIVE_PANEL")
    if hosted_raw is None and panel_raw is None:
        return None
    hosted = is_truthy(hosted_raw)
    panel = is_truthy(panel_raw)
    if not hosted:
        return DeploymentMode.CLASSIC
    if panel:
        raise HostedPanelUnsupportedError(
            "DEPLOY_ADMINISTRATIVE_PANEL=true (hosted-panel) is not "
            "supported yet; the administrative-panel data plane is tracked "
            "by https://github.com/Azure/gpt-rag/issues/611. Deploy with "
            "DEPLOY_ADMINISTRATIVE_PANEL=false (or unset) to use "
            "hosted-no-panel."
        )
    return DeploymentMode.HOSTED_NO_PANEL


def _explicit_topology_value(
    environment: Mapping[str, str],
) -> DeploymentMode | None:
    """Interpret the canonical ``DEPLOYMENT_TOPOLOGY`` variable, if present."""
    raw = (environment.get("DEPLOYMENT_TOPOLOGY") or "").strip().lower()
    if not raw:
        return None
    if raw == DeploymentMode.HOSTED_PANEL.value:
        raise HostedPanelUnsupportedError(
            "DEPLOYMENT_TOPOLOGY=hosted-panel is not supported yet; the "
            "administrative-panel data plane is tracked by "
            "https://github.com/Azure/gpt-rag/issues/611. Use "
            "DEPLOYMENT_TOPOLOGY=hosted-no-panel or DEPLOYMENT_TOPOLOGY="
            "classic instead."
        )
    if raw not in _KNOWN_TOPOLOGY_VALUES:
        raise DeploymentTopologyError(
            f"Unknown DEPLOYMENT_TOPOLOGY={raw!r}; expected one of: "
            + ", ".join(sorted(_KNOWN_TOPOLOGY_VALUES))
        )
    return DeploymentMode(raw)


def resolve_explicit_topology(
    environment: Mapping[str, str],
    *,
    strict_conflicts: bool = False,
) -> DeploymentMode | None:
    """Resolve any explicit topology signal in ``environment``.

    Returns ``None`` when neither the canonical ``DEPLOYMENT_TOPOLOGY``
    variable nor the legacy ``DEPLOY_HOSTED_AGENT_ORCHESTRATION``/
    ``DEPLOY_ADMINISTRATIVE_PANEL`` pair is present. When both signals are
    present, the canonical ``DEPLOYMENT_TOPOLOGY`` value is the operator
    override and takes precedence over previously materialized compatibility
    flags. Pass ``strict_conflicts=True`` when interpreting persisted App
    Configuration, where disagreement represents ambiguous deployed state
    and must fail closed.
    """
    topology_value = _explicit_topology_value(environment)
    if topology_value is not None and not strict_conflicts:
        return topology_value
    flag_value = _explicit_flag_topology(environment)
    if (
        topology_value is not None
        and flag_value is not None
        and topology_value is not flag_value
        and strict_conflicts
    ):
        raise ConflictingTopologySignalsError(
            "Conflicting deployment-topology signals: DEPLOYMENT_TOPOLOGY="
            f"{topology_value.value!r} does not match the "
            "DEPLOY_HOSTED_AGENT_ORCHESTRATION/DEPLOY_ADMINISTRATIVE_PANEL "
            f"pair, which resolves to {flag_value.value!r}. Set only one of "
            "these signals (or align them) before retrying. See ADR-0001 "
            "for the supported migration procedure between classic and "
            "hosted topologies."
        )
    return topology_value if topology_value is not None else flag_value


def resolve_mode(environment: Mapping[str, str]) -> DeploymentMode:
    """Resolve the deployment mode from explicit signals in ``environment``.

    Kept as a simple, backward-compatible entry point for
    ``compose_parameters``/``appconfig.build_settings``, which run after
    ``preProvision`` has already materialized the resolved topology into the
    environment. When nothing explicit is set, defaults to hosted-no-panel
    (ADR-0001 revision 5's fresh-deployment default); callers that need the
    full fresh-vs-existing/sticky/conflict contract should use
    ``resolve_topology`` instead.
    """
    explicit = resolve_explicit_topology(environment)
    if explicit is not None:
        return explicit
    return DeploymentMode.HOSTED_NO_PANEL


def resolve_topology(
    environment: Mapping[str, str],
    *,
    resource_group_exists: bool | None,
    persisted_settings: Mapping[str, str] | None = None,
) -> DeploymentMode:
    """Resolve the deployment topology per ADR-0001 revision 5.

    This is the single source of truth for the fresh-vs-existing
    default/sticky/conflict contract, intended to be called once, at
    ``preProvision`` time, before any later hook or Bicep composition runs:

    - An explicit signal in ``environment`` (``DEPLOYMENT_TOPOLOGY``, or the
      legacy ``DEPLOY_HOSTED_AGENT_ORCHESTRATION``/
      ``DEPLOY_ADMINISTRATIVE_PANEL`` pair) always wins. This honors a
      deliberate operator request, including an explicit migration between
      topologies -- there is no silent request-time fallback.
    - Otherwise, a genuinely fresh environment (``resource_group_exists`` is
      falsy, i.e. no resource group has been provisioned yet) defaults to
      hosted-no-panel.
    - Otherwise (an existing environment with no explicit signal in the
      current environment), the already-persisted App Configuration
      settings decide: a topology marker recorded there is sticky and is
      honored as-is (including a persisted hosted topology); the absence of
      any marker means a pre-cutover environment, which stays classic;
      internally conflicting persisted signals fail closed with migration
      guidance rather than guessing.
    """
    explicit = resolve_explicit_topology(environment)
    if explicit is not None:
        return explicit

    if not resource_group_exists:
        return DeploymentMode.HOSTED_NO_PANEL

    persisted_signals = persisted_settings or {}
    try:
        persisted = resolve_explicit_topology(
            persisted_signals, strict_conflicts=True
        )
    except ConflictingTopologySignalsError as exc:
        raise ConflictingTopologySignalsError(
            "The existing deployment has conflicting persisted "
            f"deployment-topology settings in App Configuration ({exc}). "
            "Resolve the conflict directly in App Configuration, or set an "
            "explicit DEPLOYMENT_TOPOLOGY in the azd environment, before "
            "re-running provisioning. See ADR-0001 for the supported "
            "migration procedure."
        ) from exc
    backend_raw = (persisted_signals.get("CHAT_BACKEND") or "").strip().lower()
    backend_mode: DeploymentMode | None = None
    if backend_raw:
        if backend_raw == "orchestrator":
            backend_mode = DeploymentMode.CLASSIC
        elif backend_raw == "hosted_agent":
            backend_mode = DeploymentMode.HOSTED_NO_PANEL
        else:
            raise DeploymentTopologyError(
                f"The existing deployment has unknown persisted CHAT_BACKEND="
                f"{backend_raw!r}. Set an explicit DEPLOYMENT_TOPOLOGY after "
                "reviewing the ADR-0001 migration procedure."
            )
    if persisted is not None and backend_mode is not None and persisted is not backend_mode:
        raise ConflictingTopologySignalsError(
            "The existing deployment has conflicting persisted topology and "
            "CHAT_BACKEND settings in App Configuration. Resolve the conflict "
            "or set an explicit DEPLOYMENT_TOPOLOGY after following the "
            "ADR-0001 migration procedure."
        )
    if persisted is not None:
        return persisted
    if backend_mode is not None:
        return backend_mode
    # No persisted topology marker: a pre-cutover, unmarked existing
    # environment stays classic rather than silently adopting the new
    # hosted-by-default template behavior.
    return DeploymentMode.CLASSIC


def describe_mode(mode: DeploymentMode) -> dict[str, object]:
    """Describe a resolved mode as the paired settings/flags that agree with it."""
    hosted = mode is not DeploymentMode.CLASSIC
    panel = mode is DeploymentMode.HOSTED_PANEL
    return {
        "topology": mode.value,
        "chat_backend": "hosted_agent" if hosted else "orchestrator",
        "components": list(selected_components(mode)),
        "deploy_hosted_agent_orchestration": hosted,
        "deploy_administrative_panel": panel,
    }


def materialized_settings(mode: DeploymentMode) -> dict[str, str]:
    """Return the paired settings to materialize into the azd environment.

    Used by ``preProvision`` immediately after resolving the topology, so
    every later hook (``preDeploy``, ``postProvision``) and the App
    Configuration `gpt-rag` label agree on the same values -- there is a
    single resolution, materialized once, not re-derived independently by
    each consumer.
    """
    description = describe_mode(mode)
    return {
        "DEPLOYMENT_TOPOLOGY": str(description["topology"]),
        "DEPLOY_HOSTED_AGENT_ORCHESTRATION": str(
            description["deploy_hosted_agent_orchestration"]
        ).lower(),
        "DEPLOY_ADMINISTRATIVE_PANEL": str(
            description["deploy_administrative_panel"]
        ).lower(),
        "CHAT_BACKEND": str(description["chat_backend"]),
    }


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
    *,
    expected_hosted_source_commit: str | None = None,
) -> dict[str, object]:
    result = copy.deepcopy(source)
    parameters = result.get("parameters")
    if not isinstance(parameters, dict):
        raise ValueError("Parameter document must contain a 'parameters' object.")

    mode = resolve_mode(environment)
    hosted = mode is not DeploymentMode.CLASSIC
    panel = mode is not DeploymentMode.HOSTED_NO_PANEL
    hosted_migration = hosted and is_truthy(
        environment.get("HOSTED_AGENT_MIGRATION")
    )
    network_isolation = is_truthy(environment.get("NETWORK_ISOLATION"))

    digest = (environment.get("HOSTED_AGENT_IMAGE_VERSION") or "").strip()
    generated_source_commit = (
        environment.get("HOSTED_AGENT_IMAGE_SOURCE_COMMIT") or ""
    ).strip()
    generated_startup_command_sha256 = (
        environment.get("HOSTED_AGENT_IMAGE_STARTUP_COMMAND_SHA256") or ""
    ).strip()
    deploy_hosted = hosted and bool(digest)

    if deploy_hosted:
        validate_hosted_prerequisites(environment)
        if (
            generated_source_commit
            and expected_hosted_source_commit
            and generated_source_commit.lower()
            != expected_hosted_source_commit.lower()
        ):
            raise DeploymentTopologyError(
                "The generated HOSTED_AGENT_IMAGE_VERSION was built from "
                f"{generated_source_commit}, but manifest.json now pins "
                f"{expected_hosted_source_commit}. Run the hosted image "
                "preparation command again before provisioning the deploy "
                "handoff."
            )
        if (
            generated_source_commit
            and generated_startup_command_sha256
            and generated_startup_command_sha256
            != hosted_startup_command_sha256(environment)
        ):
            raise DeploymentTopologyError(
                "The generated HOSTED_AGENT_IMAGE_VERSION does not match "
                "the configured HOSTED_AGENT_STARTUP_COMMAND. Run the hosted "
                "image preparation command again before provisioning the "
                "deploy handoff."
            )
    elif hosted:
        validate_hosted_prerequisites(
            environment,
            require_image_digest=False,
        )

    parameters["prepareHostedAgent"] = {"value": hosted}
    parameters["deployHostedAgent"] = {"value": deploy_hosted}
    parameters["deployCosmosDb"] = {"value": panel or hosted_migration}
    if hosted and network_isolation:
        parameters["deployAcrTaskAgentPool"] = {"value": True}

    if hosted:
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
                    hosted_startup_command(environment)
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
    if hosted and not hosted_migration:
        apps = [
            app
            for app in apps
            if isinstance(app, dict) and app.get("service_name") != "orchestrator"
        ]
    if mode is DeploymentMode.HOSTED_NO_PANEL and not hosted_migration:
        for app in apps:
            if app.get("service_name") == "dataingest":
                app["roles"] = [
                    role
                    for role in app.get("roles", [])
                    if role != "CosmosDBBuiltInDataContributor"
                ]
    parameters["containerAppsList"] = {"value": apps}

    if mode is DeploymentMode.HOSTED_NO_PANEL and not hosted_migration:
        parameters["databaseContainersList"] = {"value": []}

    parameters["additionalAppConfigurationSettings"] = {
        "value": [
            _setting(
                "DEPLOY_HOSTED_AGENT_ORCHESTRATION",
                str(hosted).lower(),
            ),
            _setting("PREPARE_HOSTED_AGENT", str(hosted).lower()),
            _setting("DEPLOY_HOSTED_AGENT", str(deploy_hosted).lower()),
            _setting("HOSTED_AGENT_PREPARED", str(hosted).lower()),
            _setting(
                "DEPLOY_ADMINISTRATIVE_PANEL",
                str(panel and hosted).lower(),
            ),
            _setting("DEPLOYMENT_TOPOLOGY", mode.value),
            _setting(
                "HOSTED_AGENT_MIGRATION",
                str(hosted_migration).lower(),
            ),
            _setting(
                "CHAT_BACKEND",
                (
                    "hosted_agent"
                    if hosted and not hosted_migration
                    else "orchestrator"
                ),
            ),
            _setting(
                "HOSTED_AGENT_BASE_URL",
                environment.get("HOSTED_AGENT_BASE_URL", ""),
            ),
            _setting(
                "HOSTED_AGENT_RESOURCE_SCOPE",
                environment.get("HOSTED_AGENT_RESOURCE_SCOPE", ""),
            ),
            _setting(
                "HOSTED_AGENT_IMAGE_VERSION",
                environment.get("HOSTED_AGENT_IMAGE_VERSION", ""),
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
    *,
    expected_hosted_source_commit: str | None = None,
) -> DeploymentMode:
    source = json.loads(input_path.read_text(encoding="utf-8-sig"))
    composed = compose_parameters(
        source,
        environment,
        expected_hosted_source_commit=expected_hosted_source_commit,
    )
    output_path.write_text(
        json.dumps(composed, indent=2) + "\n",
        encoding="utf-8",
    )
    return resolve_mode(environment)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--hosted-source-commit", default=None)
    args = parser.parse_args()

    mode = compose_file(
        args.input,
        args.output,
        os.environ,
        expected_hosted_source_commit=args.hosted_source_commit,
    )
    print(mode.value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
