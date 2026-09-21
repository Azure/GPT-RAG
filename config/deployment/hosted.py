"""Hosted-agent deployment contract helpers."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from urllib.parse import urlsplit, urlunsplit


MAX_SMOKE_OUTPUT = 1024 * 1024


def _smoke_events(output: str) -> list[dict]:
    """Read Responses SSE or CLI JSON event lines, allowing azd progress text.

    Never search model-authored text for success/error markers. Protocol JSON
    must parse and SSE event names must agree with the event's type.
    """
    events: list[dict] = []
    data: list[str] = []
    event_name = ""

    def append(payload: str, expected_type: str = "") -> None:
        if payload == "[DONE]":
            if expected_type:
                raise ValueError("Unexpected named end-of-stream marker.")
            return
        try:
            event = json.loads(payload)
        except ValueError:
            raise ValueError("Malformed smoke response event; body omitted.") from None
        if (
            not isinstance(event, dict)
            or not isinstance(event.get("type"), str)
            or not event["type"]
            or (expected_type and event["type"] != expected_type)
        ):
            raise ValueError("Invalid smoke response event envelope; body omitted.")
        events.append(event)

    for line in [*output.splitlines(), ""]:
        line = line.strip()
        if not line:
            if data:
                append("\n".join(data), event_name)
            elif event_name:
                raise ValueError("Smoke SSE event is missing its data.")
            data = []
            event_name = ""
        elif line.startswith("event:"):
            if data or event_name:
                raise ValueError("Smoke SSE event boundary is missing.")
            event_name = line[6:].strip()
        elif line.startswith("data:"):
            data.append(line[5:].lstrip())
        elif line.startswith((":", "id:", "retry:")):
            continue
        elif line.startswith("{"):
            if data or event_name:
                raise ValueError("Mixed smoke response framing.")
            append(line)
        elif data or event_name:
            raise ValueError("Malformed smoke SSE framing.")
        # Non-protocol CLI progress lines are not completion evidence.
    return events


def validate_smoke_output(output: str) -> None:
    """Require one completed, nonempty greeting response without error events.

    Matches the published v4.1.1 Invocations Responses-SSE contract. This is a
    config/model smoke only, never evidence of document access or RBAC readiness
    for another principal. The validator is local and makes no requests.
    """
    if len(output) > MAX_SMOKE_OUTPUT:
        raise ValueError("Smoke response exceeds the bounded validation size.")
    completed: list[dict] = []
    for event in _smoke_events(output):
        kind = event["type"]
        response = event.get("response")
        if (
            kind in {"error", "response.failed", "response.incomplete", "response.cancelled"}
            or event.get("error") is not None
            or (isinstance(response, dict) and (
                response.get("error") is not None
                or response.get("status") in {"failed", "incomplete", "cancelled"}
            ))
        ):
            raise ValueError("Hosted greeting returned an error/incomplete event; body omitted.")
        if kind == "response.completed":
            if not isinstance(response, dict) or response.get("status") != "completed":
                raise ValueError("Hosted greeting has no successful terminal response.")
            completed.append(response)
    if len(completed) != 1:
        raise ValueError("Expected exactly one response.completed event.")
    items = completed[0].get("output")
    if not isinstance(items, list):
        raise ValueError("Completed greeting has no assistant output.")
    for item in items:
        if (
            not isinstance(item, dict)
            or item.get("type") != "message"
            or item.get("role") != "assistant"
            or item.get("status") != "completed"
        ):
            continue
        content = item.get("content")
        if isinstance(content, list) and any(
            isinstance(part, dict)
            and part.get("type") == "output_text"
            and isinstance(part.get("text"), str)
            and part["text"].strip()
            for part in content
        ):
            return
    raise ValueError("Completed greeting has no nonempty assistant output_text.")


def invocations_base_url(endpoint: str) -> str:
    """Return the base URL expected by a client that appends /invocations."""
    value = endpoint.strip()
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.netloc:
        raise ValueError("Hosted Invocations endpoint must be an absolute HTTPS URL.")
    if not parsed.path.endswith("/invocations"):
        raise ValueError(
            "Hosted Invocations endpoint path must end with '/invocations'."
        )
    base_path = parsed.path[: -len("/invocations")]
    return urlunsplit((parsed.scheme, parsed.netloc, base_path, "", ""))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--invocations-endpoint")
    mode.add_argument(
        "--validate-smoke", action="store_true",
        help="Validate captured greeting Responses SSE/JSON events from stdin; no network calls.",
    )
    args = parser.parse_args(argv)
    if args.validate_smoke:
        logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
        try:
            validate_smoke_output(sys.stdin.read(MAX_SMOKE_OUTPUT + 1))
        except ValueError as exc:
            logging.error("%s", exc)
            return 1
        logging.info("Hosted greeting completed. Document retrieval/authorization was not tested.")
        return 0
    print(invocations_base_url(args.invocations_endpoint))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
