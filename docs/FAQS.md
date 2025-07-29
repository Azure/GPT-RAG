# Frequently Asked Questions (FAQ)

We will post commonly asked questions here as we received them.

## Cannot login to the VM using Key Vault

It is possible that if your deployment failed, the key vault value may have been overwritten.  You will need to find the correct password in the Key Vault (when the VM deployment actually occurred/succeeded) to login to Bastian.

## Can't use the VM MSI to deploy applications

If for some reason you cannot login to the VM using 'az login' or 'azd auth login' because of Entra restrictions, you will need to use the MSI to perform the final steps.  Currently not all permissions are assigned to the account.  You will need to assign various roles (such as Container Apps and Container Registry roles).
