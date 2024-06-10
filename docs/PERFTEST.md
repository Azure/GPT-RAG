# Performance Testing

When developing Language Model (LLM) applications, a significant amount of time is invested in development and evaluation to ensure high-quality, reliable, and safe user responses. However, the effectiveness of an LLM application's user experience is also determined by the response speed. 


To learn more about performance testing, please take a look at this blog post [Load Testing RAG based Generative AI Applications](https://techcommunity.microsoft.com/t5/ai-azure-ai-services-blog/load-testing-rag-based-generative-ai-applications/ba-p/4086993) where we describe the concepts, tools, and techniques used ahead.

**How do I execute the load tests?**

Enterprise RAG has three components: data ingestion, frontend, and orchestrator. The orchestrator manages conversation flow and interacts with services like the LLM and search service for data retrieval, and works across channels like web and Teams.

We've developed a load test suite for the **Orchestrator** using Azure Load Testing, executable via a Github Action workflow. For detailed instructions, see [**Load Testing GPT-RAG's orchestrator**](./LOAD_TESTING.md) page.