#!/usr/bin/env python3
import os
import sys
import time
import json
import logging
from pathlib import Path
import requests
from pathlib import Path

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

def load_appconfig_settings(ac_client, label_filter=None):
    """
    Reads all settings from App Configuration under given label_filter (or None for no label).
    Returns a dict: { key: parsed_value_or_string }.
    If a value is JSON (starts with { or [), attempts json.loads; on failure, keeps as string.
    """
    ctx = {}
    try:
        # you can adjust key_filter / label_filter as needed
        for setting in ac_client.list_configuration_settings(key_filter="*", label_filter=label_filter):
            raw = setting.value
            # Try parsing JSON for values that look like JSON
            parsed = None
            if isinstance(raw, str) and raw.strip().startswith(("{", "[")):
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None
            ctx[setting.key] = parsed if parsed is not None else raw
    except Exception as e:
        logging.error(f"Error listing App Configuration settings: {e}")
        sys.exit(1)
    return ctx

def prepare_context_and_render(template_name: str, template_dir: str, label_filter="gpt-rag") -> dict:
    """
    - Reads APP_CONFIG_ENDPOINT, loads settings under label_filter.
    - Parses JSON-like values.
    - Renders template_name (e.g. "search.j2") in template_dir with that context.
    - Parses the rendered result as JSON and returns as dict.
    """
    ac_endpoint = os.getenv("APP_CONFIG_ENDPOINT")
    if not ac_endpoint:
        logging.error("APP_CONFIG_ENDPOINT not set")
        sys.exit(1)

    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())
    try:
        ac_client = AzureAppConfigurationClient(ac_endpoint, cred)
    except Exception as e:
        logging.error(f"Failed to create AzureAppConfigurationClient: {e}")
        sys.exit(1)

    # 1. Load and parse settings into context
    context = load_appconfig_settings(ac_client, label_filter=label_filter)

    # 2. Setup Jinja2 environment
    env = Environment(
        loader=FileSystemLoader(template_dir),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )

    def render_and_parse_json(template_name_inner: str, ctx: dict) -> dict:
        try:
            tmpl = env.get_template(template_name_inner)
            rendered = tmpl.render(**ctx)
        except TemplateError as te:
            logging.error(f"Jinja2 rendering error for {template_name_inner}: {te}")
            sys.exit(1)

        try:
            parsed = json.loads(rendered)
        except json.JSONDecodeError as je:
            logging.error(f"Rendered JSON from {template_name_inner} is invalid: {je}\nRendered content:\n{rendered}")
            sys.exit(1)
        if not isinstance(parsed, dict):
            logging.error(f"Expected JSON object from {template_name_inner}, got: {type(parsed)}")
            sys.exit(1)
        return parsed

    # 3. Process a vars template first, e.g. setup_vars.j2
    vars_template = "search.settings.j2"
    if (Path(template_dir) / vars_template).exists():
        logging.info(f"Processing variable template {vars_template}")
        vars_dict = render_and_parse_json(vars_template, context)
        # Merge into context; note: if JSON contained nested objects, they become nested dicts
        context.update(vars_dict)

        # Seed each item of vars_dict into App Configuration
        for key, val in vars_dict.items():
            # Determine final string value
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
                logging.info(f"✅ Set App Config '{key}' = '{final_val}'")
            except Exception as e:
                logging.error(f"❗️ Failed to set '{key}': {e}")

    else:
        logging.info(f"{vars_template} not found; skipping variable template step.")

    # 4. Process the main template
    try:
        result = render_and_parse_json(template_name, context)
    except FileNotFoundError:
        logging.error(f"Template {template_name} not found in {template_dir}.")
        sys.exit(1)

    return result, context


def call_search_api(endpoint, api_version, rtype, rname, method, cred, body=None):
    token = cred.get_token("https://search.azure.com/.default").token
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = f"{endpoint}/{rtype}/{rname}?api-version={api_version}"
    resp = getattr(requests, method.lower())(url, headers=headers, json=body)
    if method.lower() == "delete" and resp.status_code == 404:
        logging.info(f"✅ {rtype.capitalize()} '{rname}' does not exist; skipping deletion.")
        return

    if resp.status_code >= 400:
        logging.warning(f"❗️ {method.upper()} {rtype}/{rname} failed {resp.status_code}: {resp.text}")
    else:
        logging.info(f"✅ {method.upper()} {rtype}/{rname} succeeded ({resp.status_code})")

def execute_setup(defs: dict, context: dict):
    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())
    # precompute indexer→datasource map
    indexers = defs.get("indexers", [])
    ds_to_indexers = {}
    for ix in indexers:
        ds_name = ix["body"]["dataSourceName"]
        ds_to_indexers.setdefault(ds_name, []).append(ix["name"])

    search_endpoint = context["SEARCH_SERVICE_QUERY_ENDPOINT"]
    api_version     = context["SEARCH_API_VERSION"]

    if not search_endpoint:
        logging.error("❗️ SEARCH_SERVICE_QUERY_ENDPOINT not found in App Configuration; skipping Azure Search setup.")
        return

    if not api_version:
        logging.error("❗️SEARCH_API_VERSION not found in search.env; skipping Azure Search setup.")
        return

    # datasources: delete dependent indexers first, then recreate
    logging.info("Creating datasources...")
    for ds in defs.get("datasources", []):
        name = ds["name"]
        body = {k: v for k, v in ds.items() if k != "name"}        

        # delete any indexers that reference this datasource
        for ix_name in ds_to_indexers.get(name, []):
            call_search_api(search_endpoint, api_version, "indexers", ix_name, "delete", cred)

        # now drop + re-create the datasource
        call_search_api(search_endpoint, api_version, "datasources", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "put",    cred, body)

    # indexes
    logging.info("Creating indexes...")
    for idx in defs.get("indexes", []):
        body = idx
        name = body["name"]
        call_search_api(search_endpoint, api_version, "indexes", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexes", name, "put",    cred, body)

    # skillsets
    logging.info("Creating skillsets...")
    for sk in defs.get("skillsets", []):
        body = sk
        for s in body.get("skills", []):
            uri = s.get("uri", "")
            if uri and not uri.startswith("http"):
                s["uri"] = "https://" + uri.lstrip("/")
        name = body["name"]
        call_search_api(search_endpoint, api_version, "skillsets", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "skillsets", name, "put",    cred, body)

    # indexers
    logging.info("Creating indexers...")
    for ix in defs.get("indexers", []):
        name = ix["name"]
        body = ix["body"]
        call_search_api(search_endpoint, api_version, "indexers", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexers", name, "put",    cred, body)

    logging.info("All components have been provisioned.")


if __name__ == "__main__":
    logging.info("🔍 Starting search rendering.")
    t0 = time.time()

    # Determine template directory and name; adjust as needed.
    # Here, assume search.j2 is in ./config/search/
    cwd = Path(os.getcwd())
    template_dir = cwd / "config" / "search"  
    template_name = "search.j2"

    if not template_dir.exists():
        logging.error(f"Template directory {template_dir} does not exist.")
        sys.exit(1)

    try:
        search_definitions, context = prepare_context_and_render(template_name, str(template_dir), label_filter="gpt-rag")
        logging.info("🔍 Search definitions rendered successfully")
        execute_setup(search_definitions, context)
    except Exception as e:
        logging.error(f"❗️ Unexpected error during execute setup: {e}")
        sys.exit(1)
    finally:
        logging.info(f"✅ Setup script finished in {round(time.time() - t0, 2)} seconds.")
