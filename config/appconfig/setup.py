#!/usr/bin/env python

"""
Seed all ARM deployment outputs to Azure App Configuration

This script fetches every output from a specified ARM deployment and writes
each one as its own key/value in Azure App Configuration. Special case: if
an output value is a list of dicts and any dict has 'canonical_name', we also
create individual settings for each such dict, with key=item['canonical_name']
and value=item['name'].
"""
import os
import sys
import json
import logging

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.core.exceptions import ClientAuthenticationError, ResourceNotFoundError
from azure.mgmt.resource import ResourceManagementClient
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting

# suppress verbose HTTP logs
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
for name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.mgmt.resource",
    "azure.appconfiguration"
):
    logging.getLogger(name).setLevel(logging.WARNING)

REQUIRED_ENV_VARS = [
    "subscriptionId",
    "resourceGroupName",
    "deploymentName",
    "APP_CONFIG_ENDPOINT"
]

def check_env_vars():
    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        logging.error("❗️ Missing environment variables: %s", ", ".join(missing))
        sys.exit(1)

def main():
    check_env_vars()
    sub_id = os.environ["subscriptionId"]
    rg = os.environ["resourceGroupName"]
    deployment = os.environ["deploymentName"]
    endpoint = os.environ["APP_CONFIG_ENDPOINT"]

    logging.info("Seeding App Configuration at %s for deployment %s/%s", endpoint, rg, deployment)

    # authenticate
    try:
        cred = ChainedTokenCredential(
            AzureCliCredential(),
            ManagedIdentityCredential()
        )
    except ClientAuthenticationError as e:
        logging.error("❗️ Authentication failed: %s", e)
        logging.info("ℹ️ Skipping configuration due to missing credentials.")
        sys.exit(0)

    resource_client = ResourceManagementClient(cred, sub_id)

    # fetch ARM outputs
    try:
        deployment_res = resource_client.deployments.get(rg, deployment)
        raw_outputs = deployment_res.properties.outputs or {}
    except ResourceNotFoundError:
        logging.error("❌ Deployment '%s' not found in resource group '%s'. Exiting.", deployment, rg)
        sys.exit(1)

    if not raw_outputs:
        logging.warning("⚠️ No outputs found for deployment '%s' in resource group '%s'. Nothing to seed.", deployment, rg)
        sys.exit(0)

    client = AzureAppConfigurationClient(endpoint, cred)
    logging.info("Found %d outputs to seed", len(raw_outputs))

    for key, out in raw_outputs.items():
        if not isinstance(out, dict) or "value" not in out:
            logging.warning("Skipping %s: no 'value' field", key)
            continue

        if key == "APP_CONFIG_ENDPOINT":
            logging.warning("Skipping 'APP_CONFIG_ENDPOINT' key")
            continue

        val = out["value"]
        setting_value = json.dumps(val) if not isinstance(val, str) else val

        # seed the original output
        try:
            client.set_configuration_setting(
                ConfigurationSetting(key=key, value=setting_value, label="gpt-rag")
            )
            logging.info("✅ Seeded %s", key)
        except Exception as e:
            logging.error("❌ Failed to seed %s: %s", key, e)

        # special case: list of dicts with 'canonical_name'
        if isinstance(val, list):
            for item in val:
                if isinstance(item, dict) and "canonical_name" in item and "name" in item:
                    canonical_name = item["canonical_name"]
                    internal_value = item["name"]
                    try:
                        client.set_configuration_setting(
                            ConfigurationSetting(
                                key=canonical_name,
                                value=internal_value,
                                label="gpt-rag"
                            )
                        )
                        logging.info("✅ Seeded %s -> %s", canonical_name, internal_value)
                    except Exception as e:
                        logging.error("❌ Failed to seed %s: %s", canonical_name, e)

if __name__ == "__main__":
    main()