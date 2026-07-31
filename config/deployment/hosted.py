"""Hosted-agent deployment contract helpers."""

from __future__ import annotations

import argparse
from urllib.parse import urlsplit, urlunsplit


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--invocations-endpoint", required=True)
    args = parser.parse_args()
    print(invocations_base_url(args.invocations_endpoint))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
