"""Build a hosted-agent-specific derivative container image via ACR Tasks.

Context
-------
Microsoft Foundry's hosted-agent "Create Agent" API for container-mode agents
only accepts an ``image`` reference (see ``ContainerConfigurationAPI`` in the
``azure.ai.agent`` azd extension). It never receives the ``startupCommand``
declared in ``hosted-agent/azure.yaml`` or ``composition.py``'s
``hostedAgent.startupCommand`` parameter -- that field only affects the local
``azd ai agent run`` developer flow, not real container deploys. Because of
this, whatever ``CMD``/``ENTRYPOINT`` is baked into the published
``gpt-rag-orchestrator`` image is what a Foundry hosted agent will actually
run, and today that image's ``CMD`` is always the classic Container-App
entrypoint (``uvicorn main:app --host 0.0.0.0 --port 8080``), not the hosted
entrypoint (``uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port
8088``). This module builds a tiny derivative image, layered ``FROM`` the
already-published/immutable base image with only the port/entrypoint ``CMD``
overridden, so the image actually deployed to the hosted agent runs the
correct process. The build goes through ACR Tasks (``az acr build``),
supporting a VNet-injected agent pool for ``NETWORK_ISOLATION=true``
deployments -- no Docker daemon or public registry access is required.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HOSTED_STARTUP_COMMAND_DEFAULT = (
    "uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088"
)
HOSTED_PORT_DEFAULT = 8088
DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-fA-F]{64}$")


def resolve_azure_cli_executable() -> str:
    """Return the executable path for Azure CLI across native platforms."""
    executable = shutil.which("az") or shutil.which("az.cmd")
    if not executable:
        raise RuntimeError("Azure CLI executable was not found in PATH.")
    return executable


def render_hosted_dockerfile(
    base_image_ref: str,
    startup_command: str = HOSTED_STARTUP_COMMAND_DEFAULT,
    port: int = HOSTED_PORT_DEFAULT,
) -> str:
    """Render the derivative Dockerfile content.

    ``base_image_ref`` must already be a fully-qualified, digest-pinned image
    reference (``<registry>/<repo>@sha256:<digest>``) so the derivative image
    stays anchored to an immutable base, consistent with the rest of this
    repo's "no mutable tags" deployment contract.
    """
    if "@sha256:" not in base_image_ref:
        raise ValueError(
            "base_image_ref must be digest-pinned (contain '@sha256:...'), "
            f"got: {base_image_ref!r}"
        )
    command_parts = startup_command.strip().split()
    if not command_parts:
        raise ValueError("startup_command must not be empty")
    cmd_json = json.dumps(command_parts)
    return (
        f"FROM {base_image_ref}\n"
        f"EXPOSE {port}\n"
        f"CMD {cmd_json}\n"
    )


def build_acr_build_args(
    *,
    registry: str,
    image_name: str,
    image_tag: str,
    dockerfile_path: str,
    context_dir: str,
    agent_pool: str | None = None,
) -> list[str]:
    """Return the argv for ``az acr build`` (pure, no execution)."""
    if not registry:
        raise ValueError("registry is required")
    if not image_name:
        raise ValueError("image_name is required")
    if not image_tag:
        raise ValueError("image_tag is required")
    args = [
        "az",
        "acr",
        "build",
        "--registry",
        registry,
        "--image",
        f"{image_name}:{image_tag}",
        "--file",
        dockerfile_path,
        context_dir,
    ]
    if agent_pool:
        args.extend(["--agent-pool", agent_pool])
    return args


def parse_digest_from_build_output(output: str) -> str | None:
    """Best-effort extraction of the pushed manifest digest from ``az acr
    build`` text output (used when ``--query``/JSON parsing of the run isn't
    available; callers should prefer looking up the digest via
    ``az acr repository show-manifests`` after a successful build, which is
    what the CLI entrypoint below does)."""
    match = re.search(r"sha256:[0-9a-fA-F]{64}", output)
    return match.group(0) if match else None


def resolve_pushed_digest(
    *, registry: str, image_name: str, image_tag: str
) -> str:
    """Look up the digest that was just pushed for ``image_name:image_tag``."""
    result = subprocess.run(
        [
            resolve_azure_cli_executable(),
            "acr",
            "repository",
            "show",
            "--name",
            registry,
            "--image",
            f"{image_name}:{image_tag}",
            "--query",
            "digest",
            "-o",
            "tsv",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    digest = result.stdout.strip()
    if not DIGEST_PATTERN.fullmatch(digest):
        raise RuntimeError(
            f"Unexpected digest format returned by az acr repository show: {digest!r}"
        )
    return digest


def build_hosted_image(
    *,
    registry: str,
    base_image_ref: str,
    image_name: str,
    image_tag: str,
    startup_command: str = HOSTED_STARTUP_COMMAND_DEFAULT,
    port: int = HOSTED_PORT_DEFAULT,
    agent_pool: str | None = None,
) -> str:
    """Build+push the hosted derivative image via ACR Tasks; return its digest."""
    dockerfile_content = render_hosted_dockerfile(base_image_ref, startup_command, port)
    with tempfile.TemporaryDirectory(prefix="hosted-agent-image-") as tmp:
        dockerfile_path = Path(tmp) / "Dockerfile"
        dockerfile_path.write_text(dockerfile_content, encoding="utf-8")
        args = build_acr_build_args(
            registry=registry,
            image_name=image_name,
            image_tag=image_tag,
            dockerfile_path=str(dockerfile_path),
            context_dir=tmp,
            agent_pool=agent_pool,
        )
        args[0] = resolve_azure_cli_executable()
        subprocess.run(args, check=True)
    return resolve_pushed_digest(
        registry=registry, image_name=image_name, image_tag=image_tag
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, help="ACR name, e.g. myregistry")
    parser.add_argument(
        "--base-image-ref",
        required=True,
        help="Digest-pinned base image, e.g. myregistry.azurecr.io/gpt-rag-orchestrator@sha256:...",
    )
    parser.add_argument("--image-name", default="gpt-rag-orchestrator")
    parser.add_argument("--image-tag", required=True, help="Tag for the derivative image")
    parser.add_argument(
        "--startup-command",
        default=HOSTED_STARTUP_COMMAND_DEFAULT,
    )
    parser.add_argument("--port", type=int, default=HOSTED_PORT_DEFAULT)
    parser.add_argument(
        "--agent-pool",
        default=None,
        help="ACR Tasks agent pool name (required under NETWORK_ISOLATION=true)",
    )
    args = parser.parse_args(argv)

    digest = build_hosted_image(
        registry=args.registry,
        base_image_ref=args.base_image_ref,
        image_name=args.image_name,
        image_tag=args.image_tag,
        startup_command=args.startup_command,
        port=args.port,
        agent_pool=args.agent_pool,
    )
    print(digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
