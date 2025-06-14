#!/usr/bin/env python3
"""
Simple script to associate each Container App from App Configuration
with Azure Container Registry (ACR) via its system-assigned identity.
"""

import os
import sys
import json
import logging

from azure.identity import (
    ManagedIdentityCredential,
    AzureCliCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient
from azure.mgmt.appcontainers import ContainerAppsAPIClient

# ── Silence verbose logging ─────────────────────────────────────────────────
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.appconfiguration",
    "azure.mgmt.appcontainers",
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)


def get_config_value(appconfig, key, required=True):
    """Fetch a single setting from App Configuration; exit if missing."""
    try:
        setting = appconfig.get_configuration_setting(key=key, label="gpt-rag")
        value = setting.value
    except Exception as e:
        logging.error(f"Failed to fetch '{key}': {e}")
        if required:
            sys.exit(1)
        return None

    if required and not value:
        logging.error(f"Key '{key}' not found or empty in App Configuration")
        sys.exit(1)
    return value

def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-8s %(message)s")

    endpoint = os.getenv("appConfigEndpoint")
    if not endpoint:
        logging.error("Environment variable appConfigEndpoint is not set.")
        sys.exit(1)

    # Authenticate to App Configuration and ARM
    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())
    appconfig = AzureAppConfigurationClient(endpoint, cred)

    # Read global settings
    subscription_id = get_config_value(appconfig, "subscriptionId")
    resource_group  = get_config_value(appconfig, "resourceGroupName")
    acr_name        = get_config_value(appconfig, "containerRegistryName")
    acr_server      = f"{acr_name}.azurecr.io"

    # Read and parse the list of container apps
    raw_list = get_config_value(appconfig, "containerApps")
    try:
        apps_list = json.loads(raw_list)
    except json.JSONDecodeError:
        logging.error("containerApps is not valid JSON")
        sys.exit(1)

    # Initialize Container Apps management client
    client = ContainerAppsAPIClient(cred, subscription_id)

    # Loop through each container app and update its registry config
    for entry in apps_list:
        name = entry.get("name")
        if not name:
            logging.warning("Skipping entry without 'name': %s", entry)
            continue

        logging.info("Associating ACR '%s' with Container App '%s'…", acr_server, name)
        app = client.container_apps.get(resource_group, name)

        # Set the registry to use system-assigned identity
        app.configuration.registries = [
            {"server": acr_server, "identity": "system"}
        ]

        poller = client.container_apps.begin_create_or_update(resource_group, name, app)
        poller.result()  # wait for completion

        logging.info("✅ Container App '%s' successfully updated.", name)

if __name__ == "__main__":
    main()
