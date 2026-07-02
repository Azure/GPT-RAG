import json
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from config.search import setup


TEMPLATE_DIR = Path(__file__).resolve().parents[1]


def render_json_template(template_name, context):
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    rendered = env.get_template(template_name).render(**context)
    return json.loads(rendered)


class FoundryIqTemplateTests(unittest.TestCase):
    def test_settings_template_derives_search_index_before_dependent_defaults(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_PROJECT_ENDPOINT": "https://aif-abc123.services.ai.azure.com/api/projects/proj",
            },
        )

        self.assertEqual(settings["SEARCH_RAG_INDEX_NAME"], "ragindex-abc123")
        self.assertEqual(settings["KNOWLEDGE_BASE_NAME"], "ragindex-abc123-rag-kb")
        self.assertEqual(settings["FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME"], "ragindex-abc123-blob-ks")
        self.assertEqual(
            settings["FOUNDRY_IQ_AI_SERVICES_ENDPOINT"],
            "https://aif-abc123.services.ai.azure.com/",
        )

    def test_standard_blob_knowledge_source_includes_ai_services_endpoint_without_unsupported_chat_model(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
                "FOUNDRY_IQ_CONTENT_EXTRACTION_MODE": "standard",
            },
        )
        context = {
            **settings,
            "STORAGE_ACCOUNT_RESOURCE_ID": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st",
            "EMBEDDING_MODEL_INFO": {
                "endpoint": "https://aif-abc123.openai.azure.com/",
                "deployment_name": "text-embedding",
                "model_name": "text-embedding-3-large",
            },
            "GPT_MODEL_INFO": {
                "deployment_name": "chat",
                "model_name": "gpt-5-nano",
            },
        }

        search_definitions = render_json_template("search.j2", context)
        knowledge_source = search_definitions["knowledgeSources"][0]
        ingestion_parameters = knowledge_source["azureBlobParameters"]["ingestionParameters"]

        self.assertEqual(ingestion_parameters["contentExtractionMode"], "standard")
        self.assertEqual(
            ingestion_parameters["aiServices"]["uri"],
            "https://aif-abc123.services.ai.azure.com/",
        )
        self.assertIsNone(ingestion_parameters["chatCompletionModel"])

    def test_standard_blob_knowledge_source_includes_supported_chat_model(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
                "FOUNDRY_IQ_CONTENT_EXTRACTION_MODE": "standard",
            },
        )
        context = {
            **settings,
            "STORAGE_ACCOUNT_RESOURCE_ID": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st",
            "EMBEDDING_MODEL_INFO": {
                "endpoint": "https://aif-abc123.openai.azure.com/",
                "deployment_name": "text-embedding",
                "model_name": "text-embedding-3-large",
            },
            "GPT_MODEL_INFO": {
                "deployment_name": "chat",
                "model_name": "gpt-5.2",
            },
        }

        search_definitions = render_json_template("search.j2", context)
        knowledge_source = search_definitions["knowledgeSources"][0]
        ingestion_parameters = knowledge_source["azureBlobParameters"]["ingestionParameters"]

        self.assertEqual(
            ingestion_parameters["chatCompletionModel"]["azureOpenAIParameters"]["resourceUri"],
            ingestion_parameters["aiServices"]["uri"],
        )
        self.assertEqual(
            ingestion_parameters["chatCompletionModel"]["azureOpenAIParameters"]["modelName"],
            "gpt-5.2",
        )

    def test_network_isolated_blob_knowledge_source_sets_generated_indexer_private(self):
        credential = Mock()
        credential.get_token.return_value.token = "token"
        get_response = Mock()
        get_response.status_code = 200
        get_response.json.return_value = {
            "@odata.context": "https://search/$metadata#indexers/$entity",
            "name": "blob-ks-indexer",
            "dataSourceName": "blob-ks-datasource",
            "targetIndexName": "blob-ks-index",
            "parameters": {
                "configuration": {
                    "dataToExtract": "contentAndMetadata",
                }
            },
        }
        put_response = Mock()
        put_response.status_code = 200

        with patch.object(setup.requests, "get", return_value=get_response), patch.object(
            setup.requests, "put", return_value=put_response
        ) as put:
            setup.enforce_private_execution_for_generated_indexers(
                {
                    "knowledgeSources": [
                        {
                            "name": "blob-ks",
                            "kind": "azureBlob",
                            "azureBlobParameters": {},
                        }
                    ]
                },
                {"NETWORK_ISOLATION": "true"},
                credential,
                "https://search.search.windows.net",
                "2025-05-01-preview",
            )

        body = put.call_args.kwargs["json"]
        self.assertNotIn("@odata.context", body)
        self.assertEqual(body["parameters"]["configuration"]["executionEnvironment"], "Private")

    def test_non_network_isolated_setup_does_not_update_generated_indexer(self):
        credential = Mock()

        with patch.object(setup.requests, "get") as get:
            setup.enforce_private_execution_for_generated_indexers(
                {
                    "knowledgeSources": [
                        {
                            "name": "blob-ks",
                            "kind": "azureBlob",
                            "azureBlobParameters": {},
                        }
                    ]
                },
                {"NETWORK_ISOLATION": "false"},
                credential,
                "https://search.search.windows.net",
                "2025-05-01-preview",
            )

        get.assert_not_called()


    def test_conversation_upload_disabled_by_default_keeps_single_knowledge_source(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED"], "false")
        self.assertEqual(
            settings["FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME"],
            "ragindex-abc123-conv-ks",
        )

        context = {
            **settings,
            "STORAGE_ACCOUNT_RESOURCE_ID": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st",
            "EMBEDDING_MODEL_INFO": {
                "endpoint": "https://aif-abc123.openai.azure.com/",
                "deployment_name": "text-embedding",
                "model_name": "text-embedding-3-large",
            },
            "GPT_MODEL_INFO": {
                "deployment_name": "chat",
                "model_name": "gpt-5-nano",
            },
        }

        search_definitions = render_json_template("search.j2", context)
        self.assertEqual(len(search_definitions["knowledgeSources"]), 1)
        self.assertEqual(
            search_definitions["knowledgeSources"][0]["kind"], "azureBlob"
        )
        self.assertEqual(
            len(search_definitions["knowledgeBases"][0]["knowledgeSources"]), 1
        )

    def test_conversation_upload_enabled_adds_conversational_search_index_source(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
                "FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED": "true",
            },
        )
        self.assertEqual(settings["FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED"], "true")

        context = {
            **settings,
            "STORAGE_ACCOUNT_RESOURCE_ID": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st",
            "EMBEDDING_MODEL_INFO": {
                "endpoint": "https://aif-abc123.openai.azure.com/",
                "deployment_name": "text-embedding",
                "model_name": "text-embedding-3-large",
            },
            "GPT_MODEL_INFO": {
                "deployment_name": "chat",
                "model_name": "gpt-5-nano",
            },
        }

        search_definitions = render_json_template("search.j2", context)
        knowledge_sources = search_definitions["knowledgeSources"]
        self.assertEqual(len(knowledge_sources), 2)
        self.assertEqual(knowledge_sources[0]["kind"], "azureBlob")

        conv_source = knowledge_sources[1]
        self.assertEqual(conv_source["name"], "ragindex-abc123-conv-ks")
        self.assertEqual(conv_source["kind"], "searchIndex")
        self.assertEqual(
            conv_source["searchIndexParameters"]["searchIndexName"],
            "ragindex-abc123",
        )
        self.assertEqual(
            conv_source["searchIndexParameters"]["semanticConfigurationName"],
            "semantic-config",
        )

        kb_sources = search_definitions["knowledgeBases"][0]["knowledgeSources"]
        self.assertEqual(
            [s["name"] for s in kb_sources],
            ["ragindex-abc123-blob-ks", "ragindex-abc123-conv-ks"],
        )

    def test_conversation_upload_not_added_for_search_index_pattern(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
                "FOUNDRY_IQ_PATTERN": "searchIndex",
                "FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED": "true",
            },
        )

        context = {
            **settings,
            "STORAGE_ACCOUNT_RESOURCE_ID": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st",
            "EMBEDDING_MODEL_INFO": {
                "endpoint": "https://aif-abc123.openai.azure.com/",
                "deployment_name": "text-embedding",
                "model_name": "text-embedding-3-large",
            },
            "GPT_MODEL_INFO": {
                "deployment_name": "chat",
                "model_name": "gpt-5-nano",
            },
        }

        search_definitions = render_json_template("search.j2", context)
        self.assertEqual(len(search_definitions["knowledgeSources"]), 1)
        self.assertEqual(
            search_definitions["knowledgeSources"][0]["kind"], "searchIndex"
        )
        self.assertEqual(
            len(search_definitions["knowledgeBases"][0]["knowledgeSources"]), 1
        )


if __name__ == "__main__":
    unittest.main()
