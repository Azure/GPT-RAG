#!/usr/bin/env python3
"""
Simple script to associate each Container App from App Configuration
with Azure Container Registry (ACR) via its system-assigned or user-assigned identity.

Prerequisites:
- Export the environment variable APP_CONFIG_ENDPOINT with your Azure App Configuration endpoint, e.g.:
    export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
- The following keys must be present in App Configuration (label: gpt-rag):
    - SUBSCRIPTION_ID
    - AZURE_RESOURCE_GROUP
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
import time

from azure.identity import (
    ManagedIdentityCredential,
    AzureCliCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient
from azure.mgmt.appcontainers import ContainerAppsAPIClient


POLL_TIMEOUT_SECONDS = int(os.getenv("CONTAINER_APP_POLL_TIMEOUT_SECONDS", "600"))


def _get_desired_identity(app, app_name, use_uai):
    """Return the identity string/resource id we expect to use for registry auth."""
    if use_uai.lower() == "true":
        uai_dict = getattr(app.identity, "user_assigned_identities", None)
        if not uai_dict:
            logging.error(f"No user-assigned identity found for app '{app_name}'.")
            return None
        return next(iter(uai_dict.keys()), None)
    return "system"


def _registry_matches(app, server, desired_identity):
    registries = getattr(app.configuration, "registries", None) or []
    for reg in registries:
        reg_server = reg.get("server") if isinstance(reg, dict) else getattr(reg, "server", None)
        if reg_server != server:
            continue
        reg_identity = reg.get("identity") if isinstance(reg, dict) else getattr(reg, "identity", None)
        if desired_identity == "system" and reg_identity in (None, "system"):
            return True
        if desired_identity and reg_identity == desired_identity:
            return True
    return False


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


def get_config_value(appconfig, key, required=True, max_retries=3):
    for attempt in range(max_retries):
        try:
            setting = appconfig.get_configuration_setting(key=key, label="gpt-rag")
            return setting.value
        except Exception as e:
            if attempt == max_retries - 1:
                logging.error(f"Failed to fetch '{key}' after {max_retries} attempts: {e}")
                if required:
                    sys.exit(1)
                return None
            else:
                logging.warning(f"Attempt {attempt + 1} failed for '{key}', retrying...")
                time.sleep(2)
                # Recreate credential on retry
                credential = ChainedTokenCredential(
                    ManagedIdentityCredential(),
                    AzureCliCredential()
                )
                appconfig._credential = credential


def update_container_app_registry(client, resource_group, name, acr_server, use_uai, app):
    """Update the registry configuration for a single container app."""
    desired_identity = _get_desired_identity(app, name, use_uai)
    if not desired_identity:
        return False

    if _registry_matches(app, acr_server, desired_identity):
        logging.info(f"Registry already configured for app '{name}', skipping update.")
        return True

    app.configuration.registries = [
        {"server": acr_server, "identity": desired_identity}
    ]
    poller = client.container_apps.begin_create_or_update(resource_group, name, app)
    try:
        poller.result(timeout=POLL_TIMEOUT_SECONDS)
    except Exception as exc:  # noqa: BLE001 - surface timeout text but continue
        message = str(exc).lower()
        if "timeout" in message or "did not complete" in message:
            logging.info(
                "Container App '%s' did not finish provisioning within %s seconds; moving to the next app.",
                name,
                POLL_TIMEOUT_SECONDS,
            )
            return False
        raise
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
    resource_group = get_config_value(appconfig, "AZURE_RESOURCE_GROUP")
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
