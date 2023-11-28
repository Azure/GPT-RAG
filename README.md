The **RAG pattern** enables businesses to use the reasoning capabilities of LLMs, using their existing models to process and generate responses based on new data. RAG facilitates periodic data updates without the need for fine-tuning, thereby streamlining the integration of LLMs into businesses. 

The **Enterprise RAG** Solution Accelerator (GPT-RAG) offers a robust architecture tailored for enterprise-grade deployment of the RAG pattern. It ensures grounded responses and is built on Zero-trust security and Responsible AI, ensuring availability, scalability, and auditability. Ideal for organizations transitioning from exploration and PoC stages to full-scale production and MVPs.

## Components

* [Data ingestion](https://github.com/Azure/gpt-rag-ingestion) Optimizes data preparation for Azure OpenAI.

* [Orchestrator](https://github.com/Azure/gpt-rag-orchestrator) The system's dynamic backbone ensuring scalability and a consistent user experience.

* [App Front-End](https://github.com/Azure/gpt-rag-frontend) Built with Azure App Services and the Backend for Front-End pattern, offers a smooth and scalable user interface.

## Concepts & Architecture

*  [Enterprise RAG +Prompt Engineering+Finetuning+Train (Video in Spanish)](https://www.youtube.com/watch?v=ICsf4yirieA)

<a href="https://www.youtube.com/watch?v=ICsf4yirieA"><img src="https://img.youtube.com/vi/ICsf4yirieA/0.jpg" alt="Alt text" width="480"/></a>

* [RAG Pattern: What and Why?](README_RAG.md)

* [Solution Architecture Overview](README_ARCHITECTURE.md)

## Deployment Instructions

To deploy Enterprise RAG and have your solution up and running you just need to execute the next four steps using [Azure Developer CLI (azd)](https://aka.ms/azure-dev/install) in a terminal:

**1** Download the Repository:

```sh
azd init -t azure/gpt-rag
```

**2** Login to Azure:

```sh
azd auth login

```

**3** Start Building the infrastructure and components deployment:

```sh
azd up
```

**4** Add source documents to object storage

Upload your documents to the documents folder in the storage account which name starts with strag.

Notes:
   
- For a rapid deployment using the default settings, just adhere to the previously outlined instructions.
   
- For a customized deployment, refer to the [Custom Deployment](README_CUSTOM_DEPLOY.md) section to understand the customization options before executing the previously mentioned steps.

## Additional Resources

### Pricing Estimation

* [Pricing Model](https://github.com/Azure/GPT-RAG/wiki/GPT%E2%80%90RAG-%E2%80%90-Pricing-Model)

### Governance

* [Governance Model](https://share.mindmanager.com/#publish/9ogrdWqzmAzZB6ilgURohV4lj1LriKjOWc0w_u2U)

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
