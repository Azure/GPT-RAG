"""Score a normalized GPT-RAG retrieval run against backend-specific qrels."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from azure.ai.evaluation import DocumentRetrievalEvaluator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--retrieved", type=Path, required=True)
    parser.add_argument("--qrels", type=Path, required=True)
    parser.add_argument("--timings", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def numeric_metrics(result: dict[str, Any]) -> dict[str, float]:
    metrics: dict[str, float] = {}
    sources = [result]
    nested = result.get("document_retrieval_properties")
    if isinstance(nested, dict):
        sources.append(nested)
    for source in sources:
        for key, value in source.items():
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                numeric = float(value)
                if math.isfinite(numeric):
                    metrics[key] = numeric
    return metrics


def main() -> None:
    args = parse_args()
    retrieved = json.loads(args.retrieved.read_text(encoding="utf-8"))
    qrels = json.loads(args.qrels.read_text(encoding="utf-8"))
    evaluator = DocumentRetrievalEvaluator(
        ground_truth_label_min=0,
        ground_truth_label_max=4,
    )

    per_question: dict[str, dict[str, Any]] = {}
    aggregate_values: dict[str, list[float]] = {}
    for question_id, labels in qrels.items():
        if question_id not in retrieved:
            raise KeyError(f"Qrels question {question_id!r} is missing from the run.")
        documents = retrieved[question_id]["documents"]
        result = evaluator(
            retrieval_ground_truth=labels,
            retrieved_documents=[
                {
                    "document_id": document["document_id"],
                    "relevance_score": document["relevance_score"],
                }
                for document in documents
            ],
        )
        metrics = numeric_metrics(result)
        per_question[question_id] = metrics
        for key, value in metrics.items():
            aggregate_values.setdefault(key, []).append(value)

    aggregate = {
        key: {"mean": statistics.fmean(values), "count": len(values)}
        for key, values in sorted(aggregate_values.items())
    }
    output: dict[str, Any] = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "retrieved": str(args.retrieved),
        "retrieved_sha256": hashlib.sha256(args.retrieved.read_bytes()).hexdigest(),
        "qrels": str(args.qrels),
        "qrels_sha256": hashlib.sha256(args.qrels.read_bytes()).hexdigest(),
        "per_question": per_question,
        "aggregate": aggregate,
    }
    if args.timings:
        timings = json.loads(args.timings.read_text(encoding="utf-8"))
        output["latency"] = timings.get("_summary", {})

    args.output.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
