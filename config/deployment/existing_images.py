"""Preserve deployed Container Apps images across ``azd provision`` (#708).

The landing zone creates every Container App with a placeholder image. Without
this step, re-running ``azd provision`` on an existing environment replaces the
real images published by ``azd deploy`` and takes the apps down until each
component is redeployed. Pre-provision discovers the images currently running
(by ``azd-service-name`` tag) and passes them to the template as
``containerAppsList[].image``.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from typing import Mapping, MutableMapping, Sequence

PLACEHOLDER_IMAGE_PREFIX = "mcr.microsoft.com/dotnet/samples:"


def parse_container_app_images(
    payload: object, environment_name: str | None = None
) -> dict[str, str]:
    """Return ``{service_name: image}`` from ``az containerapp list`` JSON."""
    images: dict[str, str] = {}
    if not isinstance(payload, list):
        return images
    for app in payload:
        if not isinstance(app, dict):
            continue
        tags = app.get("tags") or {}
        if not isinstance(tags, dict):
            continue
        service = tags.get("azd-service-name")
        if not service:
            continue
        if environment_name and tags.get("azd-env-name") not in (
            None,
            environment_name,
        ):
            continue
        image = app.get("image")
        if not isinstance(image, str) or not image.strip():
            continue
        image = image.strip()
        if image.startswith(PLACEHOLDER_IMAGE_PREFIX):
            continue
        images[str(service)] = image
    return images


def discover_existing_images(
    resource_group: str,
    subscription: str | None = None,
    environment_name: str | None = None,
) -> dict[str, str]:
    """Query Azure for images already deployed. Missing apps or errors yield ``{}``."""
    az = shutil.which("az")
    if not az or not resource_group:
        return {}
    command: list[str] = [
        az,
        "containerapp",
        "list",
        "-g",
        resource_group,
        "--query",
        "[].{tags:tags,image:properties.template.containers[0].image}",
        "-o",
        "json",
        "--only-show-errors",
    ]
    if subscription:
        command += ["--subscription", subscription]
    try:
        completed = subprocess.run(
            command, capture_output=True, text=True, timeout=180, check=False
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    if completed.returncode != 0:
        return {}
    try:
        payload = json.loads(completed.stdout or "[]")
    except json.JSONDecodeError:
        return {}
    return parse_container_app_images(payload, environment_name)


def apply_existing_images(
    apps: Sequence[object], images: Mapping[str, str]
) -> list[str]:
    """Set ``image`` on matching apps; returns the service names updated."""
    updated: list[str] = []
    for app in apps:
        if not isinstance(app, MutableMapping):
            continue
        service = app.get("service_name")
        image = images.get(str(service)) if service else None
        if image and not app.get("image"):
            app["image"] = image
            updated.append(str(service))
    return updated
