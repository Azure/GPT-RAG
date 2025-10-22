# 🚀 Deployment Guide

Choose your preferred deployment method based on project requirements and environment constraints.

## 📋 Table of Contents

- [1. Basic Architecture (No Network Isolation)](#1-basic-architecture-no-network-isolation-️)
- [2. Zero-Trust Architecture (ZTA)](#2-zero-trust-architecture-zta-)
  - [Before Provisioning](#1-before-provisioning)
  - [Provision the Infrastructure](#2-provision-the-infrastructure)
  - [Post-Provision Steps](#3-post-provision-steps-vnet-access-required)

---

> [!TIP]
> You can change parameter values in `main.parameters.json` or set them with `azd env set` before running `azd provision`. This applies only to parameters that support environment variable substitution.

### 1. Basic Architecture (No Network Isolation) ⚙️

Quick setup for demos without network isolation.

```shell
azd init -t azure/gpt-rag
azd provision
```

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin-bottom: 20px; background: #f5f5f5; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/nZMDtaDQuP4?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="GPT-RAG Tutorial" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

### 2. Zero-Trust Architecture (ZTA) 🔒

For deployments that **require network isolation**.

#### 1) Before Provisioning

Enable network isolation in your environment:

```shell
azd env set NETWORK_ISOLATION true
```

#### 2) Provision the Infrastructure

```shell
azd provision
```

#### 3) Post-Provision Steps *(VNet access required)*

> [!NOTE]
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
