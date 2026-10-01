"""Minimal Container App for Agent Landing Zone.

GET /health  -> 200 {"status": "ok"}
GET /        -> the platform outputs this app can see (endpoints only).

The app reads APP_CONFIG_ENDPOINT from its environment and resolves the
platform outputs contract (AGENTLZ_PLATFORM_OUTPUTS, label agent-lz) with its
managed identity. No secrets are read or returned.
"""

from __future__ import annotations

import json
import logging
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from azure.appconfiguration import AzureAppConfigurationClient
from azure.identity import DefaultAzureCredential

LABEL = "agent-lz"
OUTPUTS_KEY = "AGENTLZ_PLATFORM_OUTPUTS"
LOGGER = logging.getLogger("sample")


def platform_outputs() -> dict[str, object]:
    endpoint = os.environ["APP_CONFIG_ENDPOINT"]
    client = AzureAppConfigurationClient(endpoint, DefaultAzureCredential())
    setting = client.get_configuration_setting(key=OUTPUTS_KEY, label=LABEL)
    return json.loads(setting.value or "{}")


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: dict[str, object]) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802 - http.server API
        if self.path == "/health":
            self._send(200, {"status": "ok"})
        elif self.path == "/":
            try:
                self._send(200, {"platformOutputs": platform_outputs()})
            except Exception:  # report a generic error, log the detail
                LOGGER.exception("Could not read platform outputs.")
                self._send(503, {"error": "platform outputs unavailable"})
        else:
            self._send(404, {"error": "not found"})


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
