# APIM (Azure API Management)
Azure API Management (APIM) is a comprehensive platform for managing APIs (Application Programming Interfaces). It provides a range of tools and services to help you create, publish, secure, monitor, and analyze APIs in a centralized manner.

## Benefits of API Management
1. Centralized Management: APIM provides a unified platform to manage all your APIs, regardless of where they are hosted. This centralization simplifies monitoring, security, and versioning1.
2. Security: It helps secure your APIs by providing features like authentication, authorization, and IP filtering. You can also enforce policies to control access and protect your backend services.
3. Scalability: APIM can handle high traffic loads and scale as needed, ensuring that your APIs remain responsive even under heavy usage.
4. Analytics and Monitoring: It offers detailed analytics and monitoring capabilities, allowing you to track usage patterns, performance metrics, and detect anomalies.
5. Policy Management: You can apply policies to transform and manipulate requests and responses, such as rate limiting, caching, and format conversion, without changing the backend code.

## API Management Integration Procedure

1. **Activate Managed Identity for APIM**
   Enable managed identity for APIM for secure authentication and access.


2. **Add "apimSubscriptionKey" entry in Key Vault**
   Include the built-in all-access subscription key in the Key Vault for use in APIM.


3. **Import secrets "contentSafetyKey", "bingapikey", "azureSearchKey" into Named Values**
   Import these named values containing secret keys from your key vault resource for various services. Import "bingapikey" or "azureSearchKey" depending on your retrieval method. Add "contentSafetyKey" if using security hub.


4. **Add OpenAI resource to APIs with the API URL suffix "openai"**
   In section "Create from Azure resource",include the OpenAI resource to existing APIs, using the suffix "openai" for identification.


5. **Add orchestrator and securityhub functions to APIs under API URL suffix /orc and /**
   In section "Create from Azure resource",include function apps orchestrator and securityhub(optional) functions in APIs, assigning them the specified paths.


6. **Manually add Bing API to APIM**
   If using bing retrieval,manually create the Bing API with a GET endpoint "search" pointing to "https://api.bing.microsoft.com/v7.0/custom" and use the API URL suffix "/bingCustomSearch". In the inbound process, add the header "Ocp-Apim-Subscription-Key" with the value of {{bingApiKey}} and the action to override.


7. **Add Content Safety API**
   If using security hub,add the Content Safety API with the corresponding JSON (Download [here](https://azure-ai-content-safety-api-docs.developer.azure-api.net/api-details#api=content-safety-service-2024-02-15-preview&operation=ImageIncidents_AddIncidentSamples)), pointing to "https://{your-content-safety-resource}.cognitiveservices.azure.com/contentSafety" and using the API URL suffix "/contentSafety". In the inbound process, include the header "Ocp-Apim-Subscription-Key" with the value of {{bingApiKey}} and the action to override.


8. **Add SearchIndexClient API**
   If using AI search,incorporate the SearchIndexClient API with the appropriate JSON (Download [here](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/search/data-plane/Azure.Search/stable/2023-11-01/searchindex.json)), directing it to "https://{your-search-resource}.search.windows.net/indexes/ragindex" and with the API URL suffix "/searchIndex". In the inbound process, add the header "api-key" with the value of {{azureSearchKey}} and the action to override. Change the subscription input to "api-key".


9. **Add Enviroment Variables**
    In the orchestrator add this env variables:
    "APIM_ENABLED": "true",
    "APIM_AZURE_OPENAI_ENDPOINT": "https://{apim-resource}.azure-api.net",
    "APIM_BING_CUSTOM_SEARCH_URL": "https://{apim-resource}.azure-api.net/bingCustomSearch",
    "APIM_AZURE_SEARCH_URL": "https://{apim-resource}.azure-api.net/searchIndex",
    "APIM_SECURITY_HUB_ENDPOINT": "https://{apim-resource}.azure-api.net/securityHub"

    If using security hub, add this env variables in the security hub function:
    "APIM_ENABLED": "true",
    "APIM_ENDPOINT": "https://{apim-resource}.azure-api.net"