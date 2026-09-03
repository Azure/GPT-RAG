# Azure Direct Models

Azure Direct Models are hosted and exposed by Microsoft Foundry. You call them via the Foundry inference APIs using Microsoft Entra ID–based authentication, instead of Azure OpenAI–specific APIs. This page explains how to switch GPT-RAG’s default inference model (currently, `gpt-5-nano`) to a different model.

With Azure Direct Models, you can use non–Azure OpenAI models (for example, Mistral, DeepSeek, Grok, etc.) from Azure, while standardizing on Foundry inference APIs and Entra ID authentication.

<a id="how-to-find-which-models-you-can-use"></a>

**How to find which models you can use**

Model availability depends on what’s enabled for your tenant, subscription, and region. The easiest way to see what you can use is the [Foundry Model Catalog](https://ai.azure.com/explore/models). In the catalog, select the `Direct from Azure` collection to focus on Azure Direct models.

![Microsoft Foundry catalog - Direct from Azure](media/howto_azure_direct.png)

<a id="how-to-switch-gpt-rags-default-model"></a>

**Switch chat model**

GPT-RAG provisions with a default model (currently, `gpt-5-nano`). Most commonly, you change the model at provisioning time. If the solution is already deployed, you can switch the chat model by updating the runtime configuration.

**Provisioning time**

Before you run `azd provision`, set the model in the [`infra/main.parameters.json`](https://github.com/Azure/GPT-RAG/blob/main/infra/main.parameters.json) file (this file is used by the infrastructure provisioning step).

Model deployments live under `modelDeploymentList`. Update the entry whose
`canonical_name` is `CHAT_DEPLOYMENT_NAME` — specifically its nested `model`
object, and `apiVersion` if the model requires a different one. Leave the
`text-embedding` entry alone unless you are also changing the embedding model.

Example (default)

```json
"modelDeploymentList": {
  "value": [
    {
      "name": "chat",
      "model": {
        "format": "OpenAI",
        "name": "gpt-5-nano",
        "version": "2025-08-07"
      },
      "sku": { "name": "GlobalStandard", "capacity": 100 },
      "canonical_name": "CHAT_DEPLOYMENT_NAME",
      "apiVersion": "2025-12-01-preview"
    }
  ]
}
```

Example (Grok)

Change `format`, `name`, and `version` inside the nested `model` object to match the model you selected in the catalog.

```json
{
  "name": "chat",
  "model": {
    "format": "xAI",
    "name": "grok-4-fast-non-reasoning",
    "version": "1"
  },
  "sku": { "name": "GlobalStandard", "capacity": 100 },
  "canonical_name": "CHAT_DEPLOYMENT_NAME",
  "apiVersion": "2025-12-01-preview"
}
```

**Models tested**

I tested the end-to-end flow with these models (non-exhaustive list): `DeepSeek-V3.1`, `DeepSeek-V3-0324`, `mistral-small-2503`, `grok-4-fast-non-reasoning`, and `grok-4`.

> Note: available names/versions can change over time. Treat the Microsoft Foundry model catalog (collection `Direct from Azure`) as the source of truth.

**After the solution is deployed**

If you already provisioned GPT-RAG (or you prefer managing models manually), you can still switch models. First, create/select the model deployment in Microsoft Foundry (Model catalog → `Direct from Azure`). Then take the deployment name you created/selected and set it as `CHAT_DEPLOYMENT_NAME` in Azure App Configuration. Finally, restart the chat runtime so it picks up the new value: the orchestrator Container App in the classic topology, or the hosted agent in the hosted topologies.

<a id="bing-grounding-citations-behavior-by-model-type"></a>

> **Note on Bing Grounding citations**: The Bing Grounding tool may emit placeholder markers like &#x3010;0:0&#x2020;source&#x3011;. With OpenAI and Azure OpenAI models, responses include `url_citation` annotations so GPT-RAG can render clickable links. With some Azure Direct models, these annotations may be missing; in that case, GPT-RAG strips the placeholder markers and no clickable citations are shown.

