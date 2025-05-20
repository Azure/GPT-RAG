#!/usr/bin/env python3
"""
Automates RBAC role assignments in Azure using a JSON file and Azure App Configuration.

This script reads a `role-assignments.json` file containing role definitions, resolves
dynamic placeholders using values stored in Azure App Configuration, and assigns roles
using the Azure CLI.

Each entry in `role-assignments.json` must follow this format:
[
  {
    "assignee": "{AZURE_PRINCIPAL_IDS.SERVICE_ID}",
    "resourceId": "{AZURE_RESOURCE_IDS.STORAGE_ACCOUNT}",
    "roleDefinitionIdOrName": "Storage Blob Data Contributor"
  },
  {
    "assignee": "{AZURE_CONTAINER_APPS_LIST.DATA_INGEST_APP}",
    "resourceId": "{AZURE_RESOURCE_IDS.SEARCH_SERVICE}",
    "roleDefinitionIdOrName": "Contributor"
  }
]

Accepted placeholders:
- `{AZURE_PRINCIPAL_IDS.<key>}`: principalId values defined in App Configuration.
- `{AZURE_CONTAINER_APPS_LIST.<internal_name>}`: resolves to the principalId of the container app matching the internal name.
- `{AZURE_RESOURCE_IDS.<key>}`: full ARM resource IDs for Azure resources.

To know which keys are available under `AZURE_PRINCIPAL_IDS`, `AZURE_CONTAINER_APPS_LIST`, and `AZURE_RESOURCE_IDS`,
check the output section of your `main.bicep` deployment — these values are populated there.

Requirements:
- Environment variable `AZURE_APP_CONFIG_ENDPOINT` must be set.
- Authenticates via Azure CLI or Managed Identity.
"""


import os
import re
import sys
import json
import logging
import time
import subprocess

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.appconfiguration import AzureAppConfigurationClient

# ------------------------------------------------------------------------
# LOGGING CONFIGURATION
# ------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z"
)
for logger_name in (
    "azure",
    "azure.appconfiguration",
    "azure.core.pipeline.policies.http_logging_policy"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

# ------------------------------------------------------------------------
# RESOURCE TYPE MAP for ARM lookups when needed
# ------------------------------------------------------------------------
RESOURCE_TYPE_MAP = {
    'AZURE_STORAGE_ACCOUNT_NAME':            'Microsoft.Storage/storageAccounts',
    'AZURE_CONTAINER_APPS_LIST':             'Microsoft.App/containerApps',
    'AZURE_KEY_VAULT_NAME':                  'Microsoft.KeyVault/vaults',
    'AZURE_SEARCH_SERVICE_NAME':             'Microsoft.Search/searchServices',
    'AZURE_DATABASE_ACCOUNT_NAME':           'Microsoft.DocumentDB/databaseAccounts',
    'AZURE_APIM_SERVICE_NAME':               'Microsoft.ApiManagement/service',
    'AZURE_AOAI_SERVICE_NAME':               'Microsoft.CognitiveServices/accounts',
    'AZURE_AI_SERVICES_NAME':                'Microsoft.CognitiveServices/accounts',
    'AZURE_APP_CONFIG_NAME':                 'Microsoft.AppConfiguration/configurationStores',
    'AZURE_CONTAINER_REGISTRY_NAME':         'Microsoft.ContainerRegistry/registries',
    'AZURE_AI_FOUNDRY_PROJECT_NAME':         'Microsoft.MachineLearningServices/workspaces',
    'AZURE_AI_FOUNDRY_HUB_NAME':             'Microsoft.MachineLearningAIHub/hubs',
    'AZURE_AI_FOUNDRY_STORAGE_ACCOUNT_NAME': 'Microsoft.Storage/storageAccounts'
}

def get_config_value(appconfig, key, required=True):
    """Fetch a single value from App Configuration; exit if missing."""
    try:
        setting = appconfig.get_configuration_setting(key=key, label="infra")
    except Exception as e:
        logging.error(f"❗️ Failed to fetch key '{key}': {e}")
        if required:
            sys.exit(1)
        return None
    if required and (setting is None or setting.value is None):
        logging.error(f"❗️ Key '{key}' not found or has no value in App Configuration")
        sys.exit(1)
    return setting.value

def resolve_placeholder(raw, appconfig):
    """
    Resolve a single placeholder of the form:
      {A}, {A.B} or {A.B.C}

    Rules:
      {A}        → fetch key "A" from AppConfig and return its scalar value
      {A.B}      → fetch key "A"; if dict, return dict["B"]; if list, find element
                    with internal_name=="B" and return that element (as dict)
      {A.B.C}    → fetch key "A" (must be list); find element with internal_name=="B"
                    and return elem["C"] (as scalar or JSON)
    If raw is not a placeholder, return it unchanged.
    """
    if not (raw.startswith("{") and raw.endswith("}")):
        return raw

    placeholder = raw[1:-1]
    parts = placeholder.split(".")
    top = parts[0]

    # Fetch raw JSON/string from App Configuration
    raw_json = get_config_value(appconfig, top)
    try:
        cfg = json.loads(raw_json)
    except json.JSONDecodeError:
        # If it isn't JSON, treat as a plain string
        cfg = raw_json

    # {A}
    if len(parts) == 1:
        return cfg

    # {A.B}
    if len(parts) == 2:
        key2 = parts[1]
        # dict → simple lookup
        if isinstance(cfg, dict):
            if key2 in cfg:
                return cfg[key2]
            logging.error(f"❗️ Key '{key2}' not found in dict '{top}'")
            sys.exit(1)
        # list → find internal_name
        if isinstance(cfg, list):
            for elem in cfg:
                if elem.get("internal_name") == key2:
                    return elem
            logging.error(f"❗️ No element with internal_name='{key2}' in list '{top}'")
            sys.exit(1)
        logging.error(f"❗️ Unsupported type for placeholder '{raw}'")
        sys.exit(1)

    # {A.B.C}
    if len(parts) == 3:
        list_name, internal_name, attr = parts
        # reload and parse as list
        list_json = get_config_value(appconfig, list_name)
        try:
            lst = json.loads(list_json)
        except json.JSONDecodeError:
            logging.error(f"❗️ Expected JSON list under key '{list_name}' for {raw}")
            sys.exit(1)
        if not isinstance(lst, list):
            logging.error(f"❗️ Expected list under key '{list_name}' for {raw}")
            sys.exit(1)
        for elem in lst:
            if elem.get("internal_name") == internal_name:
                if attr in elem:
                    return elem[attr]
                logging.error(f"❗️ Attribute '{attr}' not found on element '{internal_name}'")
                sys.exit(1)
        logging.error(f"❗️ No element with internal_name='{internal_name}' in '{list_name}'")
        sys.exit(1)

    logging.error(f"❗️ Unsupported placeholder format '{{{placeholder}}}'")
    sys.exit(1)

def az_cli_show_id(name, group, rtype, query):
    """Run `az resource show` and extract a field via --query."""
    cmd = [
        "az", "resource", "show",
        "--name", name,
        "--resource-group", group,
        "--resource-type", rtype,
        "--query", query,
        "-o", "tsv"
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        logging.error(f"`{' '.join(cmd)}` failed: {proc.stderr.strip()}")
        sys.exit(1)
    return proc.stdout.strip()

def get_resource_id_for(name, group, rtype):
    return az_cli_show_id(name, group, rtype, "id")

def assign_role(principal_object_id, role, scope, rg_name=None, account_name=None):
    """
    Assign either a control-plane role via `az role assignment create`
    or a Cosmos DB data-plane role via `az cosmosdb sql role assignment create`.
    """
    # Detect Cosmos-DB data-plane
    if "Microsoft.DocumentDB/databaseAccounts" in scope \
       and role.lower().startswith("cosmos db built-in data"):
        if not rg_name or not account_name:
            logging.error("❗️ rg_name and account_name required for Cosmos data-plane role")
            sys.exit(1)
        cmd = [
            "az", "cosmosdb", "sql", "role", "assignment", "create",
            "--account-name", account_name,
            "--resource-group", rg_name,
            "--role-definition-id", "00000000-0000-0000-0000-000000000002",
            "--scope", "/",
            "--principal-id", principal_object_id
        ]
    else:
        cmd = [
            "az", "role", "assignment", "create",
            "--assignee-object-id", principal_object_id,
            "--role", role,
            "--scope", scope
        ]

    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        logging.error(f"❗️ Failed to assign {role} to {principal_object_id} on {scope}: {proc.stderr.strip()}")
        sys.exit(1)
    logging.info(f"✅ {role} → {principal_object_id} @ {scope}")

def setup_rbac():
    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())
    endpoint = os.environ.get("AZURE_APP_CONFIG_ENDPOINT")
    if not endpoint:
        logging.error("❗️ Environment variable 'AZURE_APP_CONFIG_ENDPOINT' is not set.")
        sys.exit(1)
    appconfig = AzureAppConfigurationClient(endpoint, cred)

    sub_id = get_config_value(appconfig, "AZURE_SUBSCRIPTION_ID")
    rg     = get_config_value(appconfig, "AZURE_RESOURCE_GROUP")

    base = os.path.dirname(__file__)
    path = os.path.join(base, "role-assignments.json")
    with open(path, "r") as f:
        definitions = json.load(f)

    for defn in definitions:
        raw_assignee = defn["assignee"]
        raw_resource = defn["resourceId"]
        role         = defn["roleDefinitionIdOrName"]

        # Resolve assignee → either item dict or string
        assignee_resolved = resolve_placeholder(raw_assignee, appconfig)
        if isinstance(assignee_resolved, dict):
            principal_id = assignee_resolved.get("principalId")
        else:
            principal_id = assignee_resolved

        # Resolve resource → either ARM ID string or dict(name)
        resource_resolved = resolve_placeholder(raw_resource, appconfig)
        if isinstance(resource_resolved, str):
            resource_id = resource_resolved
        else:
            # must be dict with {"name": ...}
            var = raw_resource[1:-1].split(".",1)[0]
            rtype = RESOURCE_TYPE_MAP.get(var)
            if not rtype:
                logging.error(f"❗️ No RESOURCE_TYPE_MAP entry for '{var}'")
                sys.exit(1)
            resource_id = get_resource_id_for(resource_resolved["name"], rg, rtype)

        # Cosmos DB special handling for data-plane
        cosmos_rg = cosmos_account = None
        if "Microsoft.DocumentDB/databaseAccounts" in resource_id:
            parts = resource_id.split("/")
            cosmos_rg      = parts[parts.index("resourceGroups")+1]
            cosmos_account = parts[-1]

        assign_role(principal_id, role, resource_id, cosmos_rg, cosmos_account)

def main():
    logging.info("Starting RBAC setup…")
    start = time.time()
    setup_rbac()
    logging.info(f"🎉 RBAC setup finished in {round(time.time() - start, 2)}s")

if __name__ == "__main__":
    main()
