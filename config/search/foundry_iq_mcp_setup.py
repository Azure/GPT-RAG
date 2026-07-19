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

``queryHeaders`` is runtime-only credential-resolution metadata. This module
accepts only strict, non-secret references (managed identity/OBO scopes, a Key
Vault secret name, or ``none``), persists that canonical metadata for the
orchestrator, and never renders it into the Search knowledge-source
registration payload. Literal credentials and every ``auth`` or
``authentication`` shape are rejected before any App Configuration write.
"""

from __future__ import annotations

import ipaddress
import json
import os
import re
import sys
from typing import Any
from urllib.parse import urlsplit

MCP_KIND = "mcpServer"
MCP_PARAMS_KEY = "mcpServerParameters"

LOCAL_MAX_OUTPUT_TOKENS_CAP = 8192

ALLOWED_INCLUSION_MODES = {"reranked", "always"}
ALLOWED_OUTPUT_PARSING_MODES = {"auto", "json", "split", "none"}
ALLOWED_REASONING_EFFORTS = {"low", "medium"}
DISALLOWED_HOSTNAMES = {"localhost", "localhost.localdomain", "home.arpa"}
DISALLOWED_HOST_SUFFIXES = (
    ".localhost",
    ".local",
    ".localdomain",
    ".internal",
    ".home",
    ".home.arpa",
    ".lan",
    ".corp",
    ".intranet",
    ".private",
    ".invalid",
    ".test",
    ".example",
)

ALLOWED_SOURCE_KEYS = {
    "name",
    "description",
    "serverURL",
    "failOnError",
    "maxOutputDocuments",
    "tools",
    "queryHeaders",
}
ALLOWED_TOOL_KEYS = {"name", "outputParsing", "inclusionMode", "maxOutputTokens"}
ALLOWED_OUTPUT_PARSING_KEYS = {"kind", "jsonParameters", "splitParameters"}
ALLOWED_JSON_PARAMETER_KEYS = {"documentsPath", "includeContext"}
ALLOWED_SPLIT_PARAMETER_KEYS = {
    "textSplitMode",
    "maximumPageLength",
    "pageOverlapLength",
    "maximumPagesToTake",
    "defaultLanguageCode",
}
ALLOWED_TEXT_SPLIT_MODES = {"pages", "sentences"}
ALLOWED_QUERY_HEADER_KEYS = {"name", "valueFrom"}
ALLOWED_VALUE_FROM_KEYS = {"kind", "scope", "secretName"}
ALLOWED_VALUE_FROM_KINDS = {"managedIdentity", "obo", "keyVaultSecret", "none"}

HEADER_NAME_PATTERN = re.compile(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$")
KNOWLEDGE_SOURCE_NAME_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
KEY_VAULT_SECRET_NAME_PATTERN = re.compile(r"^[0-9A-Za-z-]{1,127}$")
DENIED_HEADER_NAMES = {
    "connection",
    "content-length",
    "host",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}

# Keys that must never appear anywhere in FOUNDRY_IQ_MCP_SOURCES_JSON, no
# matter how deeply nested, checked before any other validation runs.
# Key comparisons ignore punctuation and casing so variants such as
# ``api_key`` and ``connection-string`` cannot bypass the scan. Metadata keys
# explicitly allowed by the schema (``queryHeaders``, ``valueFrom``,
# ``secretName``, and ``scope``) do not collide with these exact normalized
# names.
SECRET_LIKE_KEYS_ANY_DEPTH = {
    "auth",
    "authentication",
    "apikey",
    "accesstoken",
    "authorizationvalue",
    "bearer",
    "clientsecret",
    "connectionstring",
    "connectionstrings",
    "cookie",
    "cookies",
    "credential",
    "credentials",
    "header",
    "headerblob",
    "headers",
    "secret",
    "secretvalue",
    "storedheaders",
    "refreshtoken",
    "token",
    "password",
    "key",
    "idtoken",
    "authorization",
    "value",
}


def _is_truthy(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "t", "yes", "y"}


def _parse_trusted_hosts(raw: Any) -> set[str]:
    if not raw:
        return set()
    if isinstance(raw, str):
        text = raw.strip()
        if text.startswith("["):
            try:
                raw = json.loads(text)
            except json.JSONDecodeError as exc:
                raise ValueError("FOUNDRY_IQ_MCP_TRUSTED_HOSTS is not valid JSON.") from exc
        else:
            raw = re.split(r"[,\r\n]+", text)
    if not isinstance(raw, (list, tuple, set)):
        raise ValueError("FOUNDRY_IQ_MCP_TRUSTED_HOSTS must be a host list.")

    hosts: set[str] = set()
    for item in raw:
        host = str(item).strip().rstrip(".").lower()
        if not host or "://" in host or "/" in host or ":" in host:
            raise ValueError(
                "FOUNDRY_IQ_MCP_TRUSTED_HOSTS entries must be hostnames only."
            )
        hosts.add(host)
    return hosts


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
    try:
        parsed = urlsplit(server_url)
        # Accessing ``port`` makes urllib validate non-numeric and out-of-range
        # ports instead of leaving them in an otherwise parseable netloc.
        _ = parsed.port
    except ValueError as exc:
        raise ValueError(f"{label}: 'serverURL' is not a valid URL.") from exc

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
    hostname_l = hostname.rstrip(".").lower()

    if (
        hostname_l in DISALLOWED_HOSTNAMES
        or hostname_l.endswith(DISALLOWED_HOST_SUFFIXES)
        or "." not in hostname_l
    ):
        raise ValueError(f"{label}: 'serverURL' must not use a local or reserved host.")

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
    if hostname_l.rsplit(".", 1)[-1].isdigit():
        raise ValueError(f"{label}: 'serverURL' must not use a local or reserved host.")

    if not trusted_hosts:
        raise ValueError(
            f"{label}: FOUNDRY_IQ_MCP_TRUSTED_HOSTS is empty. Add the exact host '{hostname}' to the "
            "allowlist before enabling this MCP source."
        )
    if hostname_l not in trusted_hosts:
        raise ValueError(
            f"{label}: 'serverURL' host '{hostname}' is not an exact match in FOUNDRY_IQ_MCP_TRUSTED_HOSTS."
        )


def _normalized_key(key: Any) -> str:
    return re.sub(r"[^a-z0-9]", "", str(key).strip().lower())


def _scan_for_disallowed_keys_anywhere(node: Any, label: str) -> None:
    """Recursively reject literal credential-shaped keys at any nesting depth.

    This runs before any other structural validation so a rejected key is
    always reported clearly, regardless of where in the JSON it appears or
    whether it also happens to be an otherwise-unexpected key.
    """

    if isinstance(node, dict):
        for key, value in node.items():
            if _normalized_key(key) in SECRET_LIKE_KEYS_ANY_DEPTH:
                raise ValueError(
                    f"{label}: key '{key}' is not allowed because literal credentials, auth objects, "
                    "stored headers, cookies, and connection strings must never appear in "
                    "FOUNDRY_IQ_MCP_SOURCES_JSON."
                )
            _scan_for_disallowed_keys_anywhere(value, f"{label}.{key}")
    elif isinstance(node, list):
        for index, item in enumerate(node):
            _scan_for_disallowed_keys_anywhere(item, f"{label}[{index}]")


def _validate_output_parsing(tool_label: str, value: Any) -> dict:
    if not isinstance(value, dict):
        raise ValueError(f"{tool_label}: 'outputParsing' must be a JSON object.")

    unexpected = set(value.keys()) - ALLOWED_OUTPUT_PARSING_KEYS
    if unexpected:
        raise ValueError(f"{tool_label}: 'outputParsing' has unexpected key(s) {sorted(unexpected)}.")

    kind = value.get("kind")
    if not isinstance(kind, str) or kind not in ALLOWED_OUTPUT_PARSING_MODES:
        raise ValueError(
            f"{tool_label}: 'outputParsing.kind' must be one of "
            f"{sorted(ALLOWED_OUTPUT_PARSING_MODES)}."
        )

    json_parameters = value.get("jsonParameters")
    split_parameters = value.get("splitParameters")
    if kind == "json":
        if split_parameters is not None:
            raise ValueError(
                f"{tool_label}: 'outputParsing.splitParameters' is only valid when kind is 'split'."
            )
        if not isinstance(json_parameters, dict):
            raise ValueError(
                f"{tool_label}: 'outputParsing.jsonParameters.documentsPath' is required "
                "when kind is 'json'."
            )
        unexpected = set(json_parameters.keys()) - ALLOWED_JSON_PARAMETER_KEYS
        if unexpected:
            raise ValueError(
                f"{tool_label}: 'outputParsing.jsonParameters' has unexpected key(s) "
                f"{sorted(unexpected)}."
            )
        documents_path = json_parameters.get("documentsPath")
        if not isinstance(documents_path, str) or not documents_path.strip():
            raise ValueError(
                f"{tool_label}: 'outputParsing.jsonParameters.documentsPath' must be a non-empty string."
            )
        canonical_json_parameters = {"documentsPath": documents_path.strip()}
        include_context = json_parameters.get("includeContext")
        if include_context is not None:
            if not isinstance(include_context, bool):
                raise ValueError(
                    f"{tool_label}: 'outputParsing.jsonParameters.includeContext' must be a boolean."
                )
            canonical_json_parameters["includeContext"] = include_context
        return {
            "kind": "json",
            "jsonParameters": canonical_json_parameters,
        }

    if json_parameters is not None:
        raise ValueError(
            f"{tool_label}: 'outputParsing.jsonParameters' is only valid when kind is 'json'."
        )
    if kind == "split":
        if split_parameters is None:
            return {"kind": "split"}
        if not isinstance(split_parameters, dict):
            raise ValueError(f"{tool_label}: 'outputParsing.splitParameters' must be a JSON object.")
        unexpected = set(split_parameters.keys()) - ALLOWED_SPLIT_PARAMETER_KEYS
        if unexpected:
            raise ValueError(
                f"{tool_label}: 'outputParsing.splitParameters' has unexpected key(s) "
                f"{sorted(unexpected)}."
            )

        canonical_split_parameters: dict[str, Any] = {}
        text_split_mode = split_parameters.get("textSplitMode")
        if text_split_mode is not None:
            if text_split_mode not in ALLOWED_TEXT_SPLIT_MODES:
                raise ValueError(
                    f"{tool_label}: 'outputParsing.splitParameters.textSplitMode' must be one of "
                    f"{sorted(ALLOWED_TEXT_SPLIT_MODES)}."
                )
            canonical_split_parameters["textSplitMode"] = text_split_mode

        for key in ("maximumPageLength", "maximumPagesToTake"):
            parameter = split_parameters.get(key)
            if parameter is not None:
                if isinstance(parameter, bool) or not isinstance(parameter, int) or parameter <= 0:
                    raise ValueError(
                        f"{tool_label}: 'outputParsing.splitParameters.{key}' must be a positive integer."
                    )
                canonical_split_parameters[key] = parameter

        page_overlap_length = split_parameters.get("pageOverlapLength")
        if page_overlap_length is not None:
            if (
                isinstance(page_overlap_length, bool)
                or not isinstance(page_overlap_length, int)
                or page_overlap_length < 0
            ):
                raise ValueError(
                    f"{tool_label}: 'outputParsing.splitParameters.pageOverlapLength' "
                    "must be a non-negative integer."
                )
            maximum_page_length = split_parameters.get("maximumPageLength")
            if maximum_page_length is not None and page_overlap_length >= maximum_page_length:
                raise ValueError(
                    f"{tool_label}: 'outputParsing.splitParameters.pageOverlapLength' "
                    "must be less than maximumPageLength."
                )
            canonical_split_parameters["pageOverlapLength"] = page_overlap_length

        default_language_code = split_parameters.get("defaultLanguageCode")
        if default_language_code is not None:
            if not isinstance(default_language_code, str) or not default_language_code.strip():
                raise ValueError(
                    f"{tool_label}: 'outputParsing.splitParameters.defaultLanguageCode' "
                    "must be a non-empty string."
                )
            canonical_split_parameters["defaultLanguageCode"] = default_language_code.strip()

        return {"kind": "split", "splitParameters": canonical_split_parameters}
    if split_parameters is not None:
        raise ValueError(
            f"{tool_label}: 'outputParsing.splitParameters' is only valid when kind is 'split'."
        )
    return {"kind": kind}


def _validate_tool(source_label: str, tool: Any, seen_tool_names: set[str]) -> dict:
    if not isinstance(tool, dict):
        raise ValueError(f"{source_label}: each tool must be a JSON object.")

    unexpected = set(tool.keys()) - ALLOWED_TOOL_KEYS
    if unexpected:
        raise ValueError(f"{source_label}: tool has unexpected key(s) {sorted(unexpected)}.")

    name_value = tool.get("name")
    if not isinstance(name_value, str) or not name_value.strip():
        raise ValueError(f"{source_label}: tool 'name' is required.")
    name = name_value.strip()
    normalized_name = name.casefold()
    if normalized_name in seen_tool_names:
        raise ValueError(f"{source_label}: tool name '{name}' is used more than once; tool names must be unique.")
    seen_tool_names.add(normalized_name)
    tool_label = f"{source_label} tool '{name}'"

    output_parsing = _validate_output_parsing(tool_label, tool.get("outputParsing"))

    inclusion_mode = tool.get("inclusionMode")
    if inclusion_mode not in ALLOWED_INCLUSION_MODES:
        raise ValueError(
            f"{tool_label}: 'inclusionMode' must be one of {sorted(ALLOWED_INCLUSION_MODES)}."
        )

    max_output_tokens = tool.get("maxOutputTokens")
    if isinstance(max_output_tokens, bool) or not isinstance(max_output_tokens, int) or max_output_tokens <= 0:
        raise ValueError(f"{tool_label}: 'maxOutputTokens' must be a positive integer.")
    if max_output_tokens > LOCAL_MAX_OUTPUT_TOKENS_CAP:
        raise ValueError(
            f"{tool_label}: 'maxOutputTokens' ({max_output_tokens}) exceeds the local cap of "
            f"{LOCAL_MAX_OUTPUT_TOKENS_CAP}."
        )
    return {
        "name": name,
        "outputParsing": output_parsing,
        "inclusionMode": inclusion_mode,
        "maxOutputTokens": max_output_tokens,
    }


def _validate_query_header(source_label: str, header: Any, seen_names: set[str]) -> dict:
    if not isinstance(header, dict):
        raise ValueError(f"{source_label}: each queryHeaders entry must be a JSON object.")

    unexpected = set(header.keys()) - ALLOWED_QUERY_HEADER_KEYS
    if unexpected:
        raise ValueError(f"{source_label}: queryHeaders entry has unexpected key(s) {sorted(unexpected)}.")

    name_value = header.get("name")
    if not isinstance(name_value, str):
        raise ValueError(f"{source_label}: query header 'name' must be a string.")
    name = name_value.strip()
    if not HEADER_NAME_PATTERN.fullmatch(name):
        raise ValueError(f"{source_label}: query header name is not a valid HTTP field name.")
    if name.lower() in DENIED_HEADER_NAMES:
        raise ValueError(f"{source_label}: query header '{name}' is not allowed.")
    if name.casefold() in seen_names:
        raise ValueError(f"{source_label}: query header names must be unique within a source.")
    seen_names.add(name.casefold())

    value_from = header.get("valueFrom")
    if not isinstance(value_from, dict):
        raise ValueError(f"{source_label}: query header 'valueFrom' must be a JSON object.")
    unexpected = set(value_from.keys()) - ALLOWED_VALUE_FROM_KEYS
    if unexpected:
        raise ValueError(
            f"{source_label}: query header 'valueFrom' has unexpected key(s) {sorted(unexpected)}."
        )

    kind = value_from.get("kind")
    if kind not in ALLOWED_VALUE_FROM_KINDS:
        raise ValueError(
            f"{source_label}: query header 'valueFrom.kind' must be one of "
            f"{sorted(ALLOWED_VALUE_FROM_KINDS)}."
        )

    scope = value_from.get("scope")
    secret_name = value_from.get("secretName")
    if kind in {"managedIdentity", "obo"}:
        if not isinstance(scope, str) or not scope.strip():
            raise ValueError(f"{source_label}: query header kind '{kind}' requires an explicit scope.")
        if any(ord(character) < 0x20 or ord(character) == 0x7F for character in scope):
            raise ValueError(f"{source_label}: query header scope contains control characters.")
        if secret_name is not None:
            raise ValueError(f"{source_label}: 'secretName' is not valid for query header kind '{kind}'.")
        canonical_value_from = {"kind": kind, "scope": scope.strip()}
    elif kind == "keyVaultSecret":
        if scope is not None:
            raise ValueError(f"{source_label}: 'scope' is not valid for query header kind 'keyVaultSecret'.")
        if not isinstance(secret_name, str) or not KEY_VAULT_SECRET_NAME_PATTERN.fullmatch(secret_name):
            raise ValueError(
                f"{source_label}: query header kind 'keyVaultSecret' requires a valid secretName."
            )
        canonical_value_from = {"kind": kind, "secretName": secret_name}
    else:
        if scope is not None or secret_name is not None:
            raise ValueError(
                f"{source_label}: query header kind 'none' must not carry scope or secretName."
            )
        canonical_value_from = {"kind": "none"}

    return {"name": name, "valueFrom": canonical_value_from}


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

    # Reject auth objects and literal credential-shaped keys anywhere in the
    # raw JSON before any structural validation runs.
    _scan_for_disallowed_keys_anywhere(sources, "FOUNDRY_IQ_MCP_SOURCES_JSON")

    trusted_hosts = _parse_trusted_hosts(context.get("FOUNDRY_IQ_MCP_TRUSTED_HOSTS"))
    reasoning_effort = str(context.get("FOUNDRY_IQ_MCP_REASONING_EFFORT") or "low").strip().lower()
    if reasoning_effort not in ALLOWED_REASONING_EFFORTS:
        raise ValueError(
            f"FOUNDRY_IQ_MCP_REASONING_EFFORT must be one of {sorted(ALLOWED_REASONING_EFFORTS)}, "
            f"got '{reasoning_effort}'. MCP knowledge sources require the query planner to run."
        )

    canonical_sources: list[dict] = []
    seen_names: set[str] = set()
    for index, source in enumerate(sources):
        label = f"FOUNDRY_IQ_MCP_SOURCES_JSON[{index}]"
        if not isinstance(source, dict):
            raise ValueError(f"{label}: must be a JSON object.")

        unexpected = set(source.keys()) - ALLOWED_SOURCE_KEYS
        if unexpected:
            raise ValueError(f"{label}: unexpected key(s) {sorted(unexpected)}.")
        # Note: 'alwaysQuerySource' is deliberately absent from
        # ALLOWED_SOURCE_KEYS, so the unexpected-key check above already
        # rejects it. MCP sources are never forced into every retrieval.

        name_value = source.get("name")
        if not isinstance(name_value, str) or not name_value.strip():
            raise ValueError(f"{label}: 'name' is required.")
        name = name_value.strip()
        if not KNOWLEDGE_SOURCE_NAME_PATTERN.fullmatch(name):
            raise ValueError(
                f"{label}: 'name' must start with a letter or number, contain only letters, "
                "numbers, '.', '_' or '-', and be at most 128 characters."
            )
        normalized_name = name.casefold()
        if normalized_name in seen_names:
            raise ValueError(f"MCP source name '{name}' is used more than once; source names must be unique.")
        seen_names.add(normalized_name)
        label = f"MCP source '{name}'"

        description_value = source.get("description")
        if description_value is not None and not isinstance(description_value, str):
            raise ValueError(f"{label}: 'description' must be a string when provided.")

        server_url_value = source.get("serverURL")
        if not isinstance(server_url_value, str) or not server_url_value.strip():
            raise ValueError(f"{label}: 'serverURL' is required.")
        server_url = server_url_value.strip()
        _validate_server_url(label, server_url, trusted_hosts)

        fail_on_error = source.get("failOnError")
        if "failOnError" in source and not isinstance(fail_on_error, bool):
            raise ValueError(f"{label}: 'failOnError' must be a boolean when provided.")

        max_output_documents = source.get("maxOutputDocuments")
        if max_output_documents is not None and (
            isinstance(max_output_documents, bool)
            or not isinstance(max_output_documents, int)
            or not 1 <= max_output_documents <= 50
        ):
            raise ValueError(
                f"{label}: 'maxOutputDocuments' must be an integer between 1 and 50 when provided."
            )

        tools = source.get("tools")
        if not isinstance(tools, list) or not tools:
            raise ValueError(f"{label}: 'tools' must be a non-empty array.")
        seen_tool_names: set[str] = set()
        canonical_tools: list[dict] = []
        for tool in tools:
            canonical_tools.append(_validate_tool(label, tool, seen_tool_names))

        query_headers = source.get("queryHeaders", [])
        if not isinstance(query_headers, list):
            raise ValueError(f"{label}: 'queryHeaders' must be an array when provided.")
        seen_header_names: set[str] = set()
        canonical_headers = [
            _validate_query_header(label, header, seen_header_names)
            for header in query_headers
        ]

        canonical_source = {
            "name": name,
            "serverURL": server_url,
            "tools": canonical_tools,
        }
        if description_value is not None:
            canonical_source["description"] = description_value.strip()
        if "failOnError" in source:
            canonical_source["failOnError"] = fail_on_error
        if "maxOutputDocuments" in source:
            canonical_source["maxOutputDocuments"] = max_output_documents
        if "queryHeaders" in source:
            canonical_source["queryHeaders"] = canonical_headers
        canonical_sources.append(canonical_source)

    return canonical_sources


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


def main(*, emit_canonical: bool = False) -> int:
    """Pre-flight CLI entry point.

    Validates FOUNDRY_IQ_MCP_SOURCES_JSON (and the other FOUNDRY_IQ_MCP_*
    environment variables) before import. With ``emit_canonical=True`` it
    writes the canonical, metadata-only source JSON to stdout for the
    PowerShell preflight to persist. Errors go to stderr without rejected
    values. This module never writes App Configuration itself.
    """

    try:
        context = build_preflight_context_from_environ()
        sources = validate_and_get_mcp_sources(context)
    except ValueError as ve:
        print(f"❗️ FOUNDRY_IQ_MCP_SOURCES_JSON validation failed: {ve}", file=sys.stderr)
        return 1
    if emit_canonical:
        print(json.dumps(sources, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(emit_canonical="--canonical" in sys.argv[1:]))
