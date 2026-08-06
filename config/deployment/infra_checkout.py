"""Prepare the managed infrastructure repository for a pinned checkout."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path
from typing import Sequence


MANAGED_OVERRIDE_PATHS = ("main.parameters.json", "manifest.json")


class InfraCheckoutError(RuntimeError):
    """Raised when moving the managed infrastructure repository is unsafe."""


def _git(infra_dir: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(infra_dir), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def _is_managed_repository(infra_dir: Path) -> bool:
    result = _git(infra_dir, "rev-parse", "--show-toplevel")
    if result.returncode != 0:
        return False
    return Path(result.stdout.strip()).resolve() == infra_dir.resolve()


def prepare_infra_checkout(infra_dir: Path) -> None:
    """Reset generated overrides and reject all other dirty content."""
    infra_dir = infra_dir.resolve()
    if not infra_dir.exists():
        return

    if not _is_managed_repository(infra_dir):
        if any(infra_dir.iterdir()):
            raise InfraCheckoutError(
                f"{infra_dir} contains content but is not a managed Git repository; "
                "refusing to remove it."
            )
        return

    for relative_path in MANAGED_OVERRIDE_PATHS:
        tracked = _git(infra_dir, "ls-files", "--error-unmatch", "--", relative_path)
        if tracked.returncode == 0:
            restored = _git(
                infra_dir,
                "restore",
                "--source=HEAD",
                "--staged",
                "--worktree",
                "--",
                relative_path,
            )
            if restored.returncode != 0:
                raise InfraCheckoutError(
                    f"Failed to restore generated infra override {relative_path}: "
                    f"{restored.stderr.strip()}"
                )
            continue

        override_path = infra_dir / relative_path
        if override_path.is_symlink() or override_path.is_file():
            try:
                override_path.unlink()
            except OSError as exc:
                raise InfraCheckoutError(
                    f"Failed to remove generated infra override {override_path}: {exc}"
                ) from exc
        elif override_path.exists():
            raise InfraCheckoutError(
                f"Generated infra override path {override_path} is not a file; "
                "refusing to remove it."
            )

    status = _git(
        infra_dir,
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
        "--ignore-submodules=none",
    )
    if status.returncode != 0:
        raise InfraCheckoutError(
            f"Failed to inspect infrastructure repository status: "
            f"{status.stderr.strip()}"
        )
    if status.stdout.strip():
        raise InfraCheckoutError(
            "Infrastructure repository has local changes outside the generated "
            "manifest.json and main.parameters.json overrides. Preserve or remove "
            f"them before provisioning:\n{status.stdout.rstrip()}"
        )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Safely prepare the managed infra repository for checkout."
    )
    parser.add_argument("--infra-dir", required=True, type=Path)
    args = parser.parse_args(argv)

    try:
        prepare_infra_checkout(args.infra_dir)
    except InfraCheckoutError as exc:
        parser.exit(1, f"Error: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
