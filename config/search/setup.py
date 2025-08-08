#!/usr/bin/env python3
"""
Azure Cognitive Search Setup Script

This script automates the provisioning and configuration of Azure Cognitive Search resources (datasources, indexes, skillsets, indexers) using definitions rendered from Jinja2 templates and values from Azure App Configuration.

Prerequisites:
- Export the environment variable APP_CONFIG_ENDPOINT with your Azure App Configuration endpoint, e.g.:
    export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
- The following keys must be present in App Configuration (label: gpt-rag):
    - SEARCH_SERVICE_QUERY_ENDPOINT
    - SEARCH_API_VERSION
    - Any other keys referenced in your Jinja2 templates
- Azure CLI or Managed Identity authentication must be available.
- The Jinja2 templates for search (search.j2, search.settings.j2) must exist and be valid in the config/search directory.

Features:
- Loads settings from Azure App Configuration (optionally filtered by label).
- Renders Jinja2 templates for search resource definitions, supporting variable expansion from App Config.
- Seeds variables from a secondary template (e.g., search.settings.j2) back into App Configuration.
- Provisions or updates Azure Search datasources, indexes, skillsets, and indexers in a safe order, cleaning up dependencies as needed.
- Handles authentication via Managed Identity or Azure CLI.
- Logs all actions and errors, and continues on non-fatal errors (fail gracefully).

Typical usage:
Run this script after provisioning your Azure Search service and App Configuration, and after updating your Jinja2 templates or App Config values.
"""

import os
import time
import json
import logging
from pathlib import Path
import requests
from typing import Any, Dict, Optional, Tuple

from azure.identity import ManagedIdentityCredential, AzureCliCredential, ChainedTokenCredential
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting
from jinja2 import Environment, FileSystemLoader, StrictUndefined, TemplateError

# ── Silence verbose logging ─────────────────────────────────────────────────
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# ── Constants ───────────────────────────────────────────────────────────────
TEMPLATE_NAME = "search.j2"
VARS_TEMPLATE = "search.settings.j2"
LABEL_FILTER = "gpt-rag"

# ── App Config Loader ───────────────────────────────────────────────────────
def load_appconfig_settings(ac_client: AzureAppConfigurationClient, label_filter: Optional[str] = None) -> Dict[str, Any]:
    """
    Reads all settings from App Configuration under given label_filter (or None for no label).
    Returns a dict: { key: parsed_value_or_string }.
    If a value is JSON (starts with { or [), attempts json.loads; on failure, keeps as string.
    """
    ctx = {}
    try:
        for setting in ac_client.list_configuration_settings(key_filter="*", label_filter=label_filter):
            raw = setting.value
            parsed = None
            if isinstance(raw, str) and raw.strip().startswith(("{", "[")):
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None
            ctx[setting.key] = parsed if parsed is not None else raw
    except Exception as e:
        logging.error(f"Error listing App Configuration settings: {e}")
    return ctx

# ── Template Rendering ─────────────────────────────────────────────────────-
def prepare_context_and_render(template_name: str, template_dir: str, label_filter: str = LABEL_FILTER) -> Tuple[Optional[dict], dict]:
    """
    Loads settings from App Config, renders templates, and returns (rendered_definitions, context).
    Returns (None, context) on fatal error.
    """
    ac_endpoint = os.getenv("APP_CONFIG_ENDPOINT")
    if not ac_endpoint:
        logging.error("APP_CONFIG_ENDPOINT not set")
        return None, {}

    cred = ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())
    try:
        ac_client = AzureAppConfigurationClient(ac_endpoint, cred)
    except Exception as e:
        logging.error(f"Failed to create AzureAppConfigurationClient: {e}")
        return None, {}

    context = load_appconfig_settings(ac_client, label_filter=label_filter)

    env = Environment(
        loader=FileSystemLoader(template_dir),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )

    def render_and_parse_json(template_name_inner: str, ctx: dict) -> Optional[dict]:
        try:
            tmpl = env.get_template(template_name_inner)
            rendered = tmpl.render(**ctx)
        except TemplateError as te:
            logging.error(f"Jinja2 rendering error for {template_name_inner}: {te}")
            return None
        try:
            parsed = json.loads(rendered)
        except json.JSONDecodeError as je:
            logging.error(f"Rendered JSON from {template_name_inner} is invalid: {je}\nRendered content:\n{rendered}")
            return None
        if not isinstance(parsed, dict):
            logging.error(f"Expected JSON object from {template_name_inner}, got: {type(parsed)}")
            return None
        return parsed

    # Process a vars template first
    vars_path = Path(template_dir) / VARS_TEMPLATE
    if vars_path.exists():
        logging.info(f"Processing variable template {VARS_TEMPLATE}")
        vars_dict = render_and_parse_json(VARS_TEMPLATE, context)
        if vars_dict:
            context.update(vars_dict)
            for key, val in vars_dict.items():
                if isinstance(val, (dict, list)):
                    final_val = json.dumps(val)
                else:
                    final_val = str(val)
                try:
                    setting = ConfigurationSetting(
                        key=key,
                        label=label_filter,
                        value=final_val,
                        content_type="text/plain"
                    )
                    ac_client.set_configuration_setting(setting)
                    logging.info(f"📝 Set App Config '{key}' = '{final_val}'")
                except Exception as e:
                    logging.error(f"❗️ Failed to set '{key}': {e}")
    else:
        logging.info(f"{VARS_TEMPLATE} not found; skipping variable template step.")

    # Process the main template
    result = render_and_parse_json(template_name, context)
    if result is None:
        logging.error(f"Template {template_name} could not be rendered or parsed.")
    logging.debug(f"Rendered definitions: {json.dumps(result, indent=2) if result else 'None'}")
    return result, context

# ── Azure Search API Call ─────────────────────────────────────────────────--
def call_search_api(endpoint: str, api_version: str, rtype: str, rname: str, method: str, cred: ChainedTokenCredential, body: Any = None) -> bool:
    try:
        token = cred.get_token("https://search.azure.com/.default").token
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        url = f"{endpoint}/{rtype}/{rname}?api-version={api_version}"
        resp = getattr(requests, method.lower())(url, headers=headers, json=body)
        if method.lower() == "delete" and resp.status_code == 404:
            logging.info(f"✅ {rtype.capitalize()} '{rname}' does not exist; skipping deletion.")
            return True
        if resp.status_code >= 400:
            logging.warning(f"❗️ {method.upper()} {rtype}/{rname} failed {resp.status_code}: {resp.text}")
            return False
        else:
            logging.info(f"✅ {method.upper()} {rtype}/{rname} succeeded ({resp.status_code})")
            return True
    except Exception as e:
        logging.error(f"❗️ Exception during {method.upper()} {rtype}/{rname}: {e}")
        return False

# ── Resource Provisioning ─────────────────────────────────────────────────--
def provision_datasources(defs: dict, context: dict, cred: ChainedTokenCredential, ds_to_indexers: dict, search_endpoint: str, api_version: str):
    logging.info("Creating datasources...")
    for ds in defs.get("datasources", []):
        name = ds["name"]
        body = {k: v for k, v in ds.items() if k != "name"}
        for ix_name in ds_to_indexers.get(name, []):
            call_search_api(search_endpoint, api_version, "indexers", ix_name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "put", cred, body)

def provision_indexes(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating indexes...")
    for idx in defs.get("indexes", []):
        body = idx
        name = body["name"]
        call_search_api(search_endpoint, api_version, "indexes", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexes", name, "put", cred, body)

def provision_skillsets(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating skillsets...")
    for sk in defs.get("skillsets", []):
        body = sk
        for s in body.get("skills", []):
            uri = s.get("uri", "")
            if uri and not uri.startswith("http"):
                s["uri"] = "https://" + uri.lstrip("/")
        name = body["name"]
        call_search_api(search_endpoint, api_version, "skillsets", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "skillsets", name, "put", cred, body)

def provision_indexers(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating indexers...")
    for ix in defs.get("indexers", []):
        name = ix["name"]
        body = ix["body"]
        call_search_api(search_endpoint, api_version, "indexers", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexers", name, "put", cred, body)

# ── Main Provisioning to AI Search elements (datasources, indexes, skillset and indexers) ─────────────────────
def execute_setup(defs: Optional[dict], context: dict):
    if defs is None:
        logging.error("No search definitions to provision. Skipping setup.")
        return
    cred = ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())
    indexers = defs.get("indexers", [])
    ds_to_indexers = {}
    for ix in indexers:
        ds_name = ix["body"]["dataSourceName"]
        ds_to_indexers.setdefault(ds_name, []).append(ix["name"])
    search_endpoint = context.get("SEARCH_SERVICE_QUERY_ENDPOINT")
    api_version = context.get("SEARCH_API_VERSION")
    if not search_endpoint:
        logging.error("❗️ SEARCH_SERVICE_QUERY_ENDPOINT not found in App Configuration; skipping Azure Search setup.")
        return
    if not api_version:
        logging.error("❗️ SEARCH_API_VERSION not found in search.env; skipping Azure Search setup.")
        return
    provision_datasources(defs, context, cred, ds_to_indexers, search_endpoint, api_version)
    provision_indexes(defs, context, cred, search_endpoint, api_version)
    provision_skillsets(defs, context, cred, search_endpoint, api_version)
    provision_indexers(defs, context, cred, search_endpoint, api_version)
    logging.info("All components have been provisioned.")

# ── Entry Point ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logging.info("🔍 Starting search rendering.")
    t0 = time.time()
    cwd = Path(os.getcwd())
    template_dir = cwd / "config" / "search"
    if not template_dir.exists():
        logging.error(f"Template directory {template_dir} does not exist.")
    else:
        search_definitions, context = prepare_context_and_render(TEMPLATE_NAME, str(template_dir), label_filter=LABEL_FILTER)
        if search_definitions is not None:
            logging.info("🔍 Search definitions rendered successfully")
        execute_setup(search_definitions, context)
    logging.info(f"✅ Setup script finished in {round(time.time() - t0, 2)} seconds.")
