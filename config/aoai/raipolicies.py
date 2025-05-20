#!/usr/bin/env python3
"""
Configure RAI blocklist and policy for Azure OpenAI

This script reads configuration from Azure App Configuration, loads blocklist and policy
definitions from JSON files, and applies them to the specified Azure OpenAI deployment.

Steps:
1. Validate required env vars:
   - AZURE_APP_CONFIG_ENDPOINT

2. Authenticate via Azure CLI or Managed Identity

3. Load core settings from App Configuration:
   - Subscription ID, Resource Group, Service & Deployment Names

4. Create or update RAI blocklist and items

5. Create or update RAI policy and associate it with the deployment
"""

import os
import sys
import json
import logging

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.appconfiguration import AzureAppConfigurationClient
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
from azure.mgmt.cognitiveservices.models import (
    RaiBlocklist,
    RaiBlocklistProperties,
    RaiBlocklistItem,
    RaiBlocklistItemProperties
)

# ── configure logging ─────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.mgmt"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

# ── required env vars ───────────────────────────────────────────
REQUIRED_ENV_VARS = ["AZURE_APP_CONFIG_ENDPOINT"]

def check_env():
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        logging.error("❗️ Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

def cfg(client: AzureAppConfigurationClient, key: str, label= 'infra', required: bool = True) -> str:
    """
    Fetch a single value from App Configuration; exit if missing or empty.
    """
    try:
        setting = client.get_configuration_setting(key=key, label=label)
    except Exception as e:
        logging.error("❗️ Could not fetch key '%s': %s", key, e)
        if required:
            sys.exit(1)
        return ""
    if required and (setting is None or not setting.value):
        logging.error("❗️ Key '%s' not found or empty in App Configuration", key)
        sys.exit(1)
    return setting.value

def load_and_replace(path: str, replacements: dict) -> dict:
    try:
        raw = open(path, "r", encoding="utf-8").read()
    except OSError as e:
        logging.error("❗️ Unable to open %s: %s", path, e)
        sys.exit(1)

    for ph, val in replacements.items():
        raw = raw.replace(ph, val)

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        logging.error("❗️ Failed to parse JSON in %s: %s", path, e)
        sys.exit(1)

def main():
    check_env()
    endpoint = os.environ["AZURE_APP_CONFIG_ENDPOINT"]

    # authenticate using CLI or Managed Identity
    cred = ChainedTokenCredential(
        AzureCliCredential(),
        ManagedIdentityCredential()
    )

    # connect to App Configuration
    app_conf = AzureAppConfigurationClient(endpoint, cred)

    # ── 1) Read core settings ────────────────────────────────────────
    subscription_id = cfg(app_conf, "AZURE_SUBSCRIPTION_ID")
    resource_group  = cfg(app_conf, "AZURE_RESOURCE_GROUP")
    account_name    = cfg(app_conf, "AZURE_AOAI_SERVICE_NAME")

    logging.info("Loaded: SUBSCRIPTION_ID=%s, RESOURCE_GROUP=%s", subscription_id, resource_group)
    logging.info("Loaded: SERVICE_NAME=%s", account_name)

    # ── 2) Determine deployment name from list ───────────────────────
    raw_list = cfg(app_conf, "AZURE_AOAI_DEPLOYMENT_LIST")
    try:
        deployments = json.loads(raw_list)
    except json.JSONDecodeError as e:
        logging.error("AZURE_AOAI_DEPLOYMENT_LIST is not valid JSON: %s", e)
        sys.exit(1)

    internal_key = "AZURE_CHAT_DEPLOYMENT_NAME"
    deployment_name = None
    for item in deployments:
        if item.get("internal_name") == internal_key:
            deployment_name = item.get("name")
            break

    if not deployment_name:
        logging.error(
            "No deployment with internal_name '%s' found in AZURE_AOAI_DEPLOYMENT_LIST",
            internal_key
        )
        sys.exit(1)

    logging.info("Selected deployment: %s (internal_name=%s)", deployment_name, internal_key)

    # ── 3) Create Cognitive Services client ─────────────────────────
    client = CognitiveServicesManagementClient(cred, subscription_id)

    # names for RAI blocklist & policy
    blocklist_name = "gptragBlocklist"
    policy_name    = "gptragRAIPolicy"

    # ── 4) Blocklist creation/update ────────────────────────────────
    bl_def = load_and_replace(
        "config/aoai/raiblocklist.json",
        {"{{BlocklistName}}": blocklist_name}
    )
    bl_name = bl_def.get("name") or bl_def.get("blocklistname")
    if not bl_name:
        logging.error("❗️ Blocklist JSON must have top-level 'name' or 'blocklistname'.")
        sys.exit(1)

    logging.info("Creating/updating blocklist %s …", bl_name)
    client.rai_blocklists.create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        rai_blocklist_name=bl_name,
        rai_blocklist=RaiBlocklist(
            properties=RaiBlocklistProperties(
                description=bl_def.get("description", "")
            )
        )
    )

    # remove existing items
    for existing in client.rai_blocklist_items.list(resource_group, account_name, bl_name):
        client.rai_blocklist_items.delete(
            resource_group_name=resource_group,
            account_name=account_name,
            rai_blocklist_name=bl_name,
            rai_blocklist_item_name=existing.name
        )

    # re-add items
    for idx, item in enumerate(bl_def.get("blocklistItems", [])):
        pat = item.get("pattern", "") or ""
        if not pat.strip():
            logging.warning("Skipping blocklist item %d: empty pattern", idx)
            continue

        item_name = f"{bl_name}Item{idx}"
        logging.info("Adding blocklist item %s …", item_name)
        client.rai_blocklist_items.create_or_update(
            resource_group_name=resource_group,
            account_name=account_name,
            rai_blocklist_name=bl_name,
            rai_blocklist_item_name=item_name,
            rai_blocklist_item=RaiBlocklistItem(
                properties=RaiBlocklistItemProperties(
                    pattern=pat,
                    is_regex=item.get("isRegex", False)
                )
            )
        )

    # ── 4) RAI policy creation/update ────────────────────────────────
    pol_def = load_and_replace(
        "config/aoai/raipolicies.json",
        {
            "{{PolicyName}}": policy_name,
            "{{BlocklistName}}": bl_name
        }
    )
    p_name = pol_def.get("name")
    if not p_name:
        logging.error("❗️ Policy JSON must have top-level 'name'.")
        sys.exit(1)

    props     = pol_def["properties"]
    prompt_bl = props.pop("promptBlocklists", [])
    comp_bl   = props.pop("completionBlocklists", [])
    for x in prompt_bl: x["source"] = "Prompt"
    for x in comp_bl:   x["source"] = "Completion"
    props["customBlocklists"] = prompt_bl + comp_bl

    # normalize casing
    for f in props.get("contentFilters", []):
        if "allowedContentLevel" in f:
            lvl = f.pop("allowedContentLevel")
            f["severityThreshold"] = lvl.capitalize()
        if "source" in f:
            f["source"] = f["source"].capitalize()
    if "mode" in props:
        props["mode"] = props["mode"].capitalize()

    logging.info("Creating/updating policy %s …", p_name)
    client.rai_policies.create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        rai_policy_name=p_name,
        rai_policy={"properties": props}
    )

    # ── 5) Associate policy to deployment ─────────────────────────────
    logging.info("Associating policy %s with deployment %s …", p_name, deployment_name)
    existing = client.deployments.get(resource_group, account_name, deployment_name)
    dep_dict = existing.as_dict()
    dep_dict["properties"]["raiPolicyName"] = p_name

    client.deployments.begin_create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        deployment_name=deployment_name,
        deployment=dep_dict
    ).result()

    logging.info("RAI blocklist, policy, and deployment association complete.")

if __name__ == "__main__":
    main()
