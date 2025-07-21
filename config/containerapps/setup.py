#!/usr/bin/env python3
"""
Simple script to associate each Container App from App Configuration
with Azure Container Registry (ACR) via its system-assigned or user-assigned identity.

Prerequisites:
- Export the environment variable APP_CONFIG_ENDPOINT with your Azure App Configuration endpoint, e.g.:
    export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
- The following keys must be present in App Configuration (label: gpt-rag):
    - SUBSCRIPTION_ID
    - RESOURCE_GROUP_NAME
    - CONTAINER_REGISTRY_NAME
    - USE_UAI
    - CONTAINER_APPS (JSON list)
- Azure CLI or Managed Identity authentication must be available.

This script will:
- Read container app definitions from Azure App Configuration.
- For each app, associate the specified Azure Container Registry (ACR) using either system-assigned or user-assigned identity.
- Update the registry configuration for each Container App in Azure.
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


def configure_logging():
    """Configure logging for Azure SDKs and the script."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-8s %(message)s")
    for logger_name in (
        "azure.core.pipeline.policies.http_logging_policy",
        "azure.identity",
        "azure.appconfiguration",
        "azure.mgmt.appcontainers",
    ):
        logging.getLogger(logger_name).setLevel(logging.WARNING)


def get_credentials():
    """Return a chained credential for Azure authentication."""
    return ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())


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


def update_container_app_registry(client, resource_group, name, acr_server, use_uai, app):
    """Update the registry configuration for a single container app."""
    if use_uai.lower() == "true":
        uai_dict = getattr(app.identity, "user_assigned_identities", None)
        if not uai_dict:
            logging.error(f"No user-assigned identity found for app '{name}'.")
            return False
        uai_resource_id = next(iter(uai_dict.keys()), None)
        if not uai_resource_id:
            logging.error(f"Could not extract resource_id from user-assigned identities for app '{name}'.")
            return False
        app.configuration.registries = [
            {"server": acr_server, "identity": uai_resource_id}
        ]
    else:
        app.configuration.registries = [
            {"server": acr_server, "identity": "system"}
        ]
    poller = client.container_apps.begin_create_or_update(resource_group, name, app)
    poller.result()  # wait for completion
    return True


def main():
    configure_logging()

    endpoint = os.getenv("APP_CONFIG_ENDPOINT")
    if not endpoint:
        logging.error("Environment variable APP_CONFIG_ENDPOINT is not set.")
        sys.exit(1)

    cred = get_credentials()
    appconfig = AzureAppConfigurationClient(endpoint, cred)

    # Read global settings
    subscription_id = get_config_value(appconfig, "SUBSCRIPTION_ID")
    resource_group = get_config_value(appconfig, "RESOURCE_GROUP_NAME")
    acr_name = get_config_value(appconfig, "CONTAINER_REGISTRY_NAME")
    use_uai = get_config_value(appconfig, "USE_UAI")
    acr_server = f"{acr_name}.azurecr.io"

    # Read and parse the list of container apps
    raw_list = get_config_value(appconfig, "CONTAINER_APPS")
    try:
        apps_list = json.loads(raw_list)
    except json.JSONDecodeError:
        logging.error("CONTAINER_APPS is not valid JSON")
        sys.exit(1)

    client = ContainerAppsAPIClient(cred, subscription_id)

    for entry in apps_list:
        name = entry.get("name")
        if not name:
            logging.warning(f"Skipping entry without 'name': {entry}")
            continue
        logging.info(f"Associating ACR '{acr_server}' with Container App '{name}'…")
        try:
            app = client.container_apps.get(resource_group, name)
            success = update_container_app_registry(client, resource_group, name, acr_server, use_uai, app)
            if success:
                logging.info(f"✅ Container App '{name}' successfully updated.")
        except Exception as e:
            logging.error(f"Failed to update Container App '{name}': {e}")


if __name__ == "__main__":
    main()
