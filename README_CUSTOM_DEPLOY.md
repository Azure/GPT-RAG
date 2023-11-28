### Custom deployment

Before starting your infrastructure deployment, you can configure:
- [Deploying `Zero Trust Implementation`](#zero-trust-implementation).
- [Configuring language settings](#configuring-language-settings).
- [Defining the name for each resource](#defining-resources-names).
- [Provide a list of tags to apply to all resources](#adding-tags-for-all-resources).

#### Zero Trust Implementation

For deploying the zero trust implementation, run:

```sh
azd env set AZURE_NETWORK_ISOLATION true
```

Notes:
- Once deployment is completed, you need to use the Virtual Machine with the Bastion connection (created as part of zero trust deployment) to continue deploying data ingestion, orchestrator and the front-end app. 
- At the end of deployment, you will se a note about the name of the created Key Vault and the name of the secret to use for logging in with bastion to the VM.

#### Configuring language settings

The language settings of the components are by default in Spanish. For example, the AI Search service uses an analyzer called ‘es.microsoft’ to process and index the text during the query execution.

You can configure the language of your preference by defining the parameters of the [main.parameters.json](infra/main.parameters.json) file, notice that the accepted values for each parameter are defined in the [main.bicep](infra/main.bicep) file.

#### Defining resources names

By default, `azd` will automatically generate a unique name for each resource. The unique name is created based on the azd-environment name, the subscription name and the location. However, you can also manually define the name for each resource using the mapping from [main.parameters.json](https://github.com/Azure/GPT-RAG/blob/main/infra/main.parameters.json). Each resource name has a direct mapping to an environment variable, for example:


```json
"azureStorageAccountName": {
    "value": "${AZURE_STORAGE_ACCOUNT_NAME}"
},
```

This mapping means you can set `AZURE_STORAGE_ACCOUNT_NAME` to define the name for the storage account, by running the command:

```
azd env set AZURE_STORAGE_ACCOUNT_NAME <yourResourceNameHere>
```

> By using the azd-environment to set the mappings, you can define the resources names per environment.

> Note: If you work in multiple devices, you can leverage the azd's feature for [remote environment](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/remote-environments-support). It will allow you to keep your environment saved in Azure Storage and restore it from your devices.


### Customizing solution components

Azd automatically provisions the infrastructure and deploys the three components. However, if you want to manually deploy and customize them, you can follow the deployment instructions for each component.

**1) Data Ingestion & Search Configuration Deployment**

Use [Data ingestion](https://github.com/Azure/gpt-rag-ingestion) repo template to create your data ingestion git repo and execute the steps in its **Deploy** section.

**2) Orchestrator Component**

Use [Orchestrator](https://github.com/Azure/gpt-rag-orchestrator) repo template to create your orchestrator git repo and execute the steps in its **Deploy** section.

**3) Front-end Component**

Use [App Front-end](https://github.com/Azure/gpt-rag-frontend) repo template to create your own frontend git repo and execute the steps in its **Deploy** section.

<!-- ## Main components

1) [Data ingestion](https://github.com/Azure/gpt-rag-ingestion)

2) [Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)

3) [App Front-End](https://github.com/Azure/gpt-rag-frontend) Built with Azure App Services and the Backend for Front-End pattern, offers a smooth and scalable user interface -->

#### Adding tags for all resources

The [main.parameters.json](https://github.com/Azure/GPT-RAG/blob/main/infra/main.parameters.json) contains an empty object where you can define tags to apply to all your resources. Look for the entry:

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
