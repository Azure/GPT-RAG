import os
from azure.identity import ChainedTokenCredential, ManagedIdentityCredential, AzureCliCredential
from azure.keyvault.secrets import SecretClient
from azure.core.exceptions import AzureError
from .appconfig import AppConfigClient

class KeyVaultClient:
    """
    Simple wrapper to fetch and set secrets in Azure Key Vault.
    Optionally accepts a vault URI; if not provided, reads KEY_VAULT_URI from App Configuration.
    """
    def __init__(self, vault_uri: str = None):
        # Determine vault URI
        if vault_uri is None:
            cfg = AppConfigClient()
            vault_uri = cfg.get("KEY_VAULT_URI")
            if not vault_uri:
                raise EnvironmentError("KEY_VAULT_URI must be set to your Key Vault URI in App Configuration")
        # Authenticate
        credential = ChainedTokenCredential(AzureCliCredential(),ManagedIdentityCredential())
        try:
            self._client = SecretClient(vault_url=vault_uri, credential=credential)
        except AzureError as e:
            raise RuntimeError(f"Failed to create SecretClient: {e}")

    def get_secret(self, name: str) -> str:
        """
        Returns the secret value, or raises on error.
        """
        try:
            secret = self._client.get_secret(name)
            return secret.value
        except AzureError as e:
            raise RuntimeError(f"Error retrieving secret '{name}': {e}")

    def set_secret(self, name: str, value: str) -> None:
        """
        Stores (or updates) a secret in Key Vault.
        """
        try:
            self._client.set_secret(name, value)
        except AzureError as e:
            raise RuntimeError(f"Error setting secret '{name}': {e}")
