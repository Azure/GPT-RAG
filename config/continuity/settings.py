"""Public hosted-continuity settings shared by deployment publishers."""

from __future__ import annotations

from collections.abc import Mapping


FOUNDRY_TOKEN_AUDIENCE = "https://ai.azure.com"
DELEGATED_IDENTITY_HEADER = "x-ms-user-identity"
DELEGATED_IDENTITY_SOURCE = "authenticated_ui_bff_principal"
RESPONSES_PROTOCOL_VERSION = "2.0.0"
CONTINUITY_UNAVAILABLE_STATUS_CODE = "503"

DEFAULT_SETTINGS: Mapping[str, str] = {
    "HOSTED_CONTINUITY_ENABLED": "false",
    "HOSTED_CONVERSATION_OWNER_BINDING": "delegated",
    "HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED": "false",
    "HOSTED_CONVERSATION_DELEGATED_IDENTITY_HEADER": DELEGATED_IDENTITY_HEADER,
    "HOSTED_CONVERSATION_DELEGATED_IDENTITY_SOURCE": DELEGATED_IDENTITY_SOURCE,
    "HOSTED_CONVERSATIONS_TOKEN_AUDIENCE": FOUNDRY_TOKEN_AUDIENCE,
    "HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION": RESPONSES_PROTOCOL_VERSION,
    "HOSTED_CONTINUITY_UNAVAILABLE_STATUS_CODE": (
        CONTINUITY_UNAVAILABLE_STATUS_CODE
    ),
    "HOSTED_CONVERSATION_CAPABILITY_KEY_ID": "v1",
    "HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS": "900",
    "HOSTED_HISTORY_MAX_ITEMS": "100",
    "HOSTED_HISTORY_MAX_TOKENS": "32000",
    "HOSTED_HISTORY_TRUNCATION": "drop_oldest",
}


def public_settings(environment: Mapping[str, str]) -> dict[str, str]:
    """Return public settings while keeping validation-managed flags fail closed."""
    settings = {
        key: str(environment.get(key, default))
        for key, default in DEFAULT_SETTINGS.items()
    }
    settings["HOSTED_CONTINUITY_ENABLED"] = "false"
    settings["HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED"] = "false"
    return settings
