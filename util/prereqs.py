#!/usr/bin/env python3
import subprocess
import sys

import click
from tabulate import tabulate
from azure.core.exceptions import HttpResponseError
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.cosmosdb import CosmosDBManagementClient
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient

def normalize_region(name: str) -> str:
    return name.replace(" ", "").replace("-", "").lower()

def get_default_subscription_id() -> str:
    try:
        result = subprocess.run(
            ["az", "account", "show", "--query", "id", "-o", "tsv"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        click.echo("ERROR: Please login to Azure using `az login`.", err=True)
        sys.exit(1)

def check_cosmos_provisioning(region: str, credential, subscription_id: str) -> bool:
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
    # Always prompt for region — ensures input even when running script directly
    region = click.prompt("Azure region (default: eastus2)", default="eastus2", show_default=True)  # :contentReference[oaicite:1]{index=1}

    cred = DefaultAzureCredential()
    sub = get_default_subscription_id()

    click.echo(f"\n🔍 Checking Cosmos DB provisioning in '{region}'…")
    allowed = check_cosmos_provisioning(region, cred, sub)
    if allowed:
        click.echo("  ✅ Provisioning allowed.")
    else:
        click.echo("  ❌ Provisioning disallowed—likely capacity constraints or subscription block.")
        click.echo("     Try another region (e.g. eastus2) or request access: https://aka.ms/cosmosdbquota")

    click.echo(f"\n📊 Azure OpenAI usage in '{region}':")
    usages = get_openai_usages(region, cred, sub)
    if usages:
        click.echo(format_usages_console(usages))
    else:
        click.echo("  ⚠️ No Azure OpenAI usage data found or an error occurred.")

if __name__ == "__main__":
    main()
