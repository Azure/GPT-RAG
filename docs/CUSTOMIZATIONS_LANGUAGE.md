# Configuring Language Settings

The solution utilizes Large Language Models (LLMs) and inherently supports multiple languages by default. However, each component has certain aspects that can be customized in terms of language. Let's explore each of them.

## Data Ingestion

Data ingestion supports multiple languages. However, if you wish, you can specify the search index **Analyzer** to be tailored for a specific language. An analyzer is a crucial component of the full-text search engine, playing a key role in processing text strings during both the indexing and query execution phases. 

By default, the configuration uses a standard, language-agnostic analyzer that works well for most languages. However, if your deployment is targeted at a non-Western language, customizing this parameter for that specific language could be advantageous. 

This customization can be easily achieved by setting the `SEARCH_ANALYZER_NAME` parameter before executing `azd up` or `azd provision`. The example below shows how to configure the analyzer for Vietnamese.

```sh
azd env set SEARCH_ANALYZER_NAME vi.microsoft
```

 Here's a [List of supported language analyzers](https://learn.microsoft.com/en-us/azure/search/index-add-language-analyzers#supported-language-analyzers) available.

## Orchestrator

The orchestrator's prompts are crafted in English and include instructions that guide the model to generate content in the same language as the user, ensuring multilingual functionality. Therefore, there's no need for customization in this aspect.

However, for certain error scenarios, such as server errors or when the Azure OpenAI service is unavailable, we utilize predefined error messages. These messages are available in English, Portuguese, and Spanish, and can be found in [this folder](https://github.com/Azure/gpt-rag-orchestrator/tree/main/orc/messages) within the orchestrator's repository.

By default, the language for error messages is set to English (en). You can switch to another available language by setting the `ORCHESTRATOR_MESSAGES_LANGUAGE` environment variable before executing `azd provision` or `azd up`. For example, to select Spanish, use the following command:

```sh
azd env set ORCHESTRATOR_MESSAGES_LANGUAGE es
```

If you wish to use your own error messages or add messages in a new language, you can modify the orchestrator's code. This involves either altering the content of the current JSON files or, to introduce a new language, adding a file akin to the existing `en.json`. For example, to add French, simply create a `fr.json` file in the same [folder](https://github.com/Azure/gpt-rag-orchestrator/tree/main/orc/messages) within the orchestrator's repository. 

## Front-end

The front-end allows users to utilize voice synthesis and recognition features to provide a voice interaction experience using the Azure AI Speech Service. You can define three environment variables to customize this experience.

`AZURE_SPEECH_RECOGNITION_LANGUAGE`: sets the language for transcribing user voice in the frontend UI, with the default being 'en-US'. To select a different language, refer to the list of supported [speech recognition languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=stt#supported-languages).

`AZURE_SPEECH_SYNTHESIS_LANGUAGE`: determines the language used for speech synthesis in the frontend, with the default also being 'en-US'. For available options, consult the list of supported [speech synthesis languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts#supported-languages).

`AZURE_SPEECH_SYNTHESIS_VOICE_NAME`: specifies the voice used for speech synthesis, with the default set to 'en-US-RyanMultilingualNeural'. To choose a different voice, check the list of supported [speech synthesis voices](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts#multilingual-voices).

To configure these settings, set the corresponding environment variable before executing `azd provision` or `azd up`. For example, to select 'pt-BR-FranciscaNeural' as the voice for speech synthesis, use the following command:

```sh
azd env set AZURE_SPEECH_SYNTHESIS_VOICE_NAME pt-BR-FranciscaNeural
```