"""Capture auditable retrieval runs for GPT-RAG's supported backends."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import os
import platform
import re
import shutil
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

import requests
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI

ADAPTER_VERSION = "1"
QUESTION_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} must be set.")
    return value


def as_bool(value: str | None, default: bool = False) -> bool:
    if value is None or not value.strip():
        return default
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"Invalid boolean value: {value!r}")


def load_questions(path: Path) -> list[dict[str, str]]:
    questions: list[dict[str, str]] = []
    seen: set[str] = set()
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        item = json.loads(line)
        question_id = str(item.get("id", "")).strip()
        query = str(item.get("query", "")).strip()
        split = str(item.get("split", "")).strip()
        if not QUESTION_ID_PATTERN.fullmatch(question_id):
            raise ValueError(
                f"{path}:{line_number}: id must match {QUESTION_ID_PATTERN.pattern}"
            )
        if question_id in seen:
            raise ValueError(f"{path}:{line_number}: duplicate id {question_id!r}")
        if not query or split not in {"tune", "held_out"}:
            raise ValueError(
                f"{path}:{line_number}: query is required and split must be "
                "'tune' or 'held_out'."
            )
        seen.add(question_id)
        questions.append({"id": question_id, "query": query, "split": split})
    if not questions:
        raise ValueError(f"{path} contains no questions.")
    return questions


def package_versions() -> dict[str, str]:
    versions: dict[str, str] = {}
    for package in ("azure-identity", "openai", "requests"):
        try:
            versions[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            versions[package] = "<not installed>"
    return versions


def search_headers(credential: DefaultAzureCredential) -> dict[str, str]:
    token = credential.get_token("https://search.azure.com/.default").token
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "x-ms-query-source-authorization": token,
    }


class DirectSearchAdapter:
    def __init__(
        self,
        credential: DefaultAzureCredential,
        approach: str,
        top_k: int,
        semantic: bool,
    ) -> None:
        if semantic and approach == "vector":
            raise ValueError("Semantic ranking is not supported for vector-only runs.")
        self.credential = credential
        self.approach = approach
        self.top_k = top_k
        self.semantic = semantic
        self.endpoint = required_env("SEARCH_SERVICE_QUERY_ENDPOINT").rstrip("/")
        self.api_version = required_env("SEARCH_API_VERSION")
        self.index_name = required_env("SEARCH_RAG_INDEX_NAME")
        self.semantic_config = os.getenv("SEARCH_SEMANTIC_SEARCH_CONFIG", "").strip()
        if semantic and not self.semantic_config:
            raise RuntimeError(
                "SEARCH_SEMANTIC_SEARCH_CONFIG must be set for a semantic run."
            )

        self.embedding_client: AzureOpenAI | None = None
        if approach in {"vector", "hybrid"}:
            token_provider = get_bearer_token_provider(
                credential, "https://cognitiveservices.azure.com/.default"
            )
            self.embedding_client = AzureOpenAI(
                api_version=required_env("OPENAI_API_VERSION"),
                azure_endpoint=required_env("AI_FOUNDRY_ACCOUNT_ENDPOINT"),
                azure_ad_token_provider=token_provider,
            )
            self.embedding_deployment = required_env("EMBEDDING_DEPLOYMENT_NAME")

    def config(self) -> dict[str, Any]:
        return {
            "backend": "ai_search",
            "adapter_version": ADAPTER_VERSION,
            "approach": self.approach,
            "top_k": self.top_k,
            "semantic": self.semantic,
            "search_endpoint": self.endpoint,
            "search_api_version": self.api_version,
            "index_name": self.index_name,
            "semantic_configuration": self.semantic_config or None,
            "conversation_scope": "shared_only",
            "source_authorization": "current_lab_identity",
        }

    def retrieve(self, query: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        body: dict[str, Any] = {
            "top": self.top_k,
            "select": "id,title,filepath,url,content",
            "filter": "(conversationId eq 'NaN' or conversationId eq null)",
        }
        if self.approach in {"term", "hybrid"}:
            body["search"] = query
        if self.approach in {"vector", "hybrid"}:
            assert self.embedding_client is not None
            embedding = self.embedding_client.embeddings.create(
                input=query, model=self.embedding_deployment
            ).data[0].embedding
            body["vectorQueries"] = [
                {
                    "kind": "vector",
                    "vector": embedding,
                    "fields": "contentVector",
                    "k": self.top_k,
                }
            ]
        if self.semantic:
            body.update(
                {
                    "queryType": "semantic",
                    "semanticConfiguration": self.semantic_config,
                    "captions": "extractive",
                    "answers": "extractive",
                }
            )

        url = (
            f"{self.endpoint}/indexes/{quote(self.index_name, safe='')}/docs/search"
            f"?api-version={quote(self.api_version, safe='')}"
        )
        response = requests.post(
            url,
            headers=search_headers(self.credential),
            json=body,
            timeout=120,
        )
        response.raise_for_status()
        payload = response.json()

        documents: list[dict[str, Any]] = []
        for rank, result in enumerate(payload.get("value", []), 1):
            document_id = str(result.get("id", "")).strip()
            if not document_id:
                raise RuntimeError("Azure AI Search returned a result without its key.")
            reranker_score = result.get("@search.rerankerScore")
            search_score = result.get("@search.score")
            score = reranker_score if reranker_score is not None else search_score
            documents.append(
                {
                    "document_id": document_id,
                    "rank": rank,
                    "relevance_score": float(score or 0.0),
                    "score_kind": (
                        "search_reranker_score"
                        if reranker_score is not None
                        else "search_score"
                    ),
                    "title": result.get("title"),
                    "source_locator": result.get("url") or result.get("filepath"),
                    "content": result.get("content") or "",
                }
            )
        return payload, documents


class FoundryIQAdapter:
    def __init__(
        self, credential: DefaultAzureCredential, top_k: int
    ) -> None:
        self.credential = credential
        self.top_k = top_k
        self.endpoint = (
            os.getenv("KNOWLEDGE_BASE_ENDPOINT")
            or required_env("SEARCH_SERVICE_QUERY_ENDPOINT")
        ).rstrip("/")
        self.knowledge_base = required_env("KNOWLEDGE_BASE_NAME")
        self.api_version = required_env("FOUNDRY_IQ_API_VERSION")
        self.source_name = required_env("FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME")
        source_kind = required_env("FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND")
        self.source_kind = "azureBlob" if source_kind == "managed" else source_kind
        self.filter_add_on_enabled = as_bool(
            os.getenv("FOUNDRY_IQ_FILTER_ADD_ON_ENABLED"), default=False
        )
        if self.filter_add_on_enabled:
            raise RuntimeError(
                "This isolated helper does not synthesize GPT-RAG's per-user "
                "filterAddOn. Run Pattern B security tests through the live "
                "orchestrator instead."
            )
        self.forward_source_auth = as_bool(
            os.getenv("FOUNDRY_IQ_FORWARD_SOURCE_AUTH"), default=True
        )

    def config(self) -> dict[str, Any]:
        return {
            "backend": "foundry_iq",
            "adapter_version": ADAPTER_VERSION,
            "top_k": self.top_k,
            "knowledge_base_endpoint": self.endpoint,
            "knowledge_base_name": self.knowledge_base,
            "api_version": self.api_version,
            "knowledge_source_name": self.source_name,
            "knowledge_source_kind": self.source_kind,
            "filter_add_on_enabled": self.filter_add_on_enabled,
            "forward_source_auth": self.forward_source_auth,
        }

    def retrieve(self, query: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        token = self.credential.get_token("https://search.azure.com/.default").token
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        if self.forward_source_auth:
            headers["x-ms-query-source-authorization"] = token

        body = {
            "intents": [{"search": query, "type": "semantic"}],
            "knowledgeSourceParams": [
                {
                    "knowledgeSourceName": self.source_name,
                    "kind": self.source_kind,
                    "includeReferences": True,
                    "includeReferenceSourceData": True,
                }
            ],
            "maxOutputDocuments": self.top_k,
        }
        url = (
            f"{self.endpoint}/knowledgebases/"
            f"{quote(self.knowledge_base, safe='')}/retrieve"
            f"?api-version={quote(self.api_version, safe='')}"
        )
        response = requests.post(url, headers=headers, json=body, timeout=180)
        response.raise_for_status()
        payload = response.json()
        references = payload.get("references", []) or []

        documents: list[dict[str, Any]] = []
        for rank, reference in enumerate(references, 1):
            source = reference.get("sourceData") or {}
            if not isinstance(source, dict):
                continue
            content = (
                source.get("snippet")
                or source.get("content")
                or source.get("text")
                or ""
            )
            doc_key = str(reference.get("docKey") or "").strip()
            locator = next(
                (
                    str(source.get(name)).strip()
                    for name in (
                        "blob_url",
                        "url",
                        "filepath",
                        "path",
                        "webUrl",
                        "driveItemId",
                        "oneLakeFilePath",
                        "abfssPath",
                    )
                    if source.get(name)
                ),
                "",
            )
            if doc_key:
                document_id = f"{self.source_kind}:docKey:{doc_key}"
            elif locator and content:
                digest = hashlib.sha256(content.encode("utf-8")).hexdigest()[:16]
                document_id = f"{self.source_kind}:{locator}#sha256:{digest}"
            else:
                raise RuntimeError(
                    "Foundry IQ returned a reference without docKey or stable "
                    "source metadata. Define a versioned identity mapping before "
                    "using this source for persistent qrels."
                )
            documents.append(
                {
                    "document_id": document_id,
                    "rank": rank,
                    "relevance_score": float(len(references) - rank + 1),
                    "score_kind": "returned_rank_derived",
                    "title": source.get("title") or doc_key or None,
                    "source_locator": locator or None,
                    "content": content,
                }
            )
        return payload, documents


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=("foundry_iq", "ai_search"), required=True)
    parser.add_argument("--questions", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--top-k", type=int, required=True)
    parser.add_argument(
        "--split", choices=("tune", "held_out", "all"), default="all"
    )
    parser.add_argument(
        "--approach", choices=("term", "vector", "hybrid"), default="hybrid"
    )
    parser.add_argument(
        "--semantic", action=argparse.BooleanOptionalAction, default=False
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.top_k < 1:
        raise ValueError("--top-k must be positive.")
    if args.out.exists():
        raise FileExistsError(f"Run directory already exists: {args.out}")

    questions = load_questions(args.questions)
    if args.split != "all":
        questions = [
            question for question in questions if question["split"] == args.split
        ]
        if not questions:
            raise ValueError(f"No questions use split {args.split!r}.")
    args.out.mkdir(parents=True)
    raw_dir = args.out / "raw"
    raw_dir.mkdir()
    shutil.copyfile(args.questions, args.out / "questions.jsonl")

    credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    adapter: DirectSearchAdapter | FoundryIQAdapter
    if args.backend == "ai_search":
        adapter = DirectSearchAdapter(
            credential, args.approach, args.top_k, args.semantic
        )
    else:
        adapter = FoundryIQAdapter(credential, args.top_k)

    config = {
        **adapter.config(),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "question_split": args.split,
        "questions_sha256": hashlib.sha256(
            args.questions.read_bytes()
        ).hexdigest(),
        "adapter_script_sha256": hashlib.sha256(
            Path(__file__).read_bytes()
        ).hexdigest(),
        "agent_strategy": os.getenv("AGENT_STRATEGY"),
        "corpus_version": os.getenv("CORPUS_VERSION"),
        "ingestion_version": os.getenv("INGESTION_VERSION"),
    }
    (args.out / "config.json").write_text(
        json.dumps(config, indent=2), encoding="utf-8"
    )
    environment = {
        "python": platform.python_version(),
        "platform": platform.platform(),
        "packages": package_versions(),
    }
    (args.out / "environment.json").write_text(
        json.dumps(environment, indent=2), encoding="utf-8"
    )

    retrieved: dict[str, Any] = {}
    timings: dict[str, Any] = {}
    for question in questions:
        started = time.perf_counter()
        payload, documents = adapter.retrieve(question["query"])
        latency_ms = round((time.perf_counter() - started) * 1000, 3)
        (raw_dir / f"{question['id']}.json").write_text(
            json.dumps(payload, indent=2), encoding="utf-8"
        )
        retrieved[question["id"]] = {**question, "documents": documents}
        timings[question["id"]] = {"latency_ms": latency_ms}
        print(
            f"{question['id']}: {len(documents)} documents in "
            f"{latency_ms:.1f} ms"
        )

    latencies = [item["latency_ms"] for item in timings.values()]
    timings["_summary"] = {
        "count": len(latencies),
        "p50_ms": statistics.median(latencies),
        "p95_ms": sorted(latencies)[math.ceil(len(latencies) * 0.95) - 1],
    }
    (args.out / "retrieved.json").write_text(
        json.dumps(retrieved, indent=2), encoding="utf-8"
    )
    (args.out / "timings.json").write_text(
        json.dumps(timings, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
