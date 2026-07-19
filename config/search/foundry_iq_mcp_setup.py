"""Foundry IQ generic MCP Server knowledge source validation (preview).

MCP Server knowledge sources (kind ``mcpServer``, Search API
``2026-05-01-preview``) let a Foundry IQ knowledge base call tools exposed by
an arbitrary remote MCP server (for example, Azure Monitor MCP over
workspace-based Application Insights). Unlike the other knowledge sources in
this directory, MCP servers are attacker-reachable, operator-supplied remote
endpoints, so this module fails deployment closed (raises ``ValueError``)
instead of silently dropping a misconfigured source the way
``sharepoint_indexed_setup.filter_sharepoint_indexed_sources`` does.

This module intentionally does NOT PUT the knowledge source itself; rendering
happens through the standard ``search.j2`` template (see the
``foundry_iq_mcp_enabled`` block) and registration goes through the existing
``provision_knowledge_sources`` path in ``config/search/setup.py``. This
module owns:

1. ``is_foundry_iq_mcp_enabled`` -- the same enable gate used by the template
   and by ``setup.py``.
2. ``validate_foundry_iq_mcp_settings`` -- the single entry point called from
   ``setup.py`` before rendering. It parses and validates
   ``FOUNDRY_IQ_MCP_SOURCES_JSON``, the trusted-host allowlist, the reasoning
   effort, and the planning-model prerequisites, raising ``ValueError`` with
   an actionable message on the first problem found.
3. A standalone CLI entry point (``python -m config.search.foundry_iq_mcp_setup``)
   that validates ``FOUNDRY_IQ_MCP_SOURCES_JSON`` straight from process
   environment variables. ``scripts/postProvision.ps1`` runs this as a
   pre-flight gate, before it imports any settings into Azure App
   Configuration, so an invalid/malicious MCP source is rejected before it is
   ever persisted -- not just before the knowledge source is registered.

No MCP authentication metadata is supported by this provisioning template:
Azure AI Search's real schema for authenticating an ``mcpServer`` knowledge
source is not publicly documented, this module must not guess an unverified
REST field, and registration authentication is never rendered by
``search.j2`` regardless of what is provided here. An ``auth`` (or
``authentication``) key is therefore rejected outright, at any nesting depth,
rather than partially validated -- accepting one, even validation-only, would
mislead operators into believing it takes effect. Every MCP source in this
release relies solely on implicit managed-identity authentication (the Azure
Monitor MCP reference scenario); see ``docs/howto_grounding_mcp_server.md``.
Dynamic per-query MI/OBO credentials are out of scope here entirely -- those
are query-time control headers owned by the orchestrator repository.
"""

from __future__ import annotations

import ipaddress
import json
import os
import sys
from copy import deepcopy
from typing import Any
from urllib.parse import urlsplit

MCP_KIND = "mcpServer"
MCP_PARAMS_KEY = "mcpServerParameters"

LOCAL_MAX_OUTPUT_TOKENS_CAP = 8192

ALLOWED_INCLUSION_MODES = {"reranked", "always"}
ALLOWED_OUTPUT_PARSING_MODES = {"auto", "json", "split", "none"}
ALLOWED_REASONING_EFFORTS = {"low", "medium"}
DISALLOWED_HOSTNAMES = {"localhost"}

ALLOWED_SOURCE_KEYS = {"name", "description", "serverURL", "tools"}
ALLOWED_TOOL_KEYS = {"name", "outputParsing", "inclusionMode", "maxOutputTokens", "documentsPath"}

# Keys that must never appear anywhere in FOUNDRY_IQ_MCP_SOURCES_JSON, no
# matter how deeply nested, checked before any other validation runs.
# 'auth'/'authentication' are rejected outright (see module docstring); the
# remaining keys guard against literal credential material (API keys,
# bearer tokens, passwords, stored HTTP headers) being smuggled in under an
# unrelated or unexpected key.
DISALLOWED_AUTH_KEYS_ANY_DEPTH = {"auth", "authentication"}
SECRET_LIKE_KEYS_ANY_DEPTH = {
    "apikey",
    "secret",
    "token",
    "password",
    "key",
    "bearer",
    "header",
    "headers",
    "authorization",
    "credential",
    "credentials",
}


def _is_truthy(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "t", "yes", "y"}


def _parse_trusted_hosts(raw: Any) -> set[str]:
    if not raw:
        return set()
    parts = str(raw).replace(";", ",").replace("\n", ",").split(",")
    return {part.strip().lower() for part in parts if part.strip()}


def is_foundry_iq_mcp_enabled(context: dict) -> bool:
    """Return True when generic MCP Server knowledge sources should be
    registered on the Foundry IQ knowledge base.

    Requires the retrieval backend to be Foundry IQ and ``FOUNDRY_IQ_MCP_ENABLED``
    to be truthy. Whether ``FOUNDRY_IQ_MCP_SOURCES_JSON`` is well-formed and
    non-empty is a validation concern, not a gating concern: an operator who
    sets ``FOUNDRY_IQ_MCP_ENABLED=true`` with no (or invalid) sources must get
    a hard failure from ``validate_and_get_mcp_sources``, not a silent no-op.
    """

    if str(context.get("RETRIEVAL_BACKEND") or "").lower() != "foundry_iq":
        return False
    return _is_truthy(context.get("FOUNDRY_IQ_MCP_ENABLED"))


def _validate_server_url(label: str, server_url: str, trusted_hosts: set[str]) -> None:
    parsed = urlsplit(server_url)

    if parsed.scheme.lower() != "https":
        raise ValueError(f"{label}: 'serverURL' must use https, got scheme '{parsed.scheme or '(none)'}'.")
    if parsed.username or parsed.password:
        raise ValueError(f"{label}: 'serverURL' must not contain userinfo (a username or password).")
    if parsed.query or "?" in server_url:
        raise ValueError(f"{label}: 'serverURL' must not contain a query string.")
    if parsed.fragment:
        raise ValueError(f"{label}: 'serverURL' must not contain a fragment.")

    hostname = parsed.hostname
    if not hostname:
        raise ValueError(f"{label}: 'serverURL' is missing a host.")
    hostname_l = hostname.lower()

    if hostname_l in DISALLOWED_HOSTNAMES:
        raise ValueError(f"{label}: 'serverURL' host '{hostname}' (localhost) is not allowed.")

    try:
        ipaddress.ip_address(hostname_l.strip("[]"))
        is_ip_literal = True
    except ValueError:
        is_ip_literal = False
    if is_ip_literal:
        raise ValueError(
            f"{label}: 'serverURL' host must be a DNS hostname, not an IP literal ('{hostname}'). "
            "This blocks loopback, link-local, and other reserved IP ranges by construction."
        )

    if not trusted_hosts:
        raise ValueError(
            f"{label}: FOUNDRY_IQ_MCP_TRUSTED_HOSTS is empty. Add the exact host '{hostname}' to the "
            "allowlist before enabling this MCP source."
        )
    if hostname_l not in trusted_hosts:
        raise ValueError(
            f"{label}: 'serverURL' host '{hostname}' is not an exact match in FOUNDRY_IQ_MCP_TRUSTED_HOSTS."
        )


def _scan_for_disallowed_keys_anywhere(node: Any, label: str) -> None:
    """Recursively reject 'auth'/'authentication' and any secret-like key at
    any nesting depth within the raw MCP sources JSON.

    This runs before any other structural validation so a rejected key is
    always reported clearly, regardless of where in the JSON it appears or
    whether it also happens to be an otherwise-unexpected key.
    """

    if isinstance(node, dict):
        for key, value in node.items():
            key_l = str(key).strip().lower()
            if key_l in DISALLOWED_AUTH_KEYS_ANY_DEPTH:
                raise ValueError(
                    f"{label}: '{key}' is not supported, at any nesting depth. This provisioning "
                    "template never forwards authentication metadata into the registration payload; "
                    "every MCP source relies solely on implicit managed-identity authentication. "
                    "Remove it from FOUNDRY_IQ_MCP_SOURCES_JSON. See docs/howto_grounding_mcp_server.md."
                )
            if key_l in SECRET_LIKE_KEYS_ANY_DEPTH:
                raise ValueError(
                    f"{label}: key '{key}' must not carry literal credential material (API keys, "
                    "bearer tokens, passwords, secrets, or stored headers are not allowed anywhere in "
                    "FOUNDRY_IQ_MCP_SOURCES_JSON, at any nesting depth)."
                )
            _scan_for_disallowed_keys_anywhere(value, f"{label}.{key}")
    elif isinstance(node, list):
        for index, item in enumerate(node):
            _scan_for_disallowed_keys_anywhere(item, f"{label}[{index}]")


def _validate_tool(source_label: str, tool: Any, seen_tool_names: set[str]) -> None:
    if not isinstance(tool, dict):
        raise ValueError(f"{source_label}: each tool must be a JSON object.")

    unexpected = set(tool.keys()) - ALLOWED_TOOL_KEYS
    if unexpected:
        raise ValueError(f"{source_label}: tool has unexpected key(s) {sorted(unexpected)}.")

    name = str(tool.get("name") or "").strip()
    if not name:
        raise ValueError(f"{source_label}: tool 'name' is required.")
    if name in seen_tool_names:
        raise ValueError(f"{source_label}: tool name '{name}' is used more than once; tool names must be unique.")
    seen_tool_names.add(name)
    tool_label = f"{source_label} tool '{name}'"

    output_parsing = str(tool.get("outputParsing") or "").strip().lower()
    if output_parsing not in ALLOWED_OUTPUT_PARSING_MODES:
        raise ValueError(
            f"{tool_label}: 'outputParsing' must be one of {sorted(ALLOWED_OUTPUT_PARSING_MODES)}, "
            f"got '{output_parsing or '(none)'}'."
        )
    if output_parsing == "json" and not str(tool.get("documentsPath") or "").strip():
        raise ValueError(f"{tool_label}: 'documentsPath' is required when 'outputParsing' is 'json'.")
    if output_parsing != "json" and str(tool.get("documentsPath") or "").strip():
        raise ValueError(
            f"{tool_label}: 'documentsPath' is only valid when 'outputParsing' is 'json' (got "
            f"outputParsing='{output_parsing}'). The rendered REST payload nests 'documentsPath' under "
            "outputParsing.jsonParameters, so it has no effect for any other outputParsing kind."
        )

    inclusion_mode = str(tool.get("inclusionMode") or "").strip()
    if inclusion_mode not in ALLOWED_INCLUSION_MODES:
        raise ValueError(
            f"{tool_label}: 'inclusionMode' must be one of {sorted(ALLOWED_INCLUSION_MODES)}, "
            f"got '{inclusion_mode or '(none)'}'."
        )

    max_output_tokens = tool.get("maxOutputTokens")
    if isinstance(max_output_tokens, bool) or not isinstance(max_output_tokens, int) or max_output_tokens <= 0:
        raise ValueError(f"{tool_label}: 'maxOutputTokens' must be a positive integer.")
    if max_output_tokens > LOCAL_MAX_OUTPUT_TOKENS_CAP:
        raise ValueError(
            f"{tool_label}: 'maxOutputTokens' ({max_output_tokens}) exceeds the local cap of "
            f"{LOCAL_MAX_OUTPUT_TOKENS_CAP}."
        )
    # Note: 'alwaysQuerySource' is deliberately absent from ALLOWED_TOOL_KEYS,
    # so the unexpected-key check above already rejects it. MCP tools must
    # always go through the query planner; they are never forced in.


def validate_and_get_mcp_sources(context: dict) -> list[dict]:
    """Parse, validate, and return the configured MCP sources.

    Returns an empty list when the feature is not enabled. Raises
    ``ValueError`` with an actionable message on the first invalid field
    found when it is enabled.
    """

    if not is_foundry_iq_mcp_enabled(context):
        return []

    sources = context.get("FOUNDRY_IQ_MCP_SOURCES_JSON")
    if not isinstance(sources, list):
        raise ValueError(
            "FOUNDRY_IQ_MCP_SOURCES_JSON must be a JSON array of MCP source objects; "
            f"got {type(sources).__name__}."
        )
    if not sources:
        raise ValueError(
            "FOUNDRY_IQ_MCP_ENABLED is true but FOUNDRY_IQ_MCP_SOURCES_JSON has no sources. "
            "Add at least one MCP source or set FOUNDRY_IQ_MCP_ENABLED=false."
        )

    # Reject 'auth'/'authentication' and any secret-like key anywhere in the
    # raw JSON before any other validation runs (see module docstring).
    _scan_for_disallowed_keys_anywhere(sources, "FOUNDRY_IQ_MCP_SOURCES_JSON")

    trusted_hosts = _parse_trusted_hosts(context.get("FOUNDRY_IQ_MCP_TRUSTED_HOSTS"))
    reasoning_effort = str(context.get("FOUNDRY_IQ_MCP_REASONING_EFFORT") or "low").strip().lower()
    if reasoning_effort not in ALLOWED_REASONING_EFFORTS:
        raise ValueError(
            f"FOUNDRY_IQ_MCP_REASONING_EFFORT must be one of {sorted(ALLOWED_REASONING_EFFORTS)}, "
            f"got '{reasoning_effort}'. MCP knowledge sources require the query planner to run."
        )

    normalized_sources = deepcopy(sources)
    seen_names: set[str] = set()
    for index, source in enumerate(normalized_sources):
        label = f"FOUNDRY_IQ_MCP_SOURCES_JSON[{index}]"
        if not isinstance(source, dict):
            raise ValueError(f"{label}: must be a JSON object.")

        unexpected = set(source.keys()) - ALLOWED_SOURCE_KEYS
        if unexpected:
            raise ValueError(f"{label}: unexpected key(s) {sorted(unexpected)}.")
        # Note: 'alwaysQuerySource' is deliberately absent from
        # ALLOWED_SOURCE_KEYS, so the unexpected-key check above already
        # rejects it. MCP sources are never forced into every retrieval.

        name = str(source.get("name") or "").strip()
        if not name:
            raise ValueError(f"{label}: 'name' is required.")
        if name in seen_names:
            raise ValueError(f"MCP source name '{name}' is used more than once; source names must be unique.")
        seen_names.add(name)
        label = f"MCP source '{name}'"

        server_url = str(source.get("serverURL") or "").strip()
        if not server_url:
            raise ValueError(f"{label}: 'serverURL' is required.")
        _validate_server_url(label, server_url, trusted_hosts)

        tools = source.get("tools")
        if not isinstance(tools, list) or not tools:
            raise ValueError(f"{label}: 'tools' must be a non-empty array.")
        seen_tool_names: set[str] = set()
        for tool in tools:
            _validate_tool(label, tool, seen_tool_names)
            tool["outputParsing"] = str(tool["outputParsing"]).strip().lower()

    return normalized_sources


def validate_foundry_iq_mcp_settings(context: dict) -> None:
    """Top-level fail-closed validation entry point, called from
    ``setup.py`` right after ``validate_foundry_iq_settings``.

    Raises ``ValueError`` (aborting the whole provisioning run) when
    ``FOUNDRY_IQ_MCP_ENABLED`` is true and the configuration is invalid, or
    when no planning model is available for the knowledge base. When the
    feature is disabled this is a no-op so disabled deployments render
    exactly as before.
    """

    if not is_foundry_iq_mcp_enabled(context):
        # Do not inspect or parse stale source content while disabled. Keeping
        # the context canonical also prevents a later App Configuration write
        # from re-persisting disabled source data.
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = []
        return

    # Validate and recursively scan all source content before checking later
    # prerequisites or allowing setup.py to persist the rendered settings.
    sources = validate_and_get_mcp_sources(context)
    if not context.get("GPT_MODEL_INFO"):
        raise ValueError(
            "FOUNDRY_IQ_MCP_ENABLED is true but no chat model was found in MODEL_DEPLOYMENTS (canonical_name "
            "'CHAT_DEPLOYMENT_NAME'). MCP knowledge sources require a planning model for tool selection and "
            "argument generation."
        )
    if not context.get("FOUNDRY_IQ_AI_SERVICES_ENDPOINT"):
        raise ValueError(
            "FOUNDRY_IQ_MCP_ENABLED is true but no AI Services endpoint could be derived. Set "
            "FOUNDRY_IQ_AI_SERVICES_ENDPOINT, AI_FOUNDRY_PROJECT_ENDPOINT, or AI_FOUNDRY_ACCOUNT_NAME."
        )
    context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = sources


def _parse_env_sources_json(raw: str) -> Any:
    """Parse the raw FOUNDRY_IQ_MCP_SOURCES_JSON environment variable value.

    Used only by the standalone CLI pre-flight (below); ``setup.py`` itself
    reads already-parsed values via ``load_appconfig_settings``.
    """

    text = (raw or "").strip()
    if not text:
        return []
    try:
        return json.loads(text)
    except json.JSONDecodeError as je:
        raise ValueError(f"FOUNDRY_IQ_MCP_SOURCES_JSON is not valid JSON: {je}") from je


def build_preflight_context_from_environ() -> dict:
    """Build the minimal validation context ``validate_and_get_mcp_sources``
    needs, sourced directly from process environment variables.

    This lets this module be invoked standalone, as a provisioning
    pre-flight gate, against the operator's raw candidate settings --
    before ``scripts/postProvision.ps1`` imports anything into Azure App
    Configuration. Only the fields ``validate_and_get_mcp_sources`` reads
    are included; the planning-model/AI-Services-endpoint checks in
    ``validate_foundry_iq_mcp_settings`` need App-Configuration-derived data
    (``MODEL_DEPLOYMENTS``) that does not exist yet at this point in
    provisioning, so they are intentionally not part of this pre-flight gate
    and remain covered later by ``config.search.setup`` itself.
    """

    context = {
        "RETRIEVAL_BACKEND": os.environ.get("RETRIEVAL_BACKEND", "foundry_iq"),
        "FOUNDRY_IQ_MCP_ENABLED": os.environ.get("FOUNDRY_IQ_MCP_ENABLED", "false"),
        "FOUNDRY_IQ_MCP_SOURCES_JSON": [],
        "FOUNDRY_IQ_MCP_TRUSTED_HOSTS": os.environ.get("FOUNDRY_IQ_MCP_TRUSTED_HOSTS", ""),
        "FOUNDRY_IQ_MCP_REASONING_EFFORT": os.environ.get("FOUNDRY_IQ_MCP_REASONING_EFFORT", "low"),
    }
    # Check the explicit enablement gate before touching the raw JSON. This
    # keeps disabled provisioning independent of stale or malformed source
    # content left in the environment.
    if is_foundry_iq_mcp_enabled(context):
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = _parse_env_sources_json(
            os.environ.get("FOUNDRY_IQ_MCP_SOURCES_JSON", "[]")
        )
    return context


def main() -> int:
    """Pre-flight CLI entry point.

    Validates FOUNDRY_IQ_MCP_SOURCES_JSON (and the other FOUNDRY_IQ_MCP_*
    environment variables) exactly as they will be imported into Azure App
    Configuration, before that import happens. Prints an actionable error to
    stderr and returns a non-zero exit code on the first invalid field, and
    intentionally imports/writes nothing itself either way -- this module
    only validates.
    """

    try:
        context = build_preflight_context_from_environ()
        validate_and_get_mcp_sources(context)
    except ValueError as ve:
        print(f"❗️ FOUNDRY_IQ_MCP_SOURCES_JSON validation failed: {ve}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
