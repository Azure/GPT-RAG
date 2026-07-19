import json
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from config.search import setup
from config.search import foundry_iq_mcp_setup as mcp_setup


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


class WorkIqTemplateTests(unittest.TestCase):
    """Work IQ is opt-in and default-off. Rendered output must be byte-identical
    to the pre-Work IQ template when the feature is disabled.
    """

    def _foundry_iq_context(self, **overrides):
        settings_input = {
            "RESOURCE_TOKEN": "abc123",
            "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
            "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
            "RETRIEVAL_BACKEND": "foundry_iq",
        }
        settings_input.update(overrides)
        settings = render_json_template("search.settings.j2", settings_input)
        return settings, {
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

    def test_settings_defaults_work_iq_disabled_and_empty_name(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["WORK_IQ_ENABLED"], "false")
        self.assertEqual(settings["WORK_IQ_KNOWLEDGE_SOURCE_NAME"], "")

    def test_work_iq_disabled_by_default_produces_no_workiq_entry(self):
        _, context = self._foundry_iq_context()
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "workIQ")
        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertNotIn("work-iq-ks", kb_source_names)

    def test_work_iq_enabled_without_name_produces_no_workiq_entry(self):
        _, context = self._foundry_iq_context(WORK_IQ_ENABLED="true")
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "workIQ")

    def test_work_iq_enabled_adds_workiq_knowledge_source_and_kb_reference(self):
        _, context = self._foundry_iq_context(
            WORK_IQ_ENABLED="true",
            WORK_IQ_KNOWLEDGE_SOURCE_NAME="work-iq-ks",
        )
        search_definitions = render_json_template("search.j2", context)

        work_iq_sources = [
            ks for ks in search_definitions["knowledgeSources"] if ks["kind"] == "workIQ"
        ]
        self.assertEqual(len(work_iq_sources), 1)
        work_iq = work_iq_sources[0]
        self.assertEqual(work_iq["name"], "work-iq-ks")
        self.assertEqual(work_iq["kind"], "workIQ")
        self.assertIsNone(work_iq["encryptionKey"])
        # Work IQ is service-managed. It must not carry a filterAddOn, blob
        # parameters, or search-index parameters.
        self.assertNotIn("filterAddOn", work_iq)
        self.assertNotIn("azureBlobParameters", work_iq)
        self.assertNotIn("searchIndexParameters", work_iq)

        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertIn("work-iq-ks", kb_source_names)

    def test_work_iq_not_added_when_retrieval_backend_is_ai_search(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "WORK_IQ_ENABLED": "true",
                "WORK_IQ_KNOWLEDGE_SOURCE_NAME": "work-iq-ks",
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
        # ai_search backend never emits knowledge sources at all.
        self.assertEqual(search_definitions["knowledgeSources"], [])
        self.assertEqual(search_definitions["knowledgeBases"], [])

    def test_settings_defaults_fabric_iq_disabled_and_empty(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["FABRIC_IQ_ENABLED"], "false")
        self.assertEqual(settings["FABRIC_IQ_KNOWLEDGE_SOURCE_NAME"], "")
        self.assertEqual(settings["FABRIC_IQ_WORKSPACE_ID"], "")
        self.assertEqual(settings["FABRIC_IQ_ONTOLOGY_ID"], "")

    def test_fabric_iq_disabled_by_default_produces_no_fabric_entry(self):
        _, context = self._foundry_iq_context()
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "fabricOntology")
        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertNotIn("fabric-iq-ks", kb_source_names)

    def test_fabric_iq_enabled_without_binding_fields_produces_no_entry(self):
        # Enabled + name but missing workspace and ontology ids must not emit.
        _, context = self._foundry_iq_context(
            FABRIC_IQ_ENABLED="true",
            FABRIC_IQ_KNOWLEDGE_SOURCE_NAME="fabric-iq-ks",
        )
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "fabricOntology")

    def test_fabric_iq_enabled_adds_fabric_knowledge_source_and_kb_reference(self):
        _, context = self._foundry_iq_context(
            FABRIC_IQ_ENABLED="true",
            FABRIC_IQ_KNOWLEDGE_SOURCE_NAME="fabric-iq-ks",
            FABRIC_IQ_WORKSPACE_ID="ws-guid-1",
            FABRIC_IQ_ONTOLOGY_ID="ont-guid-1",
        )
        search_definitions = render_json_template("search.j2", context)

        fabric_sources = [
            ks
            for ks in search_definitions["knowledgeSources"]
            if ks["kind"] == "fabricOntology"
        ]
        self.assertEqual(len(fabric_sources), 1)
        fabric = fabric_sources[0]
        self.assertEqual(fabric["name"], "fabric-iq-ks")
        self.assertEqual(fabric["kind"], "fabricOntology")
        self.assertIsNone(fabric["encryptionKey"])
        # Fabric IQ is service-managed. It must not carry a filterAddOn.
        self.assertNotIn("filterAddOn", fabric)
        self.assertEqual(
            fabric["fabricOntologyParameters"],
            {"workspaceId": "ws-guid-1", "ontologyId": "ont-guid-1"},
        )

        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertIn("fabric-iq-ks", kb_source_names)

    def test_settings_defaults_fabric_data_agent_disabled_and_empty(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["FABRIC_DATA_AGENT_ENABLED"], "false")
        self.assertEqual(settings["FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME"], "")
        self.assertEqual(settings["FABRIC_DATA_AGENT_WORKSPACE_ID"], "")
        self.assertEqual(settings["FABRIC_DATA_AGENT_DATA_AGENT_ID"], "")

    def test_fabric_data_agent_disabled_by_default_produces_no_entry(self):
        _, context = self._foundry_iq_context()
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "fabricDataAgent")
        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertNotIn("fabric-data-agent-ks", kb_source_names)

    def test_fabric_data_agent_enabled_without_binding_fields_produces_no_entry(self):
        # Enabled + name but missing workspace and data agent ids must not emit.
        _, context = self._foundry_iq_context(
            FABRIC_DATA_AGENT_ENABLED="true",
            FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME="fabric-data-agent-ks",
        )
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "fabricDataAgent")

    def test_fabric_data_agent_enabled_adds_knowledge_source_and_kb_reference(self):
        _, context = self._foundry_iq_context(
            FABRIC_DATA_AGENT_ENABLED="true",
            FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME="fabric-data-agent-ks",
            FABRIC_DATA_AGENT_WORKSPACE_ID="ws-guid-2",
            FABRIC_DATA_AGENT_DATA_AGENT_ID="da-guid-2",
        )
        search_definitions = render_json_template("search.j2", context)

        agent_sources = [
            ks
            for ks in search_definitions["knowledgeSources"]
            if ks["kind"] == "fabricDataAgent"
        ]
        self.assertEqual(len(agent_sources), 1)
        agent = agent_sources[0]
        self.assertEqual(agent["name"], "fabric-data-agent-ks")
        self.assertEqual(agent["kind"], "fabricDataAgent")
        self.assertIsNone(agent["encryptionKey"])
        # Fabric Data Agent is service-managed. It must not carry a filterAddOn.
        self.assertNotIn("filterAddOn", agent)
        self.assertEqual(
            agent["fabricDataAgentParameters"],
            {"workspaceId": "ws-guid-2", "dataAgentId": "da-guid-2"},
        )

        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertIn("fabric-data-agent-ks", kb_source_names)

    def test_settings_defaults_web_grounding_disabled_and_empty(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["WEB_GROUNDING_ENABLED"], "false")
        self.assertEqual(settings["WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME"], "")
        self.assertEqual(settings["WEB_GROUNDING_ALLOWED_DOMAINS"], "")
        self.assertEqual(settings["WEB_GROUNDING_BLOCKED_DOMAINS"], "")

    def test_web_grounding_disabled_by_default_produces_no_entry(self):
        _, context = self._foundry_iq_context()
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "web")
        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertNotIn("web-ks", kb_source_names)

    def test_web_grounding_enabled_without_name_produces_no_entry(self):
        _, context = self._foundry_iq_context(
            WEB_GROUNDING_ENABLED="true",
            WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME="",
        )
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "web")

    def test_web_grounding_enabled_adds_knowledge_source_and_kb_reference(self):
        _, context = self._foundry_iq_context(
            WEB_GROUNDING_ENABLED="true",
            WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME="web-ks",
            WEB_GROUNDING_ALLOWED_DOMAINS="Learn.Microsoft.com, azure.microsoft.com",
            WEB_GROUNDING_BLOCKED_DOMAINS="example.com",
        )
        search_definitions = render_json_template("search.j2", context)

        web_sources = [
            ks
            for ks in search_definitions["knowledgeSources"]
            if ks["kind"] == "web"
        ]
        self.assertEqual(len(web_sources), 1)
        web = web_sources[0]
        self.assertEqual(web["name"], "web-ks")
        self.assertEqual(web["kind"], "web")
        self.assertIsNone(web["encryptionKey"])
        # Public data - no ACL, no filterAddOn.
        self.assertNotIn("filterAddOn", web)
        self.assertEqual(
            web["webParameters"],
            {
                "domains": {
                    "allowedDomains": ["learn.microsoft.com", "azure.microsoft.com"],
                    "blockedDomains": ["example.com"],
                }
            },
        )

        kb_source_names = [
            s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]
        ]
        self.assertIn("web-ks", kb_source_names)

    def test_web_grounding_enabled_without_domains_emits_empty_lists(self):
        _, context = self._foundry_iq_context(
            WEB_GROUNDING_ENABLED="true",
            WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME="web-ks",
        )
        search_definitions = render_json_template("search.j2", context)
        web_sources = [
            ks
            for ks in search_definitions["knowledgeSources"]
            if ks["kind"] == "web"
        ]
        self.assertEqual(len(web_sources), 1)
        self.assertEqual(
            web_sources[0]["webParameters"],
            {"domains": {"allowedDomains": [], "blockedDomains": []}},
        )


class FoundryIqMcpTemplateTests(unittest.TestCase):
    """Generic MCP Server knowledge sources are opt-in and default-off.
    Rendered output must be unchanged when the feature is disabled.
    """

    def _foundry_iq_context(self, **overrides):
        settings_input = {
            "RESOURCE_TOKEN": "abc123",
            "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
            "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
            "RETRIEVAL_BACKEND": "foundry_iq",
        }
        settings_input.update(overrides)
        settings = render_json_template("search.settings.j2", settings_input)
        return settings, {
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

    def _mcp_source(self, **overrides):
        source = {
            "name": "monitor-mcp-ks",
            "description": "Azure Monitor MCP",
            "serverURL": "https://monitor-mcp.contoso.com/mcp",
            "tools": [
                {
                    "name": "query_logs",
                    "outputParsing": "auto",
                    "inclusionMode": "reranked",
                    "maxOutputTokens": 4096,
                }
            ],
        }
        source.update(overrides)
        return source

    def test_settings_defaults_mcp_disabled_and_empty(self):
        settings = render_json_template(
            "search.settings.j2",
            {
                "RESOURCE_TOKEN": "abc123",
                "SEARCH_SERVICE_QUERY_ENDPOINT": "https://search.search.windows.net",
                "AI_FOUNDRY_ACCOUNT_NAME": "aif-abc123",
                "RETRIEVAL_BACKEND": "foundry_iq",
            },
        )
        self.assertEqual(settings["FOUNDRY_IQ_MCP_ENABLED"], "false")
        self.assertEqual(settings["FOUNDRY_IQ_MCP_SOURCES_JSON"], [])
        self.assertEqual(settings["FOUNDRY_IQ_MCP_REASONING_EFFORT"], "low")
        self.assertEqual(settings["FOUNDRY_IQ_MCP_TRUSTED_HOSTS"], "")
        self.assertEqual(settings["FOUNDRY_IQ_MCP_LOG_TOOL_ARGUMENTS"], "false")

    def test_mcp_disabled_by_default_produces_no_entry_and_preserves_minimal_reasoning(self):
        _, context = self._foundry_iq_context()
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "mcpServer")
        kb = search_definitions["knowledgeBases"][0]
        self.assertNotIn("monitor-mcp-ks", [s["name"] for s in kb["knowledgeSources"]])
        self.assertEqual(kb["models"], [])
        self.assertEqual(kb["retrievalReasoningEffort"], {"kind": "minimal"})

    def test_mcp_enabled_without_sources_produces_no_entry(self):
        _, context = self._foundry_iq_context(FOUNDRY_IQ_MCP_ENABLED="true")
        search_definitions = render_json_template("search.j2", context)
        for ks in search_definitions["knowledgeSources"]:
            self.assertNotEqual(ks["kind"], "mcpServer")
        kb = search_definitions["knowledgeBases"][0]
        self.assertEqual(kb["models"], [])
        self.assertEqual(kb["retrievalReasoningEffort"], {"kind": "minimal"})

    def test_mcp_enabled_registers_source_with_kb_planning_model_and_reasoning(self):
        _, context = self._foundry_iq_context(
            FOUNDRY_IQ_MCP_ENABLED="true",
            FOUNDRY_IQ_MCP_REASONING_EFFORT="medium",
        )
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = [self._mcp_source()]
        search_definitions = render_json_template("search.j2", context)

        mcp_sources = [ks for ks in search_definitions["knowledgeSources"] if ks["kind"] == "mcpServer"]
        self.assertEqual(len(mcp_sources), 1)
        source = mcp_sources[0]
        self.assertEqual(source["name"], "monitor-mcp-ks")
        self.assertIsNone(source["encryptionKey"])
        self.assertEqual(
            source["mcpServerParameters"],
            {
                "serverURL": "https://monitor-mcp.contoso.com/mcp",
                "tools": [
                    {
                        "name": "query_logs",
                        "outputParsing": "auto",
                        "inclusionMode": "reranked",
                        "maxOutputTokens": 4096,
                    }
                ],
            },
        )
        # Auth metadata (if any) must never be forwarded into the registration payload.
        self.assertNotIn("auth", source["mcpServerParameters"])
        self.assertNotIn("authIdentity", source["mcpServerParameters"])

        kb = search_definitions["knowledgeBases"][0]
        self.assertIn("monitor-mcp-ks", [s["name"] for s in kb["knowledgeSources"]])
        # Never emit alwaysQuerySource for MCP knowledge source references.
        mcp_ref = next(s for s in kb["knowledgeSources"] if s["name"] == "monitor-mcp-ks")
        self.assertEqual(mcp_ref, {"name": "monitor-mcp-ks"})

        self.assertEqual(
            kb["models"],
            [
                {
                    "kind": "azureOpenAI",
                    "azureOpenAIParameters": {
                        "resourceUri": context["FOUNDRY_IQ_AI_SERVICES_ENDPOINT"],
                        "deploymentId": "chat",
                        "modelName": "gpt-5-nano",
                    },
                }
            ],
        )
        self.assertEqual(kb["retrievalReasoningEffort"], {"kind": "medium"})

    def test_mcp_tool_with_json_output_parsing_includes_documents_path(self):
        _, context = self._foundry_iq_context(FOUNDRY_IQ_MCP_ENABLED="true")
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = [
            self._mcp_source(
                tools=[
                    {
                        "name": "query_logs",
                        "outputParsing": "json",
                        "documentsPath": "$.results",
                        "inclusionMode": "always",
                        "maxOutputTokens": 2048,
                    }
                ]
            )
        ]
        search_definitions = render_json_template("search.j2", context)
        tool = search_definitions["knowledgeSources"][-1]["mcpServerParameters"]["tools"][0]
        self.assertEqual(tool["documentsPath"], "$.results")

    def test_multiple_mcp_sources_all_registered_and_referenced(self):
        _, context = self._foundry_iq_context(FOUNDRY_IQ_MCP_ENABLED="true")
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = [
            self._mcp_source(name="monitor-mcp-ks", serverURL="https://monitor-mcp.contoso.com/mcp"),
            self._mcp_source(name="billing-mcp-ks", serverURL="https://billing-mcp.contoso.com/mcp"),
        ]
        search_definitions = render_json_template("search.j2", context)

        mcp_names = [
            ks["name"] for ks in search_definitions["knowledgeSources"] if ks["kind"] == "mcpServer"
        ]
        self.assertEqual(mcp_names, ["monitor-mcp-ks", "billing-mcp-ks"])

        kb_names = [s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]]
        self.assertIn("monitor-mcp-ks", kb_names)
        self.assertIn("billing-mcp-ks", kb_names)

    def test_mcp_coexists_with_web_grounding_and_sharepoint_indexed(self):
        _, context = self._foundry_iq_context(
            FOUNDRY_IQ_MCP_ENABLED="true",
            WEB_GROUNDING_ENABLED="true",
            WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME="web-ks",
            SHAREPOINT_INDEXED_ENABLED="true",
            SHAREPOINT_INDEXED_KNOWLEDGE_SOURCE_NAME="sp-ks",
            SHAREPOINT_INDEXED_INDEX_NAME="sp-index",
            SHAREPOINT_INDEXED_SITE_URL="https://contoso.sharepoint.com/sites/eng",
            SHAREPOINT_INDEXED_TENANT_ID="tenant-guid",
        )
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = [self._mcp_source()]
        search_definitions = render_json_template("search.j2", context)

        kinds = {ks["kind"] for ks in search_definitions["knowledgeSources"]}
        self.assertTrue({"azureBlob", "web", "indexedSharePoint", "mcpServer"}.issubset(kinds))

        kb_names = [s["name"] for s in search_definitions["knowledgeBases"][0]["knowledgeSources"]]
        self.assertIn("web-ks", kb_names)
        self.assertIn("sp-ks", kb_names)
        self.assertIn("monitor-mcp-ks", kb_names)

    def test_rendering_is_deterministic(self):
        _, context = self._foundry_iq_context(FOUNDRY_IQ_MCP_ENABLED="true")
        context["FOUNDRY_IQ_MCP_SOURCES_JSON"] = [
            self._mcp_source(name="monitor-mcp-ks"),
            self._mcp_source(name="billing-mcp-ks", serverURL="https://billing-mcp.contoso.com/mcp"),
        ]
        first = render_json_template("search.j2", context)
        second = render_json_template("search.j2", context)
        self.assertEqual(first, second)
        self.assertEqual(json.dumps(first, sort_keys=True), json.dumps(second, sort_keys=True))


class FoundryIqMcpValidationTests(unittest.TestCase):
    """Unit tests for the fail-closed validation in foundry_iq_mcp_setup."""

    def _context(self, sources=None, **overrides):
        context = {
            "RETRIEVAL_BACKEND": "foundry_iq",
            "FOUNDRY_IQ_MCP_ENABLED": "true",
            "FOUNDRY_IQ_MCP_SOURCES_JSON": sources if sources is not None else [],
            "FOUNDRY_IQ_MCP_TRUSTED_HOSTS": "monitor-mcp.contoso.com",
            "FOUNDRY_IQ_MCP_REASONING_EFFORT": "low",
            "GPT_MODEL_INFO": {"deployment_name": "chat", "model_name": "gpt-5-nano"},
            "FOUNDRY_IQ_AI_SERVICES_ENDPOINT": "https://aif-abc123.services.ai.azure.com/",
        }
        context.update(overrides)
        return context

    def _source(self, **overrides):
        source = {
            "name": "monitor-mcp-ks",
            "serverURL": "https://monitor-mcp.contoso.com/mcp",
            "tools": [
                {
                    "name": "query_logs",
                    "outputParsing": "auto",
                    "inclusionMode": "reranked",
                    "maxOutputTokens": 4096,
                }
            ],
        }
        source.update(overrides)
        return source

    def test_disabled_is_a_no_op(self):
        context = self._context(sources=[], FOUNDRY_IQ_MCP_ENABLED="false")
        mcp_setup.validate_foundry_iq_mcp_settings(context)  # must not raise

    def test_enabled_with_no_sources_raises(self):
        context = self._context(sources=[])
        with self.assertRaisesRegex(ValueError, "no sources"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_missing_planning_model_raises(self):
        context = self._context(sources=[self._source()], GPT_MODEL_INFO={})
        with self.assertRaisesRegex(ValueError, "planning model"):
            mcp_setup.validate_foundry_iq_mcp_settings(context)

    def test_missing_ai_services_endpoint_raises(self):
        context = self._context(sources=[self._source()], FOUNDRY_IQ_AI_SERVICES_ENDPOINT="")
        with self.assertRaisesRegex(ValueError, "AI Services endpoint"):
            mcp_setup.validate_foundry_iq_mcp_settings(context)

    def test_invalid_sources_json_type_raises(self):
        context = self._context(sources={"not": "a list"})
        with self.assertRaisesRegex(ValueError, "JSON array"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_duplicate_source_names_raise(self):
        context = self._context(sources=[self._source(), self._source()])
        with self.assertRaisesRegex(ValueError, "used more than once"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_non_https_scheme_raises(self):
        context = self._context(sources=[self._source(serverURL="http://monitor-mcp.contoso.com/mcp")])
        with self.assertRaisesRegex(ValueError, "https"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_userinfo_in_url_raises(self):
        context = self._context(
            sources=[self._source(serverURL="https://user:pass@monitor-mcp.contoso.com/mcp")]
        )
        with self.assertRaisesRegex(ValueError, "userinfo"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_fragment_in_url_raises(self):
        context = self._context(sources=[self._source(serverURL="https://monitor-mcp.contoso.com/mcp#frag")])
        with self.assertRaisesRegex(ValueError, "fragment"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_ip_literal_host_raises(self):
        context = self._context(
            sources=[self._source(serverURL="https://203.0.113.10/mcp")],
            FOUNDRY_IQ_MCP_TRUSTED_HOSTS="203.0.113.10",
        )
        with self.assertRaisesRegex(ValueError, "IP literal"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_loopback_ip_literal_host_raises(self):
        context = self._context(
            sources=[self._source(serverURL="https://127.0.0.1/mcp")],
            FOUNDRY_IQ_MCP_TRUSTED_HOSTS="127.0.0.1",
        )
        with self.assertRaisesRegex(ValueError, "IP literal"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_localhost_host_raises(self):
        context = self._context(
            sources=[self._source(serverURL="https://localhost/mcp")],
            FOUNDRY_IQ_MCP_TRUSTED_HOSTS="localhost",
        )
        with self.assertRaisesRegex(ValueError, "localhost"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_host_not_in_trusted_allowlist_raises(self):
        context = self._context(
            sources=[self._source()],
            FOUNDRY_IQ_MCP_TRUSTED_HOSTS="other-host.contoso.com",
        )
        with self.assertRaisesRegex(ValueError, "not an exact match"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_empty_trusted_hosts_raises(self):
        context = self._context(sources=[self._source()], FOUNDRY_IQ_MCP_TRUSTED_HOSTS="")
        with self.assertRaisesRegex(ValueError, "TRUSTED_HOSTS is empty"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_no_tools_raises(self):
        context = self._context(sources=[self._source(tools=[])])
        with self.assertRaisesRegex(ValueError, "non-empty array"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_duplicate_tool_names_raise(self):
        tool = {
            "name": "query_logs",
            "outputParsing": "auto",
            "inclusionMode": "reranked",
            "maxOutputTokens": 100,
        }
        context = self._context(sources=[self._source(tools=[tool, dict(tool)])])
        with self.assertRaisesRegex(ValueError, "used more than once"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_invalid_inclusion_mode_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "inclusionMode": "sometimes"}])]
        )
        with self.assertRaisesRegex(ValueError, "inclusionMode"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_invalid_output_parsing_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "outputParsing": "yaml"}])]
        )
        with self.assertRaisesRegex(ValueError, "outputParsing"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_json_output_parsing_without_documents_path_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "outputParsing": "json"}])]
        )
        with self.assertRaisesRegex(ValueError, "documentsPath"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_non_positive_max_output_tokens_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "maxOutputTokens": 0}])]
        )
        with self.assertRaisesRegex(ValueError, "positive integer"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_max_output_tokens_above_local_cap_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "maxOutputTokens": 20000}])]
        )
        with self.assertRaisesRegex(ValueError, "local cap"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_always_query_source_on_tool_raises(self):
        context = self._context(
            sources=[self._source(tools=[{**self._source()["tools"][0], "alwaysQuerySource": True}])]
        )
        with self.assertRaisesRegex(ValueError, "alwaysQuerySource"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_always_query_source_on_source_raises(self):
        context = self._context(sources=[self._source(alwaysQuerySource=True)])
        with self.assertRaisesRegex(ValueError, "alwaysQuerySource"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_foundry_connection_auth_raises(self):
        context = self._context(sources=[self._source(auth={"kind": "foundryConnection"})])
        with self.assertRaisesRegex(ValueError, "foundryConnection"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_secret_like_auth_key_raises(self):
        context = self._context(sources=[self._source(auth={"apiKey": "not-a-real-secret"})])
        with self.assertRaisesRegex(ValueError, "credential material"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_unsupported_auth_kind_raises(self):
        context = self._context(sources=[self._source(auth={"kind": "oauth2"})])
        with self.assertRaisesRegex(ValueError, "unsupported"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_managed_identity_auth_is_a_no_op(self):
        context = self._context(sources=[self._source(auth={"kind": "managedIdentity"})])
        sources = mcp_setup.validate_and_get_mcp_sources(context)
        self.assertEqual(len(sources), 1)

    def test_absent_auth_is_valid(self):
        context = self._context(sources=[self._source()])
        sources = mcp_setup.validate_and_get_mcp_sources(context)
        self.assertEqual(len(sources), 1)

    def test_unexpected_source_key_raises(self):
        context = self._context(sources=[self._source(unexpectedKey="value")])
        with self.assertRaisesRegex(ValueError, "unexpected key"):
            mcp_setup.validate_and_get_mcp_sources(context)

    def test_invalid_reasoning_effort_raises(self):
        context = self._context(sources=[self._source()], FOUNDRY_IQ_MCP_REASONING_EFFORT="minimal")
        with self.assertRaisesRegex(ValueError, "REASONING_EFFORT"):
            mcp_setup.validate_and_get_mcp_sources(context)


class WorkIqPreflightTests(unittest.TestCase):
    def test_filter_work_iq_sources_no_op_when_disabled(self):
        defs = {
            "knowledgeSources": [
                {"name": "blob-ks", "kind": "azureBlob"},
            ],
            "knowledgeBases": [
                {"name": "kb", "knowledgeSources": [{"name": "blob-ks"}]},
            ],
        }
        setup.filter_work_iq_sources(
            defs,
            {"RETRIEVAL_BACKEND": "foundry_iq", "WORK_IQ_ENABLED": "false"},
            Mock(),
        )
        self.assertEqual(defs["knowledgeSources"], [{"name": "blob-ks", "kind": "azureBlob"}])
        self.assertEqual(defs["knowledgeBases"][0]["knowledgeSources"], [{"name": "blob-ks"}])

    def test_filter_work_iq_sources_removes_source_when_not_consented(self):
        defs = {
            "knowledgeSources": [
                {"name": "blob-ks", "kind": "azureBlob"},
                {"name": "work-iq-ks", "kind": "workIQ"},
            ],
            "knowledgeBases": [
                {
                    "name": "kb",
                    "knowledgeSources": [{"name": "blob-ks"}, {"name": "work-iq-ks"}],
                }
            ],
        }
        credential = Mock()
        with patch.object(setup, "check_work_iq_admin_consent", return_value=False):
            setup.filter_work_iq_sources(
                defs,
                {
                    "RETRIEVAL_BACKEND": "foundry_iq",
                    "WORK_IQ_ENABLED": "true",
                    "WORK_IQ_KNOWLEDGE_SOURCE_NAME": "work-iq-ks",
                },
                credential,
            )
        self.assertEqual([ks["name"] for ks in defs["knowledgeSources"]], ["blob-ks"])
        self.assertEqual(
            [ref["name"] for ref in defs["knowledgeBases"][0]["knowledgeSources"]],
            ["blob-ks"],
        )

    def test_filter_work_iq_sources_keeps_source_when_consented(self):
        defs = {
            "knowledgeSources": [
                {"name": "work-iq-ks", "kind": "workIQ"},
            ],
            "knowledgeBases": [
                {"name": "kb", "knowledgeSources": [{"name": "work-iq-ks"}]}
            ],
        }
        with patch.object(setup, "check_work_iq_admin_consent", return_value=True):
            setup.filter_work_iq_sources(
                defs,
                {
                    "RETRIEVAL_BACKEND": "foundry_iq",
                    "WORK_IQ_ENABLED": "true",
                    "WORK_IQ_KNOWLEDGE_SOURCE_NAME": "work-iq-ks",
                },
                Mock(),
            )
        self.assertEqual([ks["name"] for ks in defs["knowledgeSources"]], ["work-iq-ks"])

    def test_filter_work_iq_sources_removes_source_when_preflight_inconclusive(self):
        defs = {
            "knowledgeSources": [{"name": "work-iq-ks", "kind": "workIQ"}],
            "knowledgeBases": [
                {"name": "kb", "knowledgeSources": [{"name": "work-iq-ks"}]}
            ],
        }
        with patch.object(setup, "check_work_iq_admin_consent", return_value=None):
            setup.filter_work_iq_sources(
                defs,
                {
                    "RETRIEVAL_BACKEND": "foundry_iq",
                    "WORK_IQ_ENABLED": "true",
                    "WORK_IQ_KNOWLEDGE_SOURCE_NAME": "work-iq-ks",
                },
                Mock(),
            )
        self.assertEqual(defs["knowledgeSources"], [])
        self.assertEqual(defs["knowledgeBases"][0]["knowledgeSources"], [])


if __name__ == "__main__":
    unittest.main()
