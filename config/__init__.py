"""Agent Landing Zone configuration packages.

Repository-root detection relies on the presence of both ``manifest.json`` and
``azure.yaml`` rather than on the checkout folder name, so a renamed or
differently named clone still resolves (naming map, R14).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Mapping

REPO_ROOT_ENV = "AGENTLZ_REPO_ROOT"
REPO_ROOT_MARKERS: tuple[str, ...] = ("manifest.json", "azure.yaml")


def is_repo_root(path: Path) -> bool:
    """Return whether ``path`` holds every repository-root marker file."""
    return all((path / marker).is_file() for marker in REPO_ROOT_MARKERS)


def find_repo_root(
    start: Path | str | None = None,
    environment: Mapping[str, str] | None = None,
) -> Path:
    """Locate the repository root.

    ``AGENTLZ_REPO_ROOT`` wins when set and valid. Otherwise the search walks
    up from ``start`` (default: this package) to the first folder containing
    both ``manifest.json`` and ``azure.yaml``.
    """
    env = os.environ if environment is None else environment
    explicit = (env.get(REPO_ROOT_ENV) or "").strip()
    if explicit:
        candidate = Path(explicit).resolve()
        if not is_repo_root(candidate):
            raise FileNotFoundError(
                f"{REPO_ROOT_ENV}={explicit} does not contain "
                + " and ".join(REPO_ROOT_MARKERS)
                + "."
            )
        return candidate
    origin = Path(start) if start is not None else Path(__file__).parent
    origin = origin.resolve()
    for candidate in (origin, *origin.parents):
        if is_repo_root(candidate):
            return candidate
    raise FileNotFoundError(
        "Could not find the repository root: no parent of "
        f"{origin} contains " + " and ".join(REPO_ROOT_MARKERS) + "."
    )
