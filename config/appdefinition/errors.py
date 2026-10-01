"""Error types for application definitions (FR-015d, FR-016)."""

from __future__ import annotations

from dataclasses import dataclass

SCHEMA_REFERENCE = "contracts/app-definition-v1.schema.json"


class AppDefinitionError(Exception):
    """Base class for every fail-closed application definition error."""


class DefinitionNotFoundError(AppDefinitionError):
    """The selected definition file or folder does not exist."""


@dataclass(frozen=True)
class ValidationIssue:
    """One problem found in a definition, located by a JSON pointer."""

    pointer: str
    message: str

    def __str__(self) -> str:
        return f"{self.pointer or '/'}: {self.message}"


class AppDefinitionValidationError(AppDefinitionError):
    """The definition violates the schema or a semantic rule."""

    def __init__(self, path: str, issues: list[ValidationIssue]) -> None:
        self.path = path
        self.issues = list(issues)
        lines = "\n".join(f"  {issue}" for issue in self.issues)
        super().__init__(
            f"Application definition {path} is invalid:\n{lines}\n"
            f"See {SCHEMA_REFERENCE}."
        )


class BindingMismatchError(AppDefinitionError):
    """The azd environment is already bound to a different application id."""

    def __init__(self, bound_id: str, requested_id: str) -> None:
        self.bound_id = bound_id
        self.requested_id = requested_id
        super().__init__(
            f"This environment is bound to app `{bound_id}`. "
            f"Create a new azd environment to deploy `{requested_id}`."
        )


class EnvironmentNotFoundError(AppDefinitionError):
    """No azd environment could be resolved for binding."""
