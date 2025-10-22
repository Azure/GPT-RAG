# 🚀 Deployment Guide

Choose your preferred deployment method based on project requirements and environment constraints.

> You can change parameter values in `main.parameters.json` or set them with `azd env set` before running `azd provision`. This applies only to parameters that support environment variable substitution.

## Prerequisites

<details markdown="block">
<summary>Expand to view prerequisites</summary>

To deploy this template, the user or service principal requires the following permissions on the target Resource Group:

* An Azure subscription.
* An Azure user with **Contributor** and **User Access Admin** permissions on the target resource group.

In addition, the machine or environment used for deployment should have:

- Azure Developer CLI: [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- PowerShell 7+ (Windows only): [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package)
- Git: [Download Git](https://git-scm.com/downloads)
- Python 3.12: [Download Python](https://www.python.org/downloads/release/python-3120/)
- An Azure AI Services resource created or agreement to Responsible AI terms in the portal

</details>

## Quick Start - Basic Deployment

Quick setup for demos without network isolation.

```shell
azd init -t azure/gpt-rag
azd provision
```

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/nZMDtaDQuP4?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="GPT-RAG Tutorial" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

## Zero Trust Deployment

For deployments that **require network isolation**.

### Before Provisioning

Enable network isolation in your environment:

```shell
azd env set NETWORK_ISOLATION true
```

### Provision Infrastructure

```shell
azd provision
```

### Post-Provision Configuration

> The Bicep template provisions a **Jumpbox VM** by default. You can connect to it to perform the post-provision steps, deploy services, and run tests.

**Option A – Using the deployed Jumpbox VM**

1. Connect via **Azure Bastion**.
2. Open a terminal in the VM and run:

   ```shell
   cd C:\github\gpt-rag
   .\scripts\postProvision.ps1
   ```

**Option B – From your local machine (must have VNet access)**

1. From the `gpt-rag` directory, run:

   ```shell
   .\scripts\postProvision.ps1
   ```

   or (Bash)

   ```shell
   .\scripts\postProvision.sh
   ```

2. If you have re-initialized or cloned the repo again, refresh your `azd` environment so it points to the **existing** deployment:

   ```shell
   azd init -t azure/gpt-rag
   azd env refresh
   ```

3. When prompted, select the **same Subscription, Resource Group, and Location** as the original provisioning so `azd` correctly links to your environment.
