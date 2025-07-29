#!/usr/bin/env python3
"""
AI Foundry Service Configuration Script

This script automates the configuration of Responsible AI (RAI) blocklists and policies for an Azure OpenAI deployment, and securely stores the model API key in Azure Key Vault for use with evaluation workflows.

Prerequisites:
- Export the environment variable APP_CONFIG_ENDPOINT with your Azure App Configuration endpoint, e.g.:
    export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
- The following keys must be present in App Configuration (label: gpt-rag):
    - SUBSCRIPTION_ID
    - RESOURCE_GROUP_NAME
    - AI_FOUNDRY_ACCOUNT_NAME
    - MODEL_DEPLOYMENTS (JSON list)
    - KEY_VAULT_URI
- The JSON files for blocklist and policy must exist and be valid:
    - config/aifoundry/raipolicies.json
    - config/aifoundry/raiblocklist.json
- Azure CLI or Managed Identity authentication must be available.

Features:
- Loads configuration values from Azure App Configuration (subscription, resource group, account, deployment, Key Vault URI, etc).
- Reads RAI blocklist and policy definitions from JSON files and applies them to the specified Azure OpenAI (Cognitive Services) resource.
- Creates or updates the RAI blocklist and its items, ensuring the blocklist is always in sync with the provided JSON.
- Creates or updates the RAI policy, associates it with the deployment, and normalizes policy structure as needed.
- Fetches the Azure OpenAI (AI Foundry) model API key and stores it as a secret in Azure Key Vault, enabling secure integration with AI Foundry Evaluation tools and workflows.

Typical use case:
Run this script after provisioning your Azure OpenAI resource and before running evaluation jobs that require access to the model API key via Key Vault.
"""

import os
import sys
import json
import logging
from typing import Any, Dict, Optional

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
from .keyvault import KeyVaultClient

# ── Constants ─────────────────────────────────────────
REQUIRED_ENV_VARS = ["APP_CONFIG_ENDPOINT"]
BLOCKLIST_NAME = "gptragBlocklist"
POLICY_NAME = "gptragRAIPolicy"
RAI_POLICIES_JSON_FILE = "config/aifoundry/raipolicies.json"
RAI_BLOCKLIST_JSON_FILE = "config/aifoundry/raiblocklist.json"
CANONICAL_DEPLOYMENT_NAME = "CHAT_DEPLOYMENT_NAME"
SECRET_NAME = "evaluationsModelApiKey"

# ── Logging ───────────────────────────────────────────
def configure_logging():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    for logger_name in (
        "azure.core.pipeline.policies.http_logging_policy",
        "azure.identity",
        "azure.mgmt"
    ):
        logging.getLogger(logger_name).setLevel(logging.WARNING)

# ── Environment Validation ────────────────────────────
def check_env() -> None:
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        logging.error("❗️ Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

# ── Azure App Config Helper ───────────────────────────
def cfg(client: AzureAppConfigurationClient, key: str, label: str = 'gpt-rag', required: bool = True) -> str:
    """Fetch a single value from App Configuration; exit if missing or empty."""
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

# ── JSON File Utilities ───────────────────────────────
def load_and_replace(path: str, replacements: Dict[str, str]) -> Dict[str, Any]:
    """Load a JSON file, apply replacements, and parse it."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
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

def validate_json_file(path: str) -> None:
    """Validate that a JSON file exists, is readable, and is valid JSON."""
    if not os.path.exists(path):
        logging.error(f"❗️ File not found: {path!r}. Aborting configuration.")
        sys.exit(1)
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        logging.error(f"❗️ Unable to read {path!r}: {e}. Aborting configuration.")
        sys.exit(1)
    if not content.strip():
        logging.error(f"❗️ File is empty: {path!r}. Aborting configuration.")
        sys.exit(1)
    try:
        json.loads(content)
    except json.JSONDecodeError as e:
        logging.error(f"❗️ Invalid JSON in {path!r}: {e}. Aborting configuration.")
        sys.exit(1)

# ── Azure Authentication ──────────────────────────────
def get_azure_credential() -> ChainedTokenCredential:
    """Get Azure credential (Managed Identity preferred, fallback to CLI)."""
    return ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())

# ── Key Vault Helper ─────────────────────────────────
def add_ai_foundry_account_api_key_to_key_vault(
    mgmt_client: CognitiveServicesManagementClient,
    resource_group: str,
    account_name: str,
    vault_uri: str,
    secret_name: str
) -> None:
    """Fetches the AI Foundry Account API key and stores it in Azure Key Vault."""
    try:
        logging.info("🔑 Fetching AI Foundry Account API key for account %s ...", account_name)
        keys = mgmt_client.accounts.list_keys(resource_group, account_name)
        api_key = keys.key1
        logging.info("🔒 Storing API key in Key Vault at %s ...", vault_uri)
        kv_client = KeyVaultClient(vault_uri)
        kv_client.set_secret(secret_name, api_key)
        logging.info("✅ Secret %s set successfully in Key Vault.", secret_name)
    except Exception as e:
        logging.error("❗️ Failed to set secret in Key Vault: %s", e)

# ── Blocklist Logic ──────────────────────────────────
def configure_blocklist(client: CognitiveServicesManagementClient, resource_group: str, account_name: str, bl_def: Dict[str, Any], bl_name: str) -> None:
    """Create or update the RAI blocklist and its items."""
    try:
        logging.info(f"📑 Creating/updating blocklist {bl_name} …")
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
        # Remove existing items
        for existing in client.rai_blocklist_items.list(resource_group, account_name, bl_name):
            logging.info(f"🗑️ Deleting blocklist item: {existing.name}")
            client.rai_blocklist_items.delete(
                resource_group_name=resource_group,
                account_name=account_name,
                rai_blocklist_name=bl_name,
                rai_blocklist_item_name=existing.name
            )
        # Re-add items
        for idx, item in enumerate(bl_def.get("blocklistItems", [])):
            pat = item.get("pattern", "") or ""
            if not pat.strip():
                logging.warning(f"⚠️ Skipping blocklist item {idx}: empty pattern")
                continue
            item_name = f"{bl_name}Item{idx}"
            logging.info(f"➕ Adding blocklist item {item_name} …")
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
    except Exception as e:
        logging.error(f"❗️ Blocklist configuration failed: {e}")
        sys.exit(1)

# ── Policy Logic ─────────────────────────────────────
def configure_policy(client: CognitiveServicesManagementClient, resource_group: str, account_name: str, pol_def: Dict[str, Any], bl_name: str, policy_name: str) -> str:
    """Create or update the RAI policy and return its name."""
    try:
        p_name = pol_def.get("name")
        if not p_name:
            logging.error("❗️ Policy JSON must have top-level 'name'.")
            sys.exit(1)
        props = pol_def["properties"]
        prompt_bl = props.pop("promptBlocklists", [])
        comp_bl = props.pop("completionBlocklists", [])
        for x in prompt_bl: x["source"] = "Prompt"
        for x in comp_bl: x["source"] = "Completion"
        props["customBlocklists"] = prompt_bl + comp_bl
        # Normalize casing
        for f in props.get("contentFilters", []):
            if "allowedContentLevel" in f:
                lvl = f.pop("allowedContentLevel")
                f["severityThreshold"] = lvl.capitalize()
            if "source" in f:
                f["source"] = f["source"].capitalize()
        if "mode" in props:
            props["mode"] = props["mode"].capitalize()
        logging.info(f"📑 Creating/updating policy {p_name} …")
        client.rai_policies.create_or_update(
            resource_group_name=resource_group,
            account_name=account_name,
            rai_policy_name=p_name,
            rai_policy={"properties": props}
        )
        return p_name
    except Exception as e:
        logging.error(f"❗️ Policy configuration failed: {e}")
        sys.exit(1)

# ── Deployment Association ───────────────────────────
def associate_policy_to_deployment(client: CognitiveServicesManagementClient, resource_group: str, account_name: str, deployment_name: str, policy_name: str) -> None:
    """Associate the RAI policy to the deployment."""
    try:
        logging.info(f"🔗 Associating policy {policy_name} with deployment {deployment_name} …")
        existing = client.deployments.get(resource_group, account_name, deployment_name)
        dep_dict = existing.as_dict()
        dep_dict["properties"]["raiPolicyName"] = policy_name
        client.deployments.begin_create_or_update(
            resource_group_name=resource_group,
            account_name=account_name,
            deployment_name=deployment_name,
            deployment=dep_dict
        ).result()
    except Exception as e:
        logging.error(f"❗️ Failed to associate policy to deployment: {e}")
        sys.exit(1)

# ── Main Logic ───────────────────────────────────────
def main() -> None:
    configure_logging()
    check_env()
    validate_json_file(RAI_POLICIES_JSON_FILE)
    validate_json_file(RAI_BLOCKLIST_JSON_FILE)
    endpoint = os.environ["APP_CONFIG_ENDPOINT"]
    cred = get_azure_credential()
    try:
        scope = f"{endpoint}/.default"
        cred.get_token(scope)
    except ClientAuthenticationError as e:
        logging.error("❗️ Authentication failed: %s", e)
        logging.error("ℹ️ Aborting configuration due to missing credentials.")
        sys.exit(1)
    app_conf = AzureAppConfigurationClient(endpoint, cred)
    subscription_id = cfg(app_conf, "SUBSCRIPTION_ID")
    resource_group = cfg(app_conf, "RESOURCE_GROUP_NAME")
    account_name = cfg(app_conf, "AI_FOUNDRY_ACCOUNT_NAME")
    logging.info(f"Loaded: subscriptionId={subscription_id}, resourceGroupName={resource_group}")
    logging.info(f"Loaded: aiFoundryAccountName={account_name}")
    # Determine deployment name from list
    raw_list = cfg(app_conf, "MODEL_DEPLOYMENTS")
    try:
        deployments = json.loads(raw_list)
    except json.JSONDecodeError as e:
        logging.error("MODEL_DEPLOYMENTS is not valid JSON: %s", e)
        sys.exit(1)
    deployment_name: Optional[str] = None
    for item in deployments:
        if item.get("canonical_name") == CANONICAL_DEPLOYMENT_NAME:
            deployment_name = item.get("name")
            break
    if not deployment_name:
        logging.error(
            "No deployment with canonical_name '%s' found in MODEL_DEPLOYMENTS",
            CANONICAL_DEPLOYMENT_NAME
        )
        sys.exit(1)
    logging.info(f"Selected deployment: {deployment_name} (canonical_name={CANONICAL_DEPLOYMENT_NAME})")
    client = CognitiveServicesManagementClient(cred, subscription_id)
    # Blocklist
    bl_def = load_and_replace(
        RAI_BLOCKLIST_JSON_FILE,
        {"{{BlocklistName}}": BLOCKLIST_NAME}
    )
    bl_name = bl_def.get("name") or bl_def.get("blocklistname")
    if not bl_name:
        logging.error("❗️ Blocklist JSON must have top-level 'name' or 'blocklistname'.")
        sys.exit(1)
    configure_blocklist(client, resource_group, account_name, bl_def, bl_name)
    # Policy
    pol_def = load_and_replace(
        RAI_POLICIES_JSON_FILE,
        {
            "{{PolicyName}}": POLICY_NAME,
            "{{BlocklistName}}": bl_name
        }
    )
    p_name = configure_policy(client, resource_group, account_name, pol_def, bl_name, POLICY_NAME)
    # Associate policy to deployment
    associate_policy_to_deployment(client, resource_group, account_name, deployment_name, p_name)
    # Store API key in Key Vault
    logging.info("🔑 Adding AI Foundry Account API Key to Key Vault …")
    key_vault_uri = cfg(app_conf, "KEY_VAULT_URI")
    add_ai_foundry_account_api_key_to_key_vault(
        client,
        resource_group,
        account_name,
        key_vault_uri,
        SECRET_NAME
    )
    logging.info("✅ RAI blocklist, policy, deployment association, and secret injection complete.")

if __name__ == "__main__":
    main()
