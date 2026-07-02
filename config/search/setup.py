#!/usr/bin/env python3
"""
Azure Cognitive Search Setup Script

This script automates the provisioning and configuration of Azure Cognitive Search resources (datasources, indexes, skillsets, indexers) using definitions rendered from Jinja2 templates and values from Azure App Configuration.

Prerequisites:
- Export the environment variable APP_CONFIG_ENDPOINT with your Azure App Configuration endpoint, e.g.:
    export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
- The following keys must be present in App Configuration (label: gpt-rag):
    - SEARCH_SERVICE_QUERY_ENDPOINT
    - SEARCH_API_VERSION
    - Any other keys referenced in your Jinja2 templates
- Azure CLI or Managed Identity authentication must be available.
- The Jinja2 templates for search (search.j2, search.settings.j2) must exist and be valid in the config/search directory.

Features:
- Loads settings from Azure App Configuration (optionally filtered by label).
- Renders Jinja2 templates for search resource definitions, supporting variable expansion from App Config.
- Seeds variables from a secondary template (e.g., search.settings.j2) back into App Configuration.
- Provisions or updates Azure Search datasources, indexes, skillsets, and indexers in a safe order, cleaning up dependencies as needed.
- Handles authentication via Managed Identity or Azure CLI.
- Logs all actions and errors, and continues on non-fatal errors (fail gracefully).

Typical usage:
Run this script after provisioning your Azure Search service and App Configuration, and after updating your Jinja2 templates or App Config values.
"""

import os
import time
import json
import logging
from pathlib import Path
import requests
from typing import Any, Dict, Optional, Tuple

from azure.identity import ManagedIdentityCredential, AzureCliCredential, ChainedTokenCredential
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting
from jinja2 import Environment, FileSystemLoader, StrictUndefined, TemplateError

# ── Silence verbose logging ─────────────────────────────────────────────────
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# ── Constants ───────────────────────────────────────────────────────────────
TEMPLATE_NAME = "search.j2"
VARS_TEMPLATE = "search.settings.j2"
LABEL_FILTER = "gpt-rag"
DEFAULT_KNOWLEDGE_API_VERSION = "2026-05-01-preview"

# ── App Config Loader ───────────────────────────────────────────────────────
def parse_json_like_setting(value: Any) -> Any:
    if isinstance(value, str) and value.strip().startswith(("{", "[")):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            if '\\"' in value:
                try:
                    return json.loads(value.replace('\\"', '"'))
                except json.JSONDecodeError:
                    return value
            return value
    return value


def normalize_json_like_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
    return {key: parse_json_like_setting(value) for key, value in settings.items()}


def is_truthy_setting(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "t", "yes", "y"}


def strip_odata_metadata(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: strip_odata_metadata(item)
            for key, item in value.items()
            if not key.startswith("@odata.")
        }
    if isinstance(value, list):
        return [strip_odata_metadata(item) for item in value]
    return value


def normalize_foundry_iq_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
    kind = str(settings.get("FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND") or "").lower()
    is_adls_gen2 = is_truthy_setting(settings.get("FOUNDRY_IQ_IS_ADLS_GEN2"))
    if kind == "azureblob" and not is_adls_gen2:
        allowed_options = {"rbacScope", "sensitivityLabels"}
        options = settings.get("FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS")
        if not isinstance(options, list):
            options = ["rbacScope"]
        filtered_options = [option for option in options if option in allowed_options]
        settings["FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS"] = filtered_options or ["rbacScope"]
    return settings


def normalize_endpoint_uri(value: Any) -> str:
    endpoint = str(value or "").strip()
    if not endpoint:
        return ""
    return endpoint.rstrip("/") + "/"


def derive_foundry_iq_ai_services_endpoint(settings: Dict[str, Any]) -> str:
    endpoint = normalize_endpoint_uri(settings.get("FOUNDRY_IQ_AI_SERVICES_ENDPOINT"))
    if endpoint:
        return endpoint

    project_endpoint = str(settings.get("AI_FOUNDRY_PROJECT_ENDPOINT") or "").strip()
    if "/api/projects/" in project_endpoint:
        return normalize_endpoint_uri(project_endpoint.split("/api/projects/", 1)[0])

    account_name = str(settings.get("AI_FOUNDRY_ACCOUNT_NAME") or "").strip()
    if account_name:
        return f"https://{account_name}.services.ai.azure.com/"

    return ""


def is_foundry_iq_standard_blob(settings: Dict[str, Any]) -> bool:
    retrieval_backend = str(settings.get("RETRIEVAL_BACKEND") or "").lower()
    pattern = str(settings.get("FOUNDRY_IQ_PATTERN") or "").lower()
    kind = str(settings.get("FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND") or "").lower()
    mode = str(settings.get("FOUNDRY_IQ_CONTENT_EXTRACTION_MODE") or "").lower()
    return (
        retrieval_backend == "foundry_iq"
        and pattern != "searchindex"
        and kind == "azureblob"
        and mode == "standard"
    )


def validate_foundry_iq_settings(settings: Dict[str, Any]) -> None:
    if is_foundry_iq_standard_blob(settings) and not settings.get("FOUNDRY_IQ_AI_SERVICES_ENDPOINT"):
        raise ValueError(
            "FOUNDRY_IQ_CONTENT_EXTRACTION_MODE is set to 'standard', but no AI Services endpoint "
            "could be derived. Set FOUNDRY_IQ_AI_SERVICES_ENDPOINT to the Foundry resource endpoint "
            "on services.ai.azure.com, for example 'https://<foundry-resource>.services.ai.azure.com/'."
        )


def load_appconfig_settings(ac_client: AzureAppConfigurationClient, label_filter: Optional[str] = None) -> Dict[str, Any]:
    """
    Reads all settings from App Configuration under given label_filter (or None for no label).
    Returns a dict: { key: parsed_value_or_string }.
    If a value is JSON (starts with { or [), attempts json.loads; on failure, keeps as string.
    """
    ctx = {}
    try:
        for setting in ac_client.list_configuration_settings(key_filter="*", label_filter=label_filter):
            ctx[setting.key] = parse_json_like_setting(setting.value)
    except Exception as e:
        logging.error(f"Error listing App Configuration settings: {e}")
    return ctx

# ── Template Rendering ─────────────────────────────────────────────────────-
def prepare_context_and_render(template_name: str, template_dir: str, label_filter: str = LABEL_FILTER) -> Tuple[Optional[dict], dict]:
    """
    Loads settings from App Config, renders templates, and returns (rendered_definitions, context).
    Returns (None, context) on fatal error.
    """
    ac_endpoint = os.getenv("APP_CONFIG_ENDPOINT")
    if not ac_endpoint:
        logging.error("APP_CONFIG_ENDPOINT not set")
        return None, {}

    cred = ChainedTokenCredential(
            AzureCliCredential(process_timeout=30),
            ManagedIdentityCredential(process_timeout=30)
        )
    try:
        ac_client = AzureAppConfigurationClient(ac_endpoint, cred)
    except Exception as e:
        logging.error(f"Failed to create AzureAppConfigurationClient: {e}")
        return None, {}

    context = load_appconfig_settings(ac_client, label_filter=label_filter)
    
    # ── Extract embedding model info from MODEL_DEPLOYMENTS ──────────────────────────────────────
    def extract_embedding_model_info(ctx: dict) -> dict:
        """Extract embedding model information from MODEL_DEPLOYMENTS JSON"""
        try:
            model_deployments_str = ctx.get("MODEL_DEPLOYMENTS", "[]")
            if isinstance(model_deployments_str, str):
                model_deployments = json.loads(model_deployments_str)
            else:
                model_deployments = model_deployments_str
            
            # Find the embedding model by canonical_name
            for model in model_deployments:
                if model.get("canonical_name") == "EMBEDDING_DEPLOYMENT_NAME":
                    embedding_info = {
                        "deployment_name": model.get("name", "text-embedding"),
                        "model_name": model.get("model", {}).get("name", "text-embedding-3-large") if isinstance(model.get("model"), dict) else model.get("model", "text-embedding-3-large"),
                        "endpoint": model.get("endpoint", ""),
                        "api_version": model.get("apiVersion", "2025-01-01-preview")
                    }
                    logging.info(f"✅ Found embedding model: {embedding_info['deployment_name']} at {embedding_info['endpoint']}")
                    return embedding_info
            
            logging.warning("❗️ Embedding model with canonical_name 'EMBEDDING_DEPLOYMENT_NAME' not found in MODEL_DEPLOYMENTS")
            return {}
            
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logging.error(f"❗️ Could not extract embedding model info: {e}")
            return {}

    # ── Extract GPT model info from MODEL_DEPLOYMENTS ──────────────────────────────────────
    def extract_gpt_model_info(ctx: dict) -> dict:
        """Extract GPT model information from MODEL_DEPLOYMENTS JSON for knowledge agents"""
        try:
            model_deployments_str = ctx.get("MODEL_DEPLOYMENTS", "[]")
            if isinstance(model_deployments_str, str):
                model_deployments = json.loads(model_deployments_str)
            else:
                model_deployments = model_deployments_str
            
            # Find the GPT model by canonical_name (same approach as embedding model)
            for model in model_deployments:
                if model.get("canonical_name") == "CHAT_DEPLOYMENT_NAME":
                    model_obj = model.get("model")
                    if isinstance(model_obj, dict):
                        model_name = model_obj.get("name")
                        model_format = model_obj.get("format") or model.get("modelFormat")
                    else:
                        model_name = model_obj
                        model_format = model.get("modelFormat")

                    gpt_info = {
                        "deployment_name": model.get("name"),
                        "model_name": model_name,
                        "model_format": model_format,
                        "endpoint": model.get("endpoint", ""),
                        "api_version": model.get("apiVersion", "2025-01-01-preview")
                    }

                    model_format_l = (gpt_info.get("model_format") or "").lower()
                    if model_format_l != "openai":
                        logging.info(
                            "ℹ️ CHAT_DEPLOYMENT_NAME ignored because model.format is not OpenAI "
                            f"(format='{gpt_info.get('model_format')}', model='{gpt_info.get('model_name')}')"
                        )
                        return {}

                    logging.info(
                        f"✅ Found GPT model: {gpt_info['deployment_name']} ({gpt_info['model_name']}, format={gpt_info.get('model_format')}) at {gpt_info['endpoint']}"
                    )
                    return gpt_info
            
            logging.warning("❗️ GPT model with canonical_name 'CHAT_DEPLOYMENT_NAME' not found in MODEL_DEPLOYMENTS")
            return {}
            
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logging.error(f"❗️ Could not extract GPT model info: {e}")
            return {}

    # Add embedding model info to context for agentic retrieval
    embedding_model_info = extract_embedding_model_info(context)
    context["EMBEDDING_MODEL_INFO"] = embedding_model_info or {}

    # Add GPT model info to context for knowledge agents
    gpt_model_info = extract_gpt_model_info(context)
    context["GPT_MODEL_INFO"] = gpt_model_info or {}

    # Debug logging
    if context.get("EMBEDDING_MODEL_INFO"):
        logging.info(f"🔍 EMBEDDING_MODEL_INFO = {context['EMBEDDING_MODEL_INFO']}")
    else:
        logging.warning("❗️ EMBEDDING_MODEL_INFO is empty - vectorizers will not be configured")

    if context.get("GPT_MODEL_INFO"):
        logging.info(f"🔍 GPT_MODEL_INFO = {context['GPT_MODEL_INFO']}")
    else:
        logging.info("ℹ️ GPT_MODEL_INFO is empty")

    env = Environment(
        loader=FileSystemLoader(template_dir),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )

    def render_and_parse_json(template_name_inner: str, ctx: dict) -> Optional[dict]:
        try:
            tmpl = env.get_template(template_name_inner)
            rendered = tmpl.render(**ctx)
        except TemplateError as te:
            logging.error(f"Jinja2 rendering error for {template_name_inner}: {te}")
            return None
        try:
            parsed = json.loads(rendered)
        except json.JSONDecodeError as je:
            logging.error(f"Rendered JSON from {template_name_inner} is invalid: {je}\nRendered content:\n{rendered}")
            return None
        if not isinstance(parsed, dict):
            logging.error(f"Expected JSON object from {template_name_inner}, got: {type(parsed)}")
            return None
        return parsed

    # Process a vars template first
    vars_path = Path(template_dir) / VARS_TEMPLATE
    if vars_path.exists():
        logging.info(f"Processing variable template {VARS_TEMPLATE}")
        vars_dict = render_and_parse_json(VARS_TEMPLATE, context)
        if vars_dict:
            vars_dict = normalize_foundry_iq_settings(normalize_json_like_settings(vars_dict))
            context.update(vars_dict)
            ai_services_endpoint = derive_foundry_iq_ai_services_endpoint(context)
            if ai_services_endpoint:
                context["FOUNDRY_IQ_AI_SERVICES_ENDPOINT"] = ai_services_endpoint
                vars_dict["FOUNDRY_IQ_AI_SERVICES_ENDPOINT"] = ai_services_endpoint
            try:
                validate_foundry_iq_settings(context)
            except ValueError as ve:
                logging.error(str(ve))
                return None, context
            for key, val in vars_dict.items():
                if isinstance(val, (dict, list)):
                    final_val = json.dumps(val)
                else:
                    final_val = str(val)
                try:
                    setting = ConfigurationSetting(
                        key=key,
                        label=label_filter,
                        value=final_val,
                        content_type="text/plain"
                    )
                    ac_client.set_configuration_setting(setting)
                    logging.info(f"📝 Set App Config '{key}' = '{final_val}'")
                except Exception as e:
                    logging.error(f"❗️ Failed to set '{key}': {e}")
    else:
        logging.info(f"{VARS_TEMPLATE} not found; skipping variable template step.")

    # Process the main template
    result = render_and_parse_json(template_name, context)
    if result is None:
        logging.error(f"Template {template_name} could not be rendered or parsed.")
    logging.debug(f"Rendered definitions: {json.dumps(result, indent=2) if result else 'None'}")
    return result, context

# ── Azure Search API Call ─────────────────────────────────────────────────--
def call_search_api(endpoint: str, api_version: str, rtype: str, rname: str, method: str, cred: ChainedTokenCredential, body: Any = None, max_retries: int = 3) -> bool:
    """
    Call Azure Search REST API with retry logic for authentication failures.
    """
    for attempt in range(max_retries):
        try:
            # Get fresh token on each attempt
            token = cred.get_token("https://search.azure.com/.default").token
            headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
            url = f"{endpoint}/{rtype}/{rname}?api-version={api_version}"
            resp = getattr(requests, method.lower())(url, headers=headers, json=body)
            
            if method.lower() == "delete" and resp.status_code == 404:
                logging.info(f"✅ {rtype.capitalize()} '{rname}' does not exist; skipping deletion.")
                return True
            
            if resp.status_code >= 400:
                logging.warning(f"❗️ {method.upper()} {rtype}/{rname} failed {resp.status_code}: {resp.text}")
                return False
            else:
                logging.info(f"✅ {method.upper()} {rtype}/{rname} succeeded ({resp.status_code})")
                return True
                
        except Exception as e:
            if attempt == max_retries - 1:
                logging.error(f"❗️ Exception during {method.upper()} {rtype}/{rname}: {e}")
                return False
            else:
                logging.warning(f"⚠️ Attempt {attempt + 1}/{max_retries} failed for {method.upper()} {rtype}/{rname}: {e}")
                logging.warning(f"    Retrying in 2 seconds...")
                time.sleep(2)
                # Continue to next attempt - cred.get_token() will be called again

    return False  # Should never reach here, but just in case

# ── Resource Provisioning ─────────────────────────────────────────────────--
def provision_datasources(defs: dict, context: dict, cred: ChainedTokenCredential, ds_to_indexers: dict, search_endpoint: str, api_version: str):
    logging.info("Creating datasources...")
    for ds in defs.get("datasources", []):
        name = ds["name"]
        body = {k: v for k, v in ds.items() if k != "name"}
        for ix_name in ds_to_indexers.get(name, []):
            call_search_api(search_endpoint, api_version, "indexers", ix_name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "datasources", name, "put", cred, body)

def provision_indexes(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating indexes...")
    for idx in defs.get("indexes", []):
        body = idx
        name = body["name"]
        call_search_api(search_endpoint, api_version, "indexes", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexes", name, "put", cred, body)

def provision_skillsets(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating skillsets...")
    for sk in defs.get("skillsets", []):
        body = sk
        for s in body.get("skills", []):
            uri = s.get("uri", "")
            if uri and not uri.startswith("http"):
                s["uri"] = "https://" + uri.lstrip("/")
        name = body["name"]
        call_search_api(search_endpoint, api_version, "skillsets", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "skillsets", name, "put", cred, body)

def provision_indexers(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    logging.info("Creating indexers...")
    for ix in defs.get("indexers", []):
        name = ix["name"]
        body = ix["body"]
        call_search_api(search_endpoint, api_version, "indexers", name, "delete", cred)
        call_search_api(search_endpoint, api_version, "indexers", name, "put", cred, body)

def get_knowledge_api_version(context: dict) -> str:
    return str(context.get("FOUNDRY_IQ_API_VERSION") or DEFAULT_KNOWLEDGE_API_VERSION)


def cleanup_knowledge_resources(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str):
    """Clean up knowledge base resources in the correct order:
    1) Delete knowledge bases (they reference knowledge sources)
    2) Delete knowledge sources (they reference indexes)
    This ensures indexes can be deleted without conflicts.
    """

    knowledge_bases = defs.get("knowledgeBases", [])
    if knowledge_bases:
        logging.info("🧹 Cleaning up existing knowledge bases...")
        for kb in knowledge_bases:
            kb_name = kb["name"]
            call_search_api(search_endpoint, get_knowledge_api_version(context), "knowledgebases", kb_name, "delete", cred)

    knowledge_sources = list(defs.get("knowledgeSources", []))
    search_index_ks_name = f"{context.get('SEARCH_RAG_INDEX_NAME')}-rag-ks"
    blob_ks_name = f"{context.get('SEARCH_RAG_INDEX_NAME')}-blob-ks"
    conversation_ks_name = context.get("FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME") or f"{context.get('SEARCH_RAG_INDEX_NAME')}-conv-ks"
    existing_ks_names = {ks["name"] for ks in knowledge_sources if ks.get("name")}
    for name in (search_index_ks_name, blob_ks_name, conversation_ks_name):
        if name and name not in existing_ks_names:
            knowledge_sources.append({"name": name})
            existing_ks_names.add(name)
    if knowledge_sources:
        logging.info("🧹 Cleaning up existing knowledge sources...")
        for ks in knowledge_sources:
            ks_name = ks["name"]
            call_search_api(search_endpoint, get_knowledge_api_version(context), "knowledgesources", ks_name, "delete", cred)


def provision_knowledge_sources(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str):
    """Create or update Foundry IQ knowledge sources.

    Knowledge sources are top-level objects. For searchIndex knowledge sources, the referenced index must already exist.
    Native Blob/ADLS knowledge sources require the 2026-05-01-preview API when ingesting permissions.
    """

    knowledge_sources = defs.get("knowledgeSources", [])
    if not knowledge_sources:
        logging.info("🧠 No knowledge sources defined in template; skipping creation")
        return True

    knowledge_api_version = get_knowledge_api_version(context)
    logging.info(f"🧠 Creating knowledge sources ({knowledge_api_version})...")
    success_count = 0
    for ks in knowledge_sources:
        ks_name = ks["name"]
        body = ks
        success = call_search_api(search_endpoint, knowledge_api_version, "knowledgesources", ks_name, "put", cred, body)
        if success:
            success_count += 1
        else:
            logging.error(f"❗️ Failed to create knowledge source '{ks_name}'")

    logging.info(f"🧠 Knowledge sources creation completed: {success_count}/{len(knowledge_sources)} successful")
    return success_count == len(knowledge_sources)


def enforce_private_execution_for_generated_indexers(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str, api_version: str):
    if not is_truthy_setting(context.get("NETWORK_ISOLATION")):
        return

    generated_indexers = []
    for ks in defs.get("knowledgeSources", []):
        if ks.get("kind") != "azureBlob" or not ks.get("name"):
            continue
        generated_indexers.append(
            ks.get("azureBlobParameters", {}).get("createdResources", {}).get("indexer")
            or f"{ks['name']}-indexer"
        )
    generated_indexers = [name for name in generated_indexers if name]
    if not generated_indexers:
        return

    token = cred.get_token("https://search.azure.com/.default").token
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    for indexer_name in generated_indexers:
        url = f"{search_endpoint}/indexers/{indexer_name}?api-version={api_version}"
        resp = requests.get(url, headers=headers)
        if resp.status_code == 404:
            logging.info(f"ℹ️ Generated indexer '{indexer_name}' not found yet; skipping private execution update.")
            continue
        if resp.status_code >= 400:
            logging.warning(f"❗️ GET indexers/{indexer_name} failed {resp.status_code}: {resp.text}")
            continue

        body = strip_odata_metadata(resp.json())
        if not isinstance(body.get("parameters"), dict):
            body["parameters"] = {}
        if not isinstance(body["parameters"].get("configuration"), dict):
            body["parameters"]["configuration"] = {}
        body["parameters"]["configuration"]["executionEnvironment"] = "Private"
        update_resp = requests.put(url, headers=headers, json=body)
        if update_resp.status_code >= 400:
            logging.warning(f"❗️ PUT indexers/{indexer_name} failed {update_resp.status_code}: {update_resp.text}")
            continue
        logging.info(f"✅ Set generated indexer '{indexer_name}' executionEnvironment to Private")


def provision_knowledge_bases(defs: dict, context: dict, cred: ChainedTokenCredential, search_endpoint: str):
    """Create or update Foundry IQ knowledge bases.

    This repo uses outputMode=extractiveData and retrievalReasoningEffort=minimal so it doesn't depend on an LLM.
    """

    knowledge_bases = defs.get("knowledgeBases", [])
    if not knowledge_bases:
        logging.info("📚 No knowledge bases defined in template; skipping creation")
        return True

    knowledge_api_version = get_knowledge_api_version(context)
    logging.info(f"📚 Creating knowledge bases ({knowledge_api_version})...")
    success_count = 0
    for kb in knowledge_bases:
        kb_name = kb["name"]
        body = kb
        success = call_search_api(search_endpoint, knowledge_api_version, "knowledgebases", kb_name, "put", cred, body)
        if success:
            success_count += 1
        else:
            logging.error(f"❗️ Failed to create knowledge base '{kb_name}'")

    logging.info(f"📚 Knowledge bases creation completed: {success_count}/{len(knowledge_bases)} successful")
    return success_count == len(knowledge_bases)

# ── Main Provisioning to AI Search elements (datasources, indexes, skillset and indexers) ─────────────────────
def execute_setup(defs: Optional[dict], context: dict):
    if defs is None:
        raise RuntimeError("No search definitions were rendered; aborting Azure Search setup")
    cred = ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())
    indexers = defs.get("indexers", [])
    ds_to_indexers = {}
    for ix in indexers:
        ds_name = ix["body"]["dataSourceName"]
        ds_to_indexers.setdefault(ds_name, []).append(ix["name"])
    search_endpoint = context.get("SEARCH_SERVICE_QUERY_ENDPOINT")
    api_version = context.get("SEARCH_API_VERSION")
    if not search_endpoint:
        logging.error("❗️ SEARCH_SERVICE_QUERY_ENDPOINT not found in App Configuration; skipping Azure Search setup.")
        return
    if not api_version:
        logging.error("❗️ SEARCH_API_VERSION not found in search.env; skipping Azure Search setup.")
        return
    
    # Step 1: Clean up knowledge base resources in correct order (KB -> KS)
    cleanup_knowledge_resources(defs, context, cred, search_endpoint)
    
    # Step 2: Provision standard search resources (now indexes can be deleted safely)
    provision_datasources(defs, context, cred, ds_to_indexers, search_endpoint, api_version)
    provision_indexes(defs, context, cred, search_endpoint, api_version)
    provision_skillsets(defs, context, cred, search_endpoint, api_version)
    provision_indexers(defs, context, cred, search_endpoint, api_version)
    
    # Step 3: Provision knowledge base resources (KS -> KB)
    knowledge_sources_ok = provision_knowledge_sources(defs, context, cred, search_endpoint)
    enforce_private_execution_for_generated_indexers(defs, context, cred, search_endpoint, api_version)
    knowledge_bases_ok = provision_knowledge_bases(defs, context, cred, search_endpoint)
    if context.get("RETRIEVAL_BACKEND") == "foundry_iq" and (not knowledge_sources_ok or not knowledge_bases_ok):
        raise RuntimeError("Foundry IQ knowledge source/base provisioning failed")
    
    logging.info("All components have been provisioned.")

# ── Entry Point ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logging.info("🔍 Starting search setup.")
    t0 = time.time()
    cwd = Path(os.getcwd())
    template_dir = cwd / "config" / "search"
    if not template_dir.exists():
        logging.error(f"Template directory {template_dir} does not exist.")
    else:
        search_definitions, context = prepare_context_and_render(TEMPLATE_NAME, str(template_dir), label_filter=LABEL_FILTER)
        if search_definitions is not None:
            logging.info("🔍 Search definitions rendered successfully")
        execute_setup(search_definitions, context)
    logging.info(f"✅ Setup script finished in {round(time.time() - t0, 2)} seconds.")
