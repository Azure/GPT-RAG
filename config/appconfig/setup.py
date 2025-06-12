#!/usr/bin/env python

"""
Seed all ARM deployment outputs to Azure App Configuration

This script fetches every output from a specified ARM deployment and writes
each one as its own key/value in Azure App Configuration.

Steps:
1. Validate required environment variables:
   - subscriptionId
   - resourceGroupName
   - deploymentName
   - appConfigEndpoint
2. Authenticate via Azure CLI or Managed Identity
3. Fetch all deployment outputs
4. For each output:
     - Convert the value to JSON if not a string
     - Write it to App Configuration with up to 3 retries
     - Gracefully handle missing deployment or no outputs
"""
import os
import sys
import json
import logging
import time

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.core.exceptions import ClientAuthenticationError
from azure.mgmt.resource import ResourceManagementClient
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting
from azure.core.exceptions import ResourceNotFoundError

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
    "appConfigEndpoint"
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
    app_conf_endpoint = os.environ["appConfigEndpoint"]

    logging.info("Seeding App Configuration at %s for deployment %s/%s",
                 app_conf_endpoint, rg, deployment)

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

    # fetch ARM outputs, handle missing deployment gracefully
    try:
        deployment_resource = resource_client.deployments.get(rg, deployment)
        raw_outputs = deployment_resource.properties.outputs or {}
    except ResourceNotFoundError:
        logging.error("❌ Deployment '%s' not found in resource group '%s'. Exiting.", deployment, rg)
        sys.exit(1)

    # outputs = {k.upper(): v for k, v in raw_outputs.items()}
    outputs = raw_outputs

    # if no outputs, warn and exit
    if not outputs:
        logging.warning("⚠️ No outputs found for deployment '%s' in resource group '%s'. Nothing to seed.", deployment, rg)
        sys.exit(0)

    # connect to App Configuration
    client = AzureAppConfigurationClient(app_conf_endpoint, cred)

    retries = 3
    logging.info("Found %d outputs to seed", len(outputs))
    for key, out in outputs.items():
        if not isinstance(out, dict) or "value" not in out:
            logging.warning("Skipping %s: no 'value' field", key)
            continue

        val = out["value"]
        # if it's not a string, serialize to JSON
        setting_value = json.dumps(val) if not isinstance(val, str) else val

        for attempt in range(1, retries + 1):
            try:
                client.set_configuration_setting(
                    ConfigurationSetting(key=key, value=setting_value, label="gpt-rag"),
                )
                logging.info("✅ Successfully seeded %s", key)
                break
            except Exception as e:
                logging.warning("Attempt %d/%d to seed %s failed: %s",
                                attempt, retries, key, e)
                if attempt < retries:
                    time.sleep(20)
                else:
                    logging.error("❌ Giving up on %s after %d attempts", key, retries)


if __name__ == "__main__":
    main()
