#!/usr/bin/env python3
"""

Configure AI Foundry Service

- Configure RAI blocklist and policy for Azure OpenAI

This script reads configuration from Azure App Configuration, loads blocklist and policy
definitions from JSON files, and applies them to the specified Azure OpenAI deployment.

Steps:
1. Validate required env vars:
   - APP_CONFIG_ENDPOINT

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
from azure.core.exceptions import ClientAuthenticationError
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
REQUIRED_ENV_VARS = ["APP_CONFIG_ENDPOINT"]

def check_env():
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        logging.error("❗️ Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

def cfg(client: AzureAppConfigurationClient, key: str, label= 'gpt-rag', required: bool = True) -> str:
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


def validate_json_file(path: str):
    if not os.path.exists(path):
        logging.info(f"ℹ️ File not found: {path!r}. Skipping configuration.")
        sys.exit(0)

    try:
        content = open(path, "r", encoding="utf-8").read()
    except Exception as e:
        logging.info(f"ℹ️ Unable to read {path!r}: {e}. Skipping configuration.")
        sys.exit(0)

    if not content.strip():
        logging.info(f"ℹ️ File is empty: {path!r}. Skipping configuration.")
        sys.exit(0)

    try:
        json.loads(content)
    except json.JSONDecodeError as e:
        logging.info(f"ℹ️ Invalid JSON in {path!r}: {e}. Skipping configuration.")
        sys.exit(0)

def main():
    """
    Configures Responsible AI (RAI) blocklists and policies for an Azure AI Foundry deployment.

    This function performs the following steps:
      1. Checks the environment and validates required JSON configuration files.
      2. Authenticates with Azure using CLI or Managed Identity credentials.
      3. Connects to Azure App Configuration to retrieve core settings such as subscription ID, resource group, and account name.
      4. Loads the list of model deployments and selects the deployment with canonical name 'chatDeploymentName'.
      5. Creates or updates a RAI blocklist in Azure Cognitive Services, removing any existing items and adding new ones from the provided JSON.
      6. Creates or updates a RAI policy, normalizing and merging blocklist and filter settings as required.
      7. Associates the created/updated RAI policy with the selected deployment.

    Exits the process with an error message if any critical step fails (e.g., authentication, missing configuration, invalid JSON).

    Logging is used throughout to provide progress and error information.

    Raises:
        SystemExit: If authentication fails, configuration is missing or invalid, or required JSON fields are not present.
    """
    # ── 0) Validate environment and input files ──────────────────────
    check_env()

    rai_policies_json_file   = "config/aifoundry/raipolicies.json"
    rai_blocklist_json_file  = "config/aifoundry/raiblocklist.json"
    validate_json_file(rai_policies_json_file)
    validate_json_file(rai_blocklist_json_file)

    endpoint = os.environ["APP_CONFIG_ENDPOINT"]

    # ── Authenticate using Azure CLI or Managed Identity ─────────────
    try:
        cred = ChainedTokenCredential(
            AzureCliCredential(),
            ManagedIdentityCredential()
        )
    except ClientAuthenticationError as e:
        logging.error("❗️ Authentication failed: %s", e)
        logging.info("ℹ️ Skipping configuration due to missing credentials.")
        sys.exit(0)

    # connect to App Configuration
    app_conf = AzureAppConfigurationClient(endpoint, cred)

    # ── 1) Read core settings ────────────────────────────────────────
    subscription_id = cfg(app_conf, "SUBSCRIPTION_ID")
    resource_group  = cfg(app_conf, "RESOURCE_GROUP_NAME")
    account_name    = cfg(app_conf, "AI_FOUNDRY_ACCOUNT_NAME")

    logging.info("Loaded: subscriptionId=%s, resourceGroupName=%s", subscription_id, resource_group)
    logging.info("Loaded: aiFoundryAccountName=%s", account_name)

    # ── 2) Determine deployment name from list ───────────────────────
    raw_list = cfg(app_conf, "MODEL_DEPLOYMENTS")
    try:
        deployments = json.loads(raw_list)
    except json.JSONDecodeError as e:
        logging.error("MODEL_DEPLOYMENTS is not valid JSON: %s", e)
        sys.exit(1)

    canonical_name = "CHAT_DEPLOYMENT_NAME"
    deployment_name = None
    for item in deployments:
        if item.get("canonical_name") == canonical_name:
            deployment_name = item.get("name")
            break

    if not deployment_name:
        logging.error(
            "No deployment with canonical_name '%s' found in MODEL_DEPLOYMENTS",
            canonical_name
        )
        sys.exit(1)

    logging.info("Selected deployment: %s (canonical_name=%s)", deployment_name, canonical_name)

    # ── 3) Create Cognitive Services client ─────────────────────────
    client = CognitiveServicesManagementClient(cred, subscription_id)

    # names for RAI blocklist & policy
    blocklist_name = "gptragBlocklist"
    policy_name    = "gptragRAIPolicy"

    # ── 4) Blocklist creation/update ────────────────────────────────
    bl_def = load_and_replace(
        rai_blocklist_json_file,
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
        rai_policies_json_file,
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
