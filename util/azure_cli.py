"""Cross-platform Azure CLI command resolution."""

from __future__ import annotations

import shutil


def resolve_az_command() -> str:
    """Return the executable path for Azure CLI when it is discoverable."""
    return shutil.which("az") or "az"
