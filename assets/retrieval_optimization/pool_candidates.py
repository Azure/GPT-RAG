"""Pool normalized retrieval candidates across immutable runs."""

from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--retrieved",
        nargs="+",
        required=True,
        help="One or more retrieved.json paths or glob patterns.",
    )
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    paths = sorted(
        {
            Path(match)
            for pattern in args.retrieved
            for match in glob.glob(pattern)
        }
    )
    if not paths:
        raise FileNotFoundError("No retrieved.json files matched.")

    pool: dict[str, dict[str, Any]] = {}
    for path in paths:
        payload = json.loads(path.read_text(encoding="utf-8"))
        for question_id, question in payload.items():
            entry = pool.setdefault(
                question_id,
                {
                    "query": question["query"],
                    "split": question["split"],
                    "candidates": {},
                },
            )
            if entry["query"] != question["query"]:
                raise ValueError(
                    f"Question {question_id!r} has inconsistent query text."
                )
            for document in question["documents"]:
                document_id = document["document_id"]
                candidate = entry["candidates"].setdefault(
                    document_id,
                    {
                        "document_id": document_id,
                        "title": document.get("title"),
                        "source_locator": document.get("source_locator"),
                        "content": document.get("content", ""),
                        "seen_in": [],
                    },
                )
                candidate["seen_in"].append(str(path))

    output = {
        question_id: {
            "query": item["query"],
            "split": item["split"],
            "candidates": sorted(
                item["candidates"].values(), key=lambda value: value["document_id"]
            ),
        }
        for question_id, item in sorted(pool.items())
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(f"Wrote {args.output} from {len(paths)} run(s).")


if __name__ == "__main__":
    main()
