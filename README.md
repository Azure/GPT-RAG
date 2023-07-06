# GPT on Your Data

## General Architecture Overview

<img src="media/oyd-rag.png" alt="imagem" width="1024">


## A Simple Retrieval-Augmented Generation Model

<img src="media/RAG.png" alt="imagem" width="1024">


## Zero Trust Architecture Overview

<img src="media/GPT-Rag-Architecture-Zero-Trust.png" alt="imagem" width="1024">



## Main components

1) [Data ingestion](https://github.com/Azure/gpt-rag-ingestion)

2) [Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)

3) [App UX](https://github.com/Azure/gpt-rag-frontend)

## Prerequisites

- [Azure Developer CLI](https://aka.ms/azure-dev/install)

## Deploy

1) Create a new folder and switch to it in the terminal.
2) Run `azd auth login` (if you did not run this before).
3) If did not clone the repo already, run `azd init -t azure/gpt-rag`.
4) There are 2 options how you can set the name of the resources created on Azure:

  - Pick the name for each resource at `infra/main.parameters.json`. Add a key and value for each of the next keys within the `parameters` map:
  ```json
    "resourceGroupName": {
      "value": "name-for-the-resource-group"
    },
    "keyVaultName": {
      "value": "name-for-key-vault"
    },
    "azureFunctionsServicePlanName":{
      "value": "name-for-service-plan"
    },
    "orchestratorFunctionsName":{
      "value": "name-for-orchestrator-function"
    },
    "dataIngestionFunctionsName":{
      "value": "name-for-data-ingestion-function"
    },
    "searchServiceName": {
      "value": "name-for-search-service"
    }
    "openAiServiceName": {
      "value": "name-for-open-ai-service"
    }
  ```

-   Alternately, you can set the name of each resource and save it within the azd-environment. Add the `infra` and `parameters` fields within the `config.json` file, next to the azd .env file. For example `.azure/azd-env-name/config.json`.

```json
  "infra": {
    "parameters": {
      "azureFunctionsServicePlanName": "the-plan",
      "dataIngestionFunctionsName": "data-ingest-func",
      "keyVaultName": "vv-kv-vh2",
      "openAiServiceName": "ai-s-r",
      "orchestratorFunctionsName": "o-fun",
      "resourceGroupName": "viva-rg",
      "searchServiceName": "sea"
    }
  }
```

5) Run `azd up`.

* For the target location, the regions that currently support the models used in this sample are **East US** or **South Central US**. For an up-to-date list of regions and models, check [here](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/concepts/models)

## References

* [Get started with the Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/get-started/index)

* [What is an Azure landing zone?](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/index)

* [Azure Cognitive Search](https://learn.microsoft.com/azure/search/search-what-is-azure-search)

* [Azure OpenAI Service](https://learn.microsoft.com/azure/cognitive-services/openai/overview)

* [Revolutionize your Enterprise Data with ChatGPT: Next-gen Apps w/ Azure OpenAI and Cognitive Search](https://aka.ms/entgptsearchblog)
  
* [Introducing Azure OpenAI Service On Your Data in Public Preview](https://techcommunity.microsoft.com/t5/ai-cognitive-services-blog/introducing-azure-openai-service-on-your-data-in-public-preview/ba-p/3847000)
  
* [Grounding LLMs](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/grounding-llms/ba-p/3843857#:~:text=What%20is%20Grounding%3F,relevance%20of%20the%20generated%20output.)

* [Check Your Facts and Try Again: Improving Large Language Models with External Knowledge and Automated Feedback](https://www.microsoft.com/en-us/research/group/deep-learning-group/articles/check-your-facts-and-try-again-improving-large-language-models-with-external-knowledge-and-automated-feedback/)

* [Microsoft Guidance Validation and Robustness of responses](https://lnkd.in/ggeSQmsV)




## Contributing 

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
