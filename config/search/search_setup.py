#!/usr/bin/env python3
import os
import sys
import time
import json
import logging
import requests
import re
from pathlib import Path

from azure.identity import (
    AzureCliCredential,
    ManagedIdentityCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting

# ── Silence verbose logging ─────────────────────────────────────────────────
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

def load_env_file(path: str) -> dict:
    env = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env

def resolve_placeholders(obj, env_cfg, app_cfg):
    """
    Resolve placeholders of the form {A}, {A.B} or {A.B.C} in strings, dicts or lists.

    Lookup order:
      1) Single-level {A} → env_cfg[A] if exists, else app_cfg[A]
      2) Two-level  {A.B} → if app_cfg[A] is dict, return its B;
                          if it's list, find element with internal_name==B and return that element (JSON-dumped)
      3) Three-level{A.B.C} → app_cfg[A] must be list; find element with internal_name==B and return its C
    """

    if isinstance(obj, str):
        def _replace(m):
            token = m.group(1)
            parts = token.split(".")

            # --- {A} ---
            if len(parts) == 1:
                key = parts[0]
                # env_cfg override
                if key in env_cfg:
                    return env_cfg[key]
                # then app_cfg
                if key in app_cfg:
                    val = app_cfg[key]
                    if isinstance(val, (dict, list)):
                        return json.dumps(val)
                    return str(val)
                return m.group(0)

            # --- {A.B} ---
            if len(parts) == 2:
                A, B = parts
                cfg = app_cfg.get(A)

                # dict → simple lookup
                if isinstance(cfg, dict):
                    if B in cfg:
                        val = cfg[B]
                        if isinstance(val, (dict, list)):
                            return json.dumps(val)
                        return str(val)
                    return m.group(0)

                # string that might be JSON
                if isinstance(cfg, str):
                    try:
                        parsed = json.loads(cfg)
                    except json.JSONDecodeError:
                        return m.group(0)
                    cfg = parsed

                # list → find by internal_name
                if isinstance(cfg, list):
                    for elem in cfg:
                        if elem.get("internal_name") == B:
                            return json.dumps(elem)
                    return m.group(0)

                return m.group(0)

            # --- {A.B.C} ---
            if len(parts) == 3:
                A, B, C = parts
                cfg = app_cfg.get(A)

                # if string, try JSON
                if isinstance(cfg, str):
                    try:
                        cfg = json.loads(cfg)
                    except json.JSONDecodeError:
                        return m.group(0)

                # must be list
                if isinstance(cfg, list):
                    for elem in cfg:
                        if elem.get("internal_name") == B:
                            if C in elem:
                                val = elem[C]
                                if isinstance(val, (dict, list)):
                                    return json.dumps(val)
                                return str(val)
                            return m.group(0)
                return m.group(0)

            # unsupported
            return m.group(0)

        result = re.sub(r"\{([^}]+)\}", _replace, obj)
        # if something changed, resolve again in case of nested placeholders
        return resolve_placeholders(result, env_cfg, app_cfg) if result != obj else result

    # recurse into collections
    if isinstance(obj, dict):
        return {k: resolve_placeholders(v, env_cfg, app_cfg) for k, v in obj.items()}
    if isinstance(obj, list):
        return [resolve_placeholders(v, env_cfg, app_cfg) for v in obj]

    # other types untouched
    return obj

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

def execute_setup():
    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())
    ac_endpoint = os.getenv("AZURE_APP_CONFIG_ENDPOINT")
    if not ac_endpoint:
        logging.error("AZURE_APP_CONFIG_ENDPOINT not set")
        sys.exit(1)
    ac = AzureAppConfigurationClient(ac_endpoint, cred)

    # load all settings
    app_cfg = {}
    for setting in ac.list_configuration_settings(label_filter="infra"):
        try:
            app_cfg[setting.key] = json.loads(setting.value)
        except:
            app_cfg[setting.key] = setting.value

    env_cfg = load_env_file("config/search/search.env")
    defs   = json.load(open("config/search/search.json", "r"))

    # precompute indexer→datasource map
    indexers = defs.get("indexers", [])
    ds_to_indexers = {}
    for ix in indexers:
        ds_name = resolve_placeholders(ix["body"]["dataSourceName"], env_cfg, app_cfg)
        ix_name = resolve_placeholders(ix["name"], env_cfg, app_cfg)
        ds_to_indexers.setdefault(ds_name, []).append(ix_name)

    # core
    search_endpoint = app_cfg["AZURE_SEARCH_ENDPOINT"]
    api_version     = app_cfg["AZURE_SEARCH_API_VERSION"]

    # datasources: delete dependent indexers first, then recreate
    logging.info("Creating datasources...")
    for ds in defs.get("datasources", []):
        name = resolve_placeholders(ds["name"], env_cfg, app_cfg)
        body = resolve_placeholders({k: v for k, v in ds.items() if k != "name"}, env_cfg, app_cfg)
        body = {k: v for k, v in body.items() if v is not None and k not in ("identity", "encryptionKey")}

        # delete any indexers that reference this datasource
        for ix_name in ds_to_indexers.get(name, []):
            call_search_api(search_endpoint, api_version, "indexers", ix_name, "delete", cred)

        # now drop + re-create the datasource
        call_search_api(search_endpoint, api_version, "datasources", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "put",    cred, body)

    # indexes
    logging.info("Creating indexes...")
    for idx in defs.get("indexes", []):
        body = resolve_placeholders(idx, env_cfg, app_cfg)
        name = body["name"]
        call_search_api(search_endpoint, api_version, "indexes", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexes", name, "put",    cred, body)

    # skillsets
    logging.info("Creating skillsets...")
    for sk in defs.get("skillsets", []):
        body = resolve_placeholders(sk, env_cfg, app_cfg)
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
        name = resolve_placeholders(ix["name"], env_cfg, app_cfg)
        body = resolve_placeholders(ix["body"], env_cfg, app_cfg)
        call_search_api(search_endpoint, api_version, "indexers", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexers", name, "put",    cred, body)

    logging.info("All components have been provisioned.")

    # ── Seed final env values back into App Configuration ────────────────────────
    logging.info("Seeding search.env values into App Configuration…")
    for key, raw_val in env_cfg.items():
        # resolve any placeholders in the .env value
        final_val = resolve_placeholders(raw_val, env_cfg, app_cfg)
        try:
            ac.set_configuration_setting(ConfigurationSetting(key=key, value=final_val, label="infra"))
            logging.info(f"✅ Set App Config '{key}' = '{final_val}'")
        except Exception as e:
            logging.error(f"❗️ Failed to set '{key}': {e}")

if __name__ == "__main__":
    logging.info("Starting Azure Search setup.")
    t0 = time.time()
    execute_setup()
    logging.info(f"Setup completed in {round(time.time() - t0, 2)} seconds.")
