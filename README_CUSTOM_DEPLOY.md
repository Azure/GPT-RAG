### Custom deployment

On this page, you will find some options to configure your deployment:

- [Configuring language settings](#configuring-language-settings).
- [Defining the name for each resource](#defining-resources-names).
- [Provide a list of tags to apply to all resources](#adding-tags-for-all-resources).
- [Accessing the data ingest function using a Managed Identity](#accessing-the-data-ingest-function-from-ai-search-using-a-managed-identity).

#### Configuring language settings

The default language settings for most components are set to English. You can set your preferred language by specifying the parameters in the [main.parameters.json](infra/main.parameters.json) file. Be aware that the permissible values for each parameter are listed in the [main.bicep](infra/main.bicep) file.  
   
Parameters description:  
   
- orchestratorMessagesLanguage: The language used for orchestrator error messages, such as 'en' or 'es'. To view the currently supported error message languages, you can visit [this link](https://github.com/Azure/gpt-rag-orchestrator/tree/main/orc/messages).  
   
- searchAnalyzerName: An analyzer is an integral part of the full-text search engine, responsible for text processing strings during both indexing and query execution stages. The default configuration uses the standard language agnostic analyzer, but you can change it if you want to optimize your deployment for a specific language. Here's a [List of supported language analyzers](https://learn.microsoft.com/en-us/azure/search/index-add-language-analyzers#supported-language-analyzers).  
   
- speechRecognitionLanguage: The language used to transcribe user voice in the frontend UI. [List of supported languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=stt#supported-languages).  
   
- speechSynthesisLanguage: The language used for speech synthesis in the frontend. [List of supported languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts#supported-languages).  
   
- speechSynthesisVoiceName: The voice used for speech synthesis in the frontend. [List of supported languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts#supported-languages).

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

#### Accessing the data ingest function from AI Search using a Managed Identity

The AI Search indexer uses a skillset with a custom web app skill implemented by the data ingestion Azure Function for chunking. By default, AI Search connects with the Azure Function using its API key.

If you prefer to use a managed identity for the connection, you can do so by setting AZURE_SEARCH_USE_MIS variable. 

```sh
azd env set AZURE_SEARCH_USE_MIS true
```

After setting this variable, you need to deploy again using the azd up command. 

```sh
azd up
```

Notes:

- In order for the data ingestion function to be accessed with a managed identity, it needs to be configured to use Microsoft Entra Sign-in, as indicated [in this link](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad).

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