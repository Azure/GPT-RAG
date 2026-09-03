#!/usr/bin/env python3
"""Validate repository Copilot agents, skills, and scoped instructions."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
FRONTMATTER_BOUNDARY = "---"
LOCAL_LINK = re.compile(r"\[[^\]]+\]\((?!https?://|mailto:|#)([^)]+)\)")
ASSET_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ALLOWED_AGENT_TOOLS = {"agent", "edit", "execute", "read", "search", "web"}


def read_frontmatter(path: Path) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != FRONTMATTER_BOUNDARY:
        raise ValueError("missing opening YAML frontmatter boundary")

    try:
        end = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == FRONTMATTER_BOUNDARY
        )
    except StopIteration as exc:
        raise ValueError("missing closing YAML frontmatter boundary") from exc

    frontmatter = "\n".join(lines[1:end])
    try:
        metadata = yaml.safe_load(frontmatter)
    except yaml.YAMLError as exc:
        raise ValueError(f"invalid YAML frontmatter: {exc}") from exc
    if not isinstance(metadata, dict) or not all(
        isinstance(key, str) for key in metadata
    ):
        raise ValueError("YAML frontmatter must be a string-keyed mapping")

    return metadata, text


def require_strings(
    path: Path,
    metadata: dict[str, object],
    fields: tuple[str, ...],
    errors: list[str],
) -> None:
    for field in fields:
        value = metadata.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(
                f"{path.relative_to(ROOT)}: {field!r} must be a non-empty string"
            )


def validate_agent(
    path: Path,
    metadata: dict[str, object],
    names: set[str],
    errors: list[str],
) -> None:
    require_strings(path, metadata, ("name", "description"), errors)
    name = metadata.get("name")
    if isinstance(name, str):
        if not ASSET_NAME.fullmatch(name):
            errors.append(
                f"{path.relative_to(ROOT)}: agent name must be lowercase kebab-case"
            )
        if name in names:
            errors.append(f"{path.relative_to(ROOT)}: duplicate agent {name!r}")
        names.add(name)

    tools = metadata.get("tools")
    if (
        not isinstance(tools, list)
        or not tools
        or not all(isinstance(tool, str) and tool for tool in tools)
    ):
        errors.append(
            f"{path.relative_to(ROOT)}: 'tools' must be a non-empty string list"
        )
        return

    unknown_tools = sorted(set(tools) - ALLOWED_AGENT_TOOLS)
    if unknown_tools:
        errors.append(
            f"{path.relative_to(ROOT)}: unsupported tool aliases: {unknown_tools}"
        )
    if len(tools) != len(set(tools)):
        errors.append(f"{path.relative_to(ROOT)}: duplicate tool aliases")


def validate_skill(
    path: Path,
    metadata: dict[str, object],
    names: set[str],
    errors: list[str],
) -> None:
    require_strings(path, metadata, ("name", "description"), errors)
    name = metadata.get("name")
    if not isinstance(name, str):
        return
    if not ASSET_NAME.fullmatch(name):
        errors.append(
            f"{path.relative_to(ROOT)}: skill name must be lowercase kebab-case"
        )
    if name != path.parent.name:
        errors.append(f"{path.relative_to(ROOT)}: skill name must match directory")
    if name in names:
        errors.append(f"{path.relative_to(ROOT)}: duplicate skill {name!r}")
    names.add(name)


def validate_instruction(
    path: Path,
    metadata: dict[str, object],
    errors: list[str],
) -> None:
    require_strings(path, metadata, ("applyTo",), errors)
    apply_to = metadata.get("applyTo")
    if isinstance(apply_to, str) and any(
        not pattern.strip() for pattern in apply_to.split(",")
    ):
        errors.append(f"{path.relative_to(ROOT)}: 'applyTo' has an empty pattern")


def validate_local_links(path: Path, text: str, errors: list[str]) -> None:
    for target in LOCAL_LINK.findall(text):
        target_path = target.split("#", 1)[0]
        if not target_path:
            continue
        resolved = (path.parent / target_path).resolve()
        if not resolved.is_relative_to(ROOT.resolve()) or not resolved.exists():
            errors.append(
                f"{path.relative_to(ROOT)}: local link does not exist: {target}"
            )


def main() -> int:
    errors: list[str] = []
    agent_names: set[str] = set()
    skill_names: set[str] = set()

    groups = (
        (ROOT / ".github" / "agents", "*.agent.md", "agent"),
        (ROOT / ".github" / "skills", "*/SKILL.md", "skill"),
        (ROOT / ".github" / "instructions", "*.instructions.md", "instruction"),
    )

    for directory, pattern, asset_kind in groups:
        paths = sorted(directory.rglob(pattern))
        if not paths:
            errors.append(f"{directory.relative_to(ROOT)}: no matching assets")
            continue

        for path in paths:
            try:
                metadata, text = read_frontmatter(path)
            except (OSError, UnicodeError, ValueError) as exc:
                errors.append(f"{path.relative_to(ROOT)}: {exc}")
                continue

            validate_local_links(path, text, errors)

            if asset_kind == "agent":
                validate_agent(path, metadata, agent_names, errors)
            elif asset_kind == "skill":
                validate_skill(path, metadata, skill_names, errors)
            else:
                validate_instruction(path, metadata, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(agent_names)} agents and {len(skill_names)} skills "
        "plus scoped instructions."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
