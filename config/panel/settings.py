"""Public hosted-panel settings shared by deployment publishers.

Mirrors ``config.continuity.settings``: every key here is safe to publish
unconditionally (App Configuration label ``gpt-rag``) because it is inert
unless ``DEPLOY_ADMINISTRATIVE_PANEL`` and ``PANEL_HISTORY_ENABLED`` are both
``true`` (see ADR-0004 and the merged ``gpt-rag-ui`` ``panel_config.py``,
which this module's key names and defaults match exactly -- no duplicate or
invented keys).

``PANEL_HISTORY_OWNER_BINDING_VALIDATED`` is forced to ``false`` here the
same way ``HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`` is forced to
``false`` in ``config.continuity.settings``: it is this ADR's own
environment-evidence gate for the panel's list/read call path, and no live
verification procedure for that gate ships in this change (only the
platform contract -- containers, RBAC, App Configuration keys, and the
versioned schema). Flipping it to ``true`` is out of scope until a
dedicated verification procedure exists; until then the panel safely stays
on its ``owner_index`` pre-gate/fallback mechanism, which is fully
functional and never itself returns an error for the unmet gate.
"""

from __future__ import annotations

from collections.abc import Mapping


LABEL = "gpt-rag"

# Canonical panel Cosmos container names. Both are partitioned by
# ``/principal_id`` (matching the classic ``conversations`` container
# convention) and carry metadata only -- never message content, citations,
# or document content. Distinct from the classic chat-content container so
# switching topologies never mixes content and metadata in one container.
OWNER_INDEX_CONTAINER_NAME = "panel-conversation-owner-index"
FEEDBACK_CONTAINER_NAME = "panel-feedback"

# App Configuration keys that receive the container names above (published
# by the generic AILZ database-container-list mechanism via each entry's
# ``canonical_name``; see ``config.deployment.composition.panel_database_containers``).
OWNER_INDEX_CONTAINER_CONFIG_KEY = "PANEL_OWNER_INDEX_DATABASE_CONTAINER"
FEEDBACK_CONTAINER_CONFIG_KEY = "PANEL_FEEDBACK_DATABASE_CONTAINER"

DEFAULT_CURSOR_TTL_SECONDS = "600"
DEFAULT_OVERVIEW_MIN_CARDINALITY = "5"

DEFAULT_SETTINGS: Mapping[str, str] = {
    "PANEL_HISTORY_ENABLED": "false",
    "PANEL_HISTORY_OWNER_BINDING_VALIDATED": "false",
    "PANEL_CONVERSATION_ENUMERATION_MODE": "owner_index",
    "PANEL_CONVERSATIONS_TOKEN_AUDIENCE": "",
    "PANEL_CONVERSATIONS_TENANT_ID": "",
    OWNER_INDEX_CONTAINER_CONFIG_KEY: OWNER_INDEX_CONTAINER_NAME,
    FEEDBACK_CONTAINER_CONFIG_KEY: FEEDBACK_CONTAINER_NAME,
    "PANEL_CURSOR_TTL_SECONDS": DEFAULT_CURSOR_TTL_SECONDS,
    "PANEL_OVERVIEW_MIN_CARDINALITY": DEFAULT_OVERVIEW_MIN_CARDINALITY,
}


def public_settings(environment: Mapping[str, str]) -> dict[str, str]:
    """Return the panel settings to publish, keeping the evidence-gated flag
    fail closed regardless of what an operator may have set locally.

    While ``DEPLOY_ADMINISTRATIVE_PANEL``/``PANEL_HISTORY_ENABLED`` are
    ``false`` (today's default and only supported state -- hosted-panel
    topology selection itself still fails closed pending
    https://github.com/Azure/gpt-rag/issues/611's remaining component work),
    every value here stays at its safe default and no Cosmos container or
    RBAC assignment is provisioned (see
    ``config.deployment.composition.panel_database_containers`` and
    ``config.panel.setup``).
    """
    settings = {
        key: str(environment.get(key, default))
        for key, default in DEFAULT_SETTINGS.items()
    }
    settings["PANEL_HISTORY_OWNER_BINDING_VALIDATED"] = "false"
    return settings
