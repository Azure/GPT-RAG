# Azure Direct Models (Microsoft Foundry)

This page explains what **Azure Direct Models** are and how to switch GPT-RAG’s default inference model (by default, `gpt-4o`) to a different model. **Azure Direct Models** are models hosted and exposed by **Azure AI Foundry** that you call **directly** via the **Foundry inference APIs**, using **Microsoft Entra ID–based authentication**, instead of Azure OpenAI–specific APIs.

**Azure Direct Models**

**Azure Direct Models** are models hosted and exposed by **Azure AI Foundry** that you call **directly** via the **Foundry inference APIs**, using **Microsoft Entra ID–based authentication**, instead of Azure OpenAI–specific APIs.

This enables you to:

- Use **non–Azure OpenAI models** (for example, Mistral, DeepSeek, Grok, Llama, etc.) from Azure.
- Standardize on Foundry inference APIs with Entra ID identity-based access.

<a id="how-to-find-which-models-you-can-use"></a>

**How to find which models you can use**

In practice, model availability depends on what’s enabled/available for your tenant/subscription/region and what appears in the Azure AI Foundry model catalog.

To discover **Azure Direct** models, open the **Model catalog** in Azure AI Foundry and select the collection:

- **Direct from Azure**

Use the image below as reference (catalog + collection filter):

![Azure AI Foundry catalog - Direct from Azure](media/howto_azure_direct.png)

<a id="how-to-switch-gpt-rags-default-model"></a>

**How to switch GPT-RAG’s default model**

GPT-RAG provisions with a default model (currently, `gpt-4o`). You can switch the inference model in two common ways:

- **Option A (recommended):** choose the model **before provisioning** (IaC-driven) by changing `infra/main.parameters.json`.
- **Option B:** choose the model **after provisioning** by creating/selecting the model manually in Azure AI Foundry and then updating your deployed configuration to point to it.

**Option A: Before provisioning (IaC / `main.parameters.json`)**

- Reference file: https://github.com/Azure/GPT-RAG/blob/main/infra/main.parameters.json

In `main.parameters.json`, update the `model` section.

**Example (default)**

```json
"model": {
  "format": "OpenAI",
  "name": "gpt-4o",
  "version": "2024-11-20"
}
```

**Example (Grok)**

Change `format`, `name`, and `version` to match the model you selected in the catalog.

```json
"model": {
  "format": "xAI",
  "name": "grok-4-fast-non-reasoning",
  "version": "1"
}
```

**Models tested**

I tested the end-to-end flow with these models (examples):

- `DeepSeek-V3.1`
- `DeepSeek-V3-0324`
- `mistral-small-2503`
- `grok-4-fast-non-reasoning`
- `grok-4`

> Note: available names/versions can change over time. Treat the Azure AI Foundry model catalog (collection **Direct from Azure**) as the source of truth.

**Option B: After provisioning (manual model creation)**

If you already provisioned GPT-RAG (or you prefer managing models manually), you can still switch models. The key idea is:

1. Create/select the model deployment in **Azure AI Foundry**.
2. Update GPT-RAG’s configuration so the orchestrator starts calling the new model.

**1) Create/select the model in Azure AI Foundry**

- In the Azure AI Foundry **Model catalog**, pick a model from **Direct from Azure**.
- Create/select a deployment (or whatever the UI calls it for that model).
- Note the model identifiers you need to configure GPT-RAG with: `format`, `name`, and `version`.

**2) Point GPT-RAG to the new model**

After provisioning, this usually means updating the **runtime configuration** used by the running services (rather than changing IaC inputs).

- If your deployment stores configuration in **Azure App Configuration**, update the corresponding model settings there and restart/redeploy the services so they pick up the new values.

> Tip: if you want a reproducible, “infrastructure-as-code” change that is applied during provisioning, use Option A.

<a id="bing-grounding-citations-behavior-by-model-type"></a>

**Bing Grounding Citations (behavior by model type)**
When the Bing Grounding Tool is used in Azure AI Foundry, the model may emit citation placeholders in the response text, for example: &#x3010;0:0&#x2020;source&#x3011;. How these placeholders are resolved depends on the model:

OpenAI / Azure OpenAI models (e.g., GPT-4, GPT-4o):

The response text includes annotations containing a `url_citation` object with the source URL and title.
The orchestrator processes these annotations and replaces placeholders with Markdown links in the format `[title](url)`.

Other models (Azure Direct) (e.g., `grok-4`, Llama, etc.):

The response text contains placeholders only, without annotations.
Since there is no reliable way to infer the source URLs, the placeholders are removed to avoid strange characters in the final answer.
Result: Bing citations appear without links when using these models.

