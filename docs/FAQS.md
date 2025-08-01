# Frequently Asked Questions (FAQ)

We will post commonly asked questions here as we received them.

## Cannot login to the VM using Key Vault

It is possible that if your deployment failed, the key vault value may have been overwritten.  You will need to find the correct password in the Key Vault (when the VM deployment actually occurred/succeeded) to login to Bastian.

## Can't use the VM MSI to deploy applications

If for some reason you cannot login to the VM using 'az login' or 'azd auth login' because of Entra restrictions, you will need to use the MSI to perform the final steps.  Ensure you are using the latest pull from the latest release branch that has the proper permissions assigned to the VM managed identity.

## Not able to connect to App Config

Ensure that the system or managed identity has the proper permission.  This includes App Configuration Data Reader and Key Vault Secrets User.

If using User Managed Identity, ensure that the 'AZURE_CLIENT_ID' is set to the matching value.

Double check that the app config url is set correctly in the container environment variables.

## AI Search Indexer is not being created

Check that the service private link between Azure AI Search and the other services is in an `Approved` status.

## Unable to start Docker Desktop in virtual machine

Ensure that dockerd process is stopped and then start docker desktop.
