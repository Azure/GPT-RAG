"""SharePoint Indexed knowledge source preflight and helpers (preview).

The SharePoint Indexed knowledge source (kind: ``indexedSharePoint``, API
``2026-05-01-preview``) is registered through the standard j2 template +
``provision_knowledge_sources`` path in ``config/search/setup.py``. This
module intentionally does NOT PUT the KS itself; it only owns:

1. Advisory prerequisites logging for operators (Entra app registration +
   Federated Identity Credential + Graph ``Sites.Selected`` or
   ``Sites.Read.All`` admin consent), matching the pattern used for
   Work IQ.
2. A ``filter_sharepoint_indexed_sources`` helper that removes the KS from
   the rendered template when required identifiers are missing so the rest
   of the provisioning still succeeds.

Auth to Microsoft Graph is baked into the KS ``connectionString`` at
registration time via the User Assigned Managed Identity + FIC and is not
performed here. See ``docs/howto_grounding_sharepoint_indexed.md`` for the
manual Entra prerequisites that Bicep cannot cover.
"""

from __future__ import annotations

import logging
from typing import Any


SHAREPOINT_INDEXED_KIND = "indexedSharePoint"
SHAREPOINT_INDEXED_PARAMS_KEY = "indexedSharePointParameters"
SHAREPOINT_INDEXED_ADMIN_CONSENT_DOCS = (
    "https://aka.ms/gpt-rag/sharepoint-indexed-prereqs"
)


def _is_truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"true", "1", "yes", "y", "t"}


def sharepoint_indexed_required_context_keys() -> tuple[str, ...]:
    """Return the App Configuration keys required to enable the KS."""

    return (
        "SHAREPOINT_INDEXED_ENABLED",
        "SHAREPOINT_INDEXED_KNOWLEDGE_SOURCE_NAME",
        "SHAREPOINT_INDEXED_INDEX_NAME",
        "SHAREPOINT_INDEXED_SITE_URL",
        "SHAREPOINT_INDEXED_TENANT_ID",
    )


def sharepoint_indexed_is_configured(context: dict) -> bool:
    """Return True when the operator has enabled the KS and set the
    required identifiers. Empty strings count as unset.
    """

    if not _is_truthy(context.get("SHAREPOINT_INDEXED_ENABLED")):
        return False
    required = (
        "SHAREPOINT_INDEXED_KNOWLEDGE_SOURCE_NAME",
        "SHAREPOINT_INDEXED_INDEX_NAME",
        "SHAREPOINT_INDEXED_SITE_URL",
        "SHAREPOINT_INDEXED_TENANT_ID",
    )
    return all((context.get(k) or "").strip() for k in required)


def log_sharepoint_indexed_prerequisites_warning() -> None:
    """Emit an advisory warning listing the manual prerequisites that must
    be completed before the SharePoint Indexed KS can retrieve results.
    """

    logging.warning(
        "SharePoint Indexed is enabled in configuration but not all "
        "prerequisites can be verified from the deployment identity. "
        "The knowledge source will still be registered; retrieval will fail "
        "until the manual steps below have been completed."
    )
    logging.warning(
        "   Prerequisites: 1) Register an Entra app for SharePoint Indexed. "
        "2) Add a Federated Identity Credential on that app for the User "
        "Assigned Managed Identity used by the orchestrator. "
        "3) Grant admin consent for Microsoft Graph Sites.Selected (preferred) "
        "or Sites.Read.All. 4) If using Sites.Selected, grant the app read "
        "access to the target SharePoint site."
    )
    logging.warning(
        f"   See {SHAREPOINT_INDEXED_ADMIN_CONSENT_DOCS} for the full "
        "walkthrough (this URL is a placeholder until the docs page lands "
        "on the docs branch)."
    )


def filter_sharepoint_indexed_sources(defs: dict, context: dict) -> None:
    """Remove the SharePoint Indexed KS from the rendered template when the
    required identifiers are missing so the rest of the provisioning still
    succeeds. Default deployments (SharePoint Indexed disabled) are
    untouched.
    """

    ks_name = (context.get("SHAREPOINT_INDEXED_KNOWLEDGE_SOURCE_NAME") or "").strip()
    if not ks_name:
        return
    if sharepoint_indexed_is_configured(context):
        log_sharepoint_indexed_prerequisites_warning()
        return

    logging.warning(
        f"SharePoint Indexed knowledge source '{ks_name}' is missing one or "
        "more required identifiers (INDEX_NAME, SITE_URL, TENANT_ID). "
        "Removing it from the provisioning payload."
    )
    knowledge_sources = defs.get("knowledgeSources") or []
    defs["knowledgeSources"] = [
        ks for ks in knowledge_sources if ks.get("name") != ks_name
    ]
    for kb in defs.get("knowledgeBases") or []:
        kb["knowledgeSources"] = [
            ref
            for ref in kb.get("knowledgeSources") or []
            if ref.get("name") != ks_name
        ]
