import os
from typing import Dict, Any
from azure.identity import ChainedTokenCredential, ManagedIdentityCredential, AzureCliCredential
from azure.appconfiguration import AzureAppConfigurationClient
from azure.core.exceptions import AzureError

class AppConfigClient:
    def __init__(self):
        """
        Bulk-loads all keys labeled 'gpt-rag' into an in-memory dict.
        """
        endpoint = os.getenv("APP_CONFIG_ENDPOINT")
        if not endpoint:
            raise EnvironmentError("APP_CONFIG_ENDPOINT must be set")

        credential = ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())
        client = AzureAppConfigurationClient(base_url=endpoint, credential=credential)

        self._settings: Dict[str, str] = {}

        try:
            for setting in client.list_configuration_settings(label_filter="gpt-rag"):
                self._settings[setting.key] = setting.value
        except AzureError as e:
            raise RuntimeError(f"Failed to bulk-load 'gpt-rag' settings: {e}")

    def get(self, key: str, default: Any = None) -> Any:
        """
        Returns the in-memory value for the given key.

        If the key was not found under either label, returns `default`.
        """
        return self._settings.get(key, default)