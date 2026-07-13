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
