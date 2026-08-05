#!/usr/bin/env python3
import subprocess
import sys

import click
from tabulate import tabulate

from util.azure_cli import resolve_az_command

def normalize_region(name: str) -> str:
    return name.replace(" ", "").replace("-", "").lower()

def get_default_subscription_id() -> str:
    try:
        result = subprocess.run(
            [
                resolve_az_command(),
                "account",
                "show",
                "--query",
                "id",
                "-o",
                "tsv",
            ],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        click.echo("ERROR: Please login to Azure using `az login`.", err=True)
        sys.exit(1)

def check_cosmos_provisioning(region: str, credential, subscription_id: str) -> bool:
    from azure.core.exceptions import HttpResponseError
    from azure.mgmt.cosmosdb import CosmosDBManagementClient

    client = CosmosDBManagementClient(credential, subscription_id)
    tgt = normalize_region(region)
    try:
        for loc in client.locations.list():
            if normalize_region(loc.name) == tgt:
                return bool(loc.properties.is_subscription_region_access_allowed_for_regular)
    except HttpResponseError as e:
        click.echo(f"ERROR querying Cosmos DB locations: {e.message}", err=True)
    return False

def get_openai_usages(region: str, credential, subscription_id: str):
    from azure.core.exceptions import HttpResponseError
    from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
    from azure.mgmt.resource import ResourceManagementClient

    rm = ResourceManagementClient(credential, subscription_id)
    rp = rm.providers.get("Microsoft.CognitiveServices")
    if rp.registration_state.lower() != "registered":
        rm.providers.register("Microsoft.CognitiveServices")
    cs = CognitiveServicesManagementClient(credential, subscription_id)
    try:
        api_region = region.replace(" ", "")
        return list(cs.usages.list(location=api_region))
    except HttpResponseError as e:
        click.echo(f"ERROR fetching Azure OpenAI usage data: {e.message}", err=True)
        return []

def format_usages_console(usages) -> str:
    rows = [[u.name.value, u.current_value, u.limit] for u in usages]
    return tabulate(
        rows,
        headers=["Resource", "Current", "Limit"],
        tablefmt="simple",
        numalign="right",
        floatfmt=".2f"
    )

@click.command(context_settings={"ignore_unknown_options": True})
def main():
    """Checks Cosmos DB provisioning and Azure OpenAI usage in a region."""
    from azure.identity import DefaultAzureCredential

    # Always prompt for region so direct runs cannot omit it.
    region = click.prompt(
        "Azure region (default: eastus2)",
        default="eastus2",
        show_default=True,
    )

    cred = DefaultAzureCredential()
    sub = get_default_subscription_id()

    click.echo(f"\nChecking Cosmos DB provisioning in '{region}'...")
    allowed = check_cosmos_provisioning(region, cred, sub)
    if allowed:
        click.echo("  PASS: Provisioning allowed.")
    else:
        click.echo(
            "  FAIL: Provisioning disallowed; likely capacity constraints "
            "or a subscription block."
        )
        click.echo("     Try another region (e.g. eastus2) or request access: https://aka.ms/cosmosdbquota")

    click.echo(f"\nAzure OpenAI usage in '{region}':")
    usages = get_openai_usages(region, cred, sub)
    if usages:
        click.echo(format_usages_console(usages))
    else:
        click.echo("  WARN: No Azure OpenAI usage data found or an error occurred.")

if __name__ == "__main__":
    main()
