"""Prepare a digest-pinned hosted-agent container image via ACR Tasks.

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
8088``). This module first builds the exact manifest-pinned orchestrator source
through the component's standard ACR Tasks path, resolves that pushed image to
an immutable digest, and then builds a tiny derivative image with only the
port/entrypoint ``CMD`` overridden. A caller may instead supply an immutable
digest explicitly, in which case no clone or build occurs. Both builds support
the VNet-injected agent pool used by ``NETWORK_ISOLATION=true`` deployments.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from util.azure_cli import resolve_az_command

HOSTED_STARTUP_COMMAND_DEFAULT = (
    "uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088"
)
HOSTED_PORT_DEFAULT = 8088
BASE_IMAGE_NAME_DEFAULT = "azure-gpt-rag/orchestrator"
DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-fA-F]{40}$")


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
    image, separator, digest = base_image_ref.rpartition("@")
    if not image or separator != "@" or not DIGEST_PATTERN.fullmatch(digest):
        raise ValueError(
            "base_image_ref must end in an immutable @sha256:<64 hex> digest, "
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
    azure_cli: str = "az",
) -> list[str]:
    """Return the argv for ``az acr build`` (pure, no execution)."""
    if not registry:
        raise ValueError("registry is required")
    if not image_name:
        raise ValueError("image_name is required")
    if not image_tag:
        raise ValueError("image_tag is required")
    args = [
        azure_cli,
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


def validate_digest(digest: str, *, name: str = "image version") -> str:
    """Return a normalized immutable digest or fail closed."""
    normalized = digest.strip()
    if not DIGEST_PATTERN.fullmatch(normalized):
        raise ValueError(
            f"{name} must be an immutable OCI digest in "
            "sha256:<64 hex characters> form."
        )
    return normalized


def resolve_pushed_digest(
    *,
    registry: str,
    image_name: str,
    image_tag: str,
    azure_cli: str = "az",
) -> str:
    """Look up the digest that was just pushed for ``image_name:image_tag``."""
    result = subprocess.run(
        [
            azure_cli,
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
    try:
        return validate_digest(digest, name="ACR manifest digest")
    except ValueError as exc:
        raise RuntimeError(
            f"Unexpected digest returned by az acr repository show: {digest!r}"
        ) from exc


def validate_acr_agent_pool(
    *,
    registry: str,
    resource_group: str,
    agent_pool: str,
    azure_cli: str = "az",
) -> None:
    """Fail before building when the configured private ACR agent pool is absent."""
    if not resource_group:
        raise ValueError(
            "resource_group is required when an ACR Tasks agent pool is configured"
        )
    subprocess.run(
        [
            azure_cli,
            "acr",
            "agentpool",
            "show",
            "--registry",
            registry,
            "--name",
            agent_pool,
            "--resource-group",
            resource_group,
            "--only-show-errors",
        ],
        check=True,
        stdout=sys.stderr,
    )


def clone_pinned_source(
    *,
    source_repo: str,
    source_ref: str,
    expected_commit: str,
    target_dir: Path,
) -> None:
    """Clone one manifest ref and prove it resolves to the expected commit."""
    if not source_repo:
        raise ValueError("source_repo is required")
    if not source_ref:
        raise ValueError("source_ref is required")
    if not COMMIT_PATTERN.fullmatch(expected_commit):
        raise ValueError("expected_commit must be a full 40-character Git SHA")

    subprocess.run(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            source_ref,
            "--quiet",
            source_repo,
            str(target_dir),
        ],
        check=True,
        stdout=sys.stderr,
    )
    result = subprocess.run(
        ["git", "-C", str(target_dir), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    actual_commit = result.stdout.strip()
    if actual_commit.lower() != expected_commit.lower():
        raise RuntimeError(
            f"Manifest ref {source_ref!r} resolved to {actual_commit!r}, "
            f"expected {expected_commit!r}."
        )


def build_source_image(
    *,
    registry: str,
    source_dir: Path,
    image_name: str,
    image_tag: str,
    agent_pool: str | None = None,
    azure_cli: str = "az",
) -> str:
    """Build the pinned orchestrator source through the standard ACR Tasks path."""
    dockerfile_path = source_dir / "Dockerfile"
    if not dockerfile_path.is_file():
        raise RuntimeError(f"Pinned source has no Dockerfile at {dockerfile_path}")
    args = build_acr_build_args(
        registry=registry,
        image_name=image_name,
        image_tag=image_tag,
        dockerfile_path="Dockerfile",
        context_dir=str(source_dir),
        agent_pool=agent_pool,
        azure_cli=azure_cli,
    )
    subprocess.run(args, check=True, stdout=sys.stderr)
    return resolve_pushed_digest(
        registry=registry,
        image_name=image_name,
        image_tag=image_tag,
        azure_cli=azure_cli,
    )


def prepare_hosted_image(
    *,
    image_version: str | None,
    registry: str,
    registry_endpoint: str,
    image_name: str,
    source_repo: str,
    source_ref: str,
    source_commit: str,
    base_image_name: str = BASE_IMAGE_NAME_DEFAULT,
    startup_command: str = HOSTED_STARTUP_COMMAND_DEFAULT,
    port: int = HOSTED_PORT_DEFAULT,
    agent_pool: str | None = None,
    resource_group: str | None = None,
    azure_cli: str = "az",
) -> str:
    """Resolve an override or automatically build a hosted-compatible digest."""
    if image_version and image_version.strip():
        return validate_digest(
            image_version, name="HOSTED_AGENT_IMAGE_VERSION"
        )

    if not registry_endpoint:
        raise ValueError(
            "Automatic hosted image preparation requires "
            "AZURE_CONTAINER_REGISTRY_ENDPOINT from provisioning."
        )
    if agent_pool:
        validate_acr_agent_pool(
            registry=registry,
            resource_group=resource_group or "",
            agent_pool=agent_pool,
            azure_cli=azure_cli,
        )

    source_tag = source_commit[:12].lower()
    base_tag = f"hosted-base-{source_tag}"
    hosted_tag = f"hosted-{source_tag}"
    with tempfile.TemporaryDirectory(prefix="hosted-agent-source-") as tmp:
        source_dir = Path(tmp) / "orchestrator"
        clone_pinned_source(
            source_repo=source_repo,
            source_ref=source_ref,
            expected_commit=source_commit,
            target_dir=source_dir,
        )
        base_digest = build_source_image(
            registry=registry,
            source_dir=source_dir,
            image_name=base_image_name,
            image_tag=base_tag,
            agent_pool=agent_pool,
            azure_cli=azure_cli,
        )

    base_image_ref = (
        f"{registry_endpoint.rstrip('/')}/{base_image_name}@{base_digest}"
    )
    return build_hosted_image(
        registry=registry,
        base_image_ref=base_image_ref,
        image_name=image_name,
        image_tag=hosted_tag,
        startup_command=startup_command,
        port=port,
        agent_pool=agent_pool,
        azure_cli=azure_cli,
    )


def build_hosted_image(
    *,
    registry: str,
    base_image_ref: str,
    image_name: str,
    image_tag: str,
    startup_command: str = HOSTED_STARTUP_COMMAND_DEFAULT,
    port: int = HOSTED_PORT_DEFAULT,
    agent_pool: str | None = None,
    azure_cli: str = "az",
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
            azure_cli=azure_cli,
        )
        subprocess.run(args, check=True, stdout=sys.stderr)
    return resolve_pushed_digest(
        registry=registry,
        image_name=image_name,
        image_tag=image_tag,
        azure_cli=azure_cli,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, help="ACR name, e.g. myregistry")
    parser.add_argument(
        "--registry-endpoint",
        required=True,
        help="ACR login server, e.g. myregistry.azurecr.io",
    )
    parser.add_argument(
        "--base-image-ref",
        default=None,
        help="Digest-pinned base image, e.g. myregistry.azurecr.io/gpt-rag-orchestrator@sha256:...",
    )
    parser.add_argument("--image-name", default="gpt-rag-orchestrator")
    parser.add_argument("--image-tag", default=None, help="Tag for the derivative image")
    parser.add_argument(
        "--image-version",
        default=None,
        help="Optional immutable digest override; skips all builds when supplied.",
    )
    parser.add_argument("--source-repo", default=None)
    parser.add_argument("--source-ref", default=None)
    parser.add_argument("--source-commit", default=None)
    parser.add_argument(
        "--base-image-name",
        default=BASE_IMAGE_NAME_DEFAULT,
    )
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
    parser.add_argument("--resource-group", default=None)
    args = parser.parse_args(argv)
    azure_cli = resolve_az_command()

    try:
        if args.base_image_ref:
            if not args.image_tag:
                parser.error("--image-tag is required with --base-image-ref")
            digest = build_hosted_image(
                registry=args.registry,
                base_image_ref=args.base_image_ref,
                image_name=args.image_name,
                image_tag=args.image_tag,
                startup_command=args.startup_command,
                port=args.port,
                agent_pool=args.agent_pool,
                azure_cli=azure_cli,
            )
        else:
            missing = [
                name
                for name, value in (
                    ("--source-repo", args.source_repo),
                    ("--source-ref", args.source_ref),
                    ("--source-commit", args.source_commit),
                )
                if not value
            ]
            if missing and not args.image_version:
                parser.error(
                    "automatic preparation requires " + ", ".join(missing)
                )
            digest = prepare_hosted_image(
                image_version=args.image_version,
                registry=args.registry,
                registry_endpoint=args.registry_endpoint,
                image_name=args.image_name,
                source_repo=args.source_repo or "",
                source_ref=args.source_ref or "",
                source_commit=args.source_commit or "",
                base_image_name=args.base_image_name,
                startup_command=args.startup_command,
                port=args.port,
                agent_pool=args.agent_pool,
                resource_group=args.resource_group,
                azure_cli=azure_cli,
            )
        print(digest)
        return 0
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"Hosted image preparation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
