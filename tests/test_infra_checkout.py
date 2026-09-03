from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from config.deployment.infra_checkout import (
    InfraCheckoutError,
    prepare_infra_checkout,
)


def _git(repository: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repository), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


@pytest.fixture
def infra_repository(tmp_path: Path) -> tuple[Path, str, str]:
    repository = tmp_path / "infra"
    repository.mkdir()
    _git(repository, "init")
    _git(repository, "config", "user.name", "GPT-RAG tests")
    _git(repository, "config", "user.email", "gpt-rag-tests@example.invalid")

    for name, content in (
        ("main.bicep", "base bicep\n"),
        ("main.parameters.json", '{"source": "base"}\n'),
        ("manifest.json", '{"source": "base"}\n'),
        ("operator.txt", "base operator content\n"),
    ):
        (repository / name).write_text(content, encoding="utf-8")
    _git(repository, "add", ".")
    _git(repository, "commit", "-m", "base")
    base_commit = _git(repository, "rev-parse", "HEAD")

    (repository / "main.parameters.json").write_text(
        '{"source": "target"}\n', encoding="utf-8"
    )
    (repository / "manifest.json").write_text(
        '{"source": "target"}\n', encoding="utf-8"
    )
    _git(repository, "add", "main.parameters.json", "manifest.json")
    _git(repository, "commit", "-m", "target")
    target_commit = _git(repository, "rev-parse", "HEAD")
    _git(repository, "checkout", "--detach", base_commit)
    return repository, base_commit, target_commit


def test_generated_overrides_do_not_block_pin_upgrade(
    infra_repository: tuple[Path, str, str],
) -> None:
    repository, _, target_commit = infra_repository
    (repository / "main.parameters.json").write_text(
        '{"generated": "parameters"}\n', encoding="utf-8"
    )
    (repository / "manifest.json").write_text(
        '{"generated": "manifest"}\n', encoding="utf-8"
    )

    prepare_infra_checkout(repository)
    _git(repository, "checkout", "--detach", target_commit)

    assert _git(repository, "rev-parse", "HEAD") == target_commit
    assert _git(repository, "status", "--porcelain") == ""


def test_unrelated_dirty_content_fails_closed_and_is_preserved(
    infra_repository: tuple[Path, str, str],
) -> None:
    repository, base_commit, _ = infra_repository
    (repository / "manifest.json").write_text(
        '{"generated": "manifest"}\n', encoding="utf-8"
    )
    operator_content = "operator change that must survive\n"
    (repository / "operator.txt").write_text(operator_content, encoding="utf-8")

    with pytest.raises(InfraCheckoutError, match="local changes outside"):
        prepare_infra_checkout(repository)

    assert _git(repository, "rev-parse", "HEAD") == base_commit
    assert (repository / "operator.txt").read_text(encoding="utf-8") == operator_content
    assert (repository / "manifest.json").read_text(encoding="utf-8") == (
        '{"source": "base"}\n'
    )


def test_unremovable_generated_override_has_clear_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repository = tmp_path / "infra"
    repository.mkdir()
    _git(repository, "init")
    override = repository / "manifest.json"
    override.write_text('{"generated": true}\n', encoding="utf-8")

    def reject_removal(self: Path, missing_ok: bool = False) -> None:
        raise PermissionError("read-only override")

    monkeypatch.setattr(Path, "unlink", reject_removal)

    with pytest.raises(InfraCheckoutError, match="read-only override"):
        prepare_infra_checkout(repository)
