"""Environment binding: one application per azd environment (FR-015g, R11).

The first provision stores the definition ``id`` as ``AGENTLZ_APP_ID`` in
``.azure/<env>/.env``. Later provisions and deploys must use a definition with
the same ``id``; a different ``id`` fails before any Azure change.
"""

from __future__ import annotations

import json
import os
import re
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from .errors import BindingMismatchError, EnvironmentNotFoundError

APP_ID_ENV = "AGENTLZ_APP_ID"
_LINE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$")


@dataclass(frozen=True)
class BindingResult:
    env_file: Path
    app_id: str
    newly_bound: bool


def resolve_env_name(azure_dir: Path, environment: Mapping[str, str] | None = None) -> str:
    """Return the azd environment name: ``AZURE_ENV_NAME`` or the azd default."""
    env = os.environ if environment is None else environment
    name = (env.get("AZURE_ENV_NAME") or "").strip()
    if name:
        return name
    config = azure_dir / "config.json"
    if config.is_file():
        value = json.loads(config.read_text(encoding="utf-8")).get("defaultEnvironment")
        if isinstance(value, str) and value.strip():
            return value.strip()
    raise EnvironmentNotFoundError(
        "No azd environment is selected. Run `azd env new <name>` or `azd env select <name>` first."
    )


def env_file_path(azure_dir: Path, env_name: str) -> Path:
    if not env_name or any(part in env_name for part in ("/", "\\", "..")):
        raise EnvironmentNotFoundError(f"Invalid azd environment name `{env_name}`.")
    return azure_dir / env_name / ".env"


def _unquote(raw: str) -> str:
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
        return raw[1:-1]
    return raw


def read_bound_app_id(env_file: Path) -> str | None:
    if not env_file.is_file():
        return None
    for line in env_file.read_text(encoding="utf-8-sig").splitlines():
        match = _LINE.match(line)
        if match and match.group(1) == APP_ID_ENV:
            value = _unquote(match.group(2)).strip()
            return value or None
    return None


def check_binding(env_file: Path, app_id: str) -> str | None:
    """Raise :class:`BindingMismatchError` on a different bound id; return the bound id."""
    bound = read_bound_app_id(env_file)
    if bound is not None and bound != app_id:
        raise BindingMismatchError(bound, app_id)
    return bound


def _write_value(env_file: Path, key: str, value: str) -> None:
    lines = env_file.read_text(encoding="utf-8-sig").splitlines() if env_file.is_file() else []
    rendered = f'{key}="{value}"'
    replaced = False
    for index, line in enumerate(lines):
        match = _LINE.match(line)
        if match and match.group(1) == key:
            lines[index] = rendered
            replaced = True
    if not replaced:
        lines.append(rendered)
    env_file.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=env_file.parent, prefix=".env.", text=True)
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            stream.write("\n".join(lines) + "\n")
        os.replace(temporary, env_file)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def bind(env_file: Path, app_id: str) -> BindingResult:
    """Bind ``env_file`` to ``app_id``; idempotent for the same id."""
    bound = check_binding(env_file, app_id)
    if bound == app_id:
        return BindingResult(env_file, app_id, newly_bound=False)
    _write_value(env_file, APP_ID_ENV, app_id)
    return BindingResult(env_file, app_id, newly_bound=True)
