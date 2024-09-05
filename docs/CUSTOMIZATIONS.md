# Custom deployment

On this page, you will find some options to configure your deployment:

- [Configuring Language settings](#configuring-language-settings)
- [Configuring AOAI content filters](#configuring-aoai-content-filters)
- [Setting Custom Names for Resources](#defining-resources-names)
- [Applying Tags to All Resources](#adding-tags-for-all-resources)
- [Bringing Your Own Resources](#bring-your-own-resources)
<!-- - [Selecting Your Components](#selecting-your-components) -->
- [Accessing Data Ingest function using AI Search Managed Identity](#accessing-the-data-ingest-function-from-ai-search-using-a-managed-identity)
- [Extending Enteprise RAG components](#extending-solution-components)
- [Filter Files with AI Search Using Security Trimming](#Filter-Files-with-AI-Search-Using-Security-Trimming)

**Note on Environment Variables**

Most of the customizations described on this page involve the use of environment variables. Therefore, it's worth noting the following about using `azd` environment variables:
- By utilizing the `azd env` to set [environment variables](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/manage-environment-variables), you can specify resource names for each environment.
- If you work across multiple devices, you can take advantage of `azd`'s support for [remote environments](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/remote-environments-support). This feature allows you to save your environment settings in Azure Storage and restore them on any device.

## Configuring Language Settings

Enterprise RAG leverages Large Language Models (LLMs) and supports multiple languages by default. However, it provides parameters to fine-tune the language settings across its three main components. For detailed instructions, refer to [Configuring Language Settings](CUSTOMIZATIONS_LANGUAGE.md).

## Configuring AOAI content filters

Provisioning an Azure OpenAI resource with `azd` automatically creates a content filtering profile with a default severity threshold (Medium) for all content harm categories (Hate, Violence, Sexual, Self-Harm) and assigns it to the provisioned Azure OpenAI model through a post-deployment script. If you wish to customize these settings to be more or less restrictive, please refer to the [Customize Content Filtering Policies](CUSTOMIZATIONS_CONTENT_FILTERING.md) page.

## Defining resources names

By default, `azd` will automatically generate a unique name for each resource. The unique name is created based on the azd-environment name, the subscription name and the location. However, you can also manually define the name for each resource as described in [Customizing resources names](CUSTOMIZATIONS_RESOURCE_NAMES.md).

## Adding tags for all resources

The [main.parameters.json](../infra/main.parameters.json) contains an empty object where you can define tags to apply to all your resources before you run `azd up` or `azd provision`. Look for the entry:

```json
"deploymentTags":{
    "value": {}
}
```

Define your tags as `"key":value`, for example:

```json
"deploymentTags":{
    "value": {
        "business-unit": "foo",
        "cost-center": "bar"
    }
}
```

While you are defining your deployment tags, you can create your own environment mappings (in case you want to set different tag's values per environment). For example:

Creating your own azd-env mapping:
```json
"deploymentTags":{
    "value": {
        "business-unit": "${MY_DEPLOYMENT_BUSINESS_UNIT}",
        "cost-center": "${COST_CENTER}"
    }
}
```

Then, define the values for your environment:
```sh
azd env set MY_DEPLOYMENT_BUSINESS_UNIT foo
azd env set COST_CENTER bar
```

> Note: Since the input parameter is an object, azd won't prompt the user for a value if the env-var is not set (how it happens when the input argument is a string). The values would be resolved and applied as empty strings when missing.

## Bring Your Own Resources

In some cases, you may want to use one or more pre-existing resources in your subscription instead of creating new ones. Our Bicep template allows you to do this. For detailed instructions on how this can be achieved, please take a look at the [Bring Your Own Resources](CUSTOMIZATIONS_BYOR.md) page.

<!-- ## Selecting Your Components

To install just some specific GPT-RAG components, you can adjust the installation process by setting one or more of the following variables to false, based on the components you prefer not to install:

- DEPLOY_DATA_INGESTION
- DEPLOY_FRONTEND
- DEPLOY_ORCHESTRATOR

After setting the variables, begin the deployment process by running `azd init` as directed in the Getting Started section on the main page. Next, execute `azd provision`. Following this, use the `azd package` and `azd deploy` commands, specifying which components to install: `dataIngest`, `orchestrator`, or `frontend`. If no components are specified, the system will attempt to package and deploy all components.

For example, suppose you are only interested in the **Data ingestion** component.

First, you would set the deployment of the other two components to false:

```
azd env set DEPLOY_FRONTEND false
azd env set DEPLOY_ORCHESTRATOR false
```

Then, you proceed with the deployment procedure, as previously described.

```
azd provision
azd package dataIngest
azd deploy dataIngest
```

Done! you deployed only the **Data ingestion** component. -->

## Accessing the data ingest function from AI Search using a Managed Identity

In the AI Search indexing process, a skillset incorporates a custom web app skill. This skill is powered by the data ingestion Azure Function, which is responsible for chunking the data. By default, the AI Search service establishes a connection with the Azure Function via an API key.

However, for enhanced security and simplified credentials management, you have the option to utilize a managed identity for this connection. To switch to using a managed identity, simply set the environment variable `AZURE_SEARCH_USE_MIS` to `true`.

```sh
azd env set AZURE_SEARCH_USE_MIS true
```

After setting this variable, you need to deploy again using the azd up command. 

```sh
azd up
```

> **Important**: In order for the data ingestion function to be accessed with a managed identity, it needs to be configured to use Microsoft Entra Sign-in, as indicated [in this link](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad).

## Extending solution components

Azd automatically provisions the infrastructure and deploys the three components. However, you may want to change and customize parts of the code to meet a specific requirement. Our Solution Accelerator allows you to do this. For detailed instructions on how this can be achieved, please take a look at the [Extending Application Components](EXTENDING_APP_COMPONENTS.md) page.

## Filter Files with AI Search Using Security Trimming

This customization is particularly valuable in scenarios where sensitive documents need to be accessed by specific groups or individuals within an organization. By enabling the AZURE_SEARCH_TRIMMING variable, you can ensure that AI Search returns results tailored to each user’s access (no RBAC permissions), please take a look at the [Filter Files with AI Search Using Security Trimming](CUSTOMIZATIONS_SEARCH_TRIMMING.md) page.