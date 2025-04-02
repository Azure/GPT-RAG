# Bring your own model
GPT-RAG accepts models from various providers, allowing for a flexible and customizable integration of AI capabilities.

**Important:** The models must support chat completion and accept function calling to ensure compatibility with GPT-RAG's functionalities.

*Disclaimer: This feature is currently available in the insiders branch in beta testing.*

To configure your model, you need to set specific environment variables for each provider. These variables are essential for the proper initialization and operation of the models within GPT-RAG. Additionally, you must set the environment variable `MODEL_PROVIDER` to one of the following values, depending on your provider:

- Azure OpenAI -> "aoai"
- Azure AI Foundry -> "azure_inference"
- OpenAI -> "openai"
- Anthropic -> "anthropic"
- Amazon Bedrock -> "amazon"
- Google -> "google"
- Vertex -> "vertex"
- Mistral -> "mistral"
- Ollama -> "ollama"
- Onnx -> "onnx"

## Bring your own model variables needed

Refer to the table below for the detailed environment variables required for each provider. This table outlines the necessary constructor settings, environment variables, and whether they are required for the integration.

Alternatively, all the API keys can be inputted via Key Vault instead of environment variables. For this, you do not need to set the API key environment variable. Instead, set a secret with the key under the following names:

- Azure AI Foundry -> "azureAIInferenceApiKey"
- OpenAI -> "openAIApiKey"
- Anthropic -> "anthropicApiKey"
- Google -> "googleAiApiKey"
- Mistral -> "mistralApiKey"


| Provider | Constructor Settings | Environment Variable | Required? |
| --- | --- | --- | --- |
| Azure AI Inference | ai_model_id, <br> api_key, <br> endpoint | AZURE_AI_INFERENCE_MODEL_ID, <br> AZURE_AI_INFERENCE_API_KEY, <br> AZURE_AI_INFERENCE_ENDPOINT | Yes, <br> No, <br> Yes |
| Anthropic | api_key, <br> ai_model_id | ANTHROPIC_API_KEY, <br> ANTHROPIC_CHAT_MODEL_ID | Yes, <br> Yes |
| Bedrock | model_id, <br> cli credentials([Guide](https://github.com/microsoft/semantic-kernel/blob/main/python/semantic_kernel/connectors/ai/bedrock/README.md)) | BEDROCK_CHAT_MODEL_ID, <br> N/A | Yes, <br> Yes |
| Google AI | gemini_model_id, <br> api_key | GOOGLE_AI_GEMINI_MODEL_ID, <br> GOOGLE_AI_API_KEY | Yes, <br> Yes |
| Vertex AI | project_id, <br> region, <br> gemini_model_id, <br> cli credentials([Guide](https://github.com/microsoft/semantic-kernel/blob/main/python/semantic_kernel/connectors/ai/google/README.md)) | VERTEX_AI_PROJECT_ID, <br> VERTEX_AI_REGION, <br> VERTEX_AI_GEMINI_MODEL_ID, <br> N/A | Yes, <br> No, <br> Yes, <br> Yes |
| Mistral AI | ai_model_id, <br> api_key | MISTRALAI_CHAT_MODEL_ID, <br> MISTRALAI_API_KEY | Yes, <br> Yes |
| Ollama | ai_model_id, <br> host | OLLAMA_CHAT_MODEL_ID, <br> OLLAMA_HOST | Yes, <br> No |
| Onnx | template, <br> ai_model_path | ONNX_GEN_AI_CHAT_TEMPLATE, <br> ONNX_GEN_AI_CHAT_MODEL_FOLDER | Yes, <br> Yes |



## Additional Details

### Considerations for Each Provider
- **Azure AI Foundry**: Use the model base endpoint and ensure that the endpoint URL does not end with /score.