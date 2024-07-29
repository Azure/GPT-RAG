# Multi-Environment Azure DevOps Setup

This document outlines the steps to set up a multi-environment workflow to deploy infrastructure and services to Azure using Azure Pipelines, taking the solution from proof of concept to production-ready.

# Assumptions:

- This example assumes you have an Azure DevOps Organization and Project set up
- This is a tightly coupled example, which deploys infrastructure in the same pipeline as all of the services
- This example deploys 3 environments: dev, test, and prod
- This example uses 'azd pipeline config' (https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/configure-devops-pipeline?tabs=azdo), which as of writing, is in preview. This feature enables rapid Azure Pipeline setup
- All below commands are run as a one-time setup on a local machine by an admin who has access to the Azure Repo and Azure subscription
- This example does not cover configuring any naming conventions
- Original remote versions of the orchestrator, frontend, and ingestion repositories are used; in a real scenario, you would fork these repositories and use your forked versions. This would require updating the repository URLs in the azure.yaml file.

# Decisions required:

- Service Principals that will be used for each environment
- Decisions on which Azure Repo, Azure subscription, and Azure location to use

# Prerequisites:

- Azure CLI (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli) with Azure DevOps extension (https://learn.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)
- Azure Developer CLI (https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows)
- PowerShell 7 (https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4)
- Git (https://git-scm.com/downloads)
- Azure DevOps organization
- Bash shell (e.g. Git Bash)
  - Note that all commands are written for bash shell
- Personnel with Azure admin (can create Service Principals) and Azure DevOps admin (owns repo/org) access
- The code in the repository needs to exist in Azure Repos and you need to have it cloned locally. This guide may be useful if you run into issues setting up your repository: https://github.com/Azure/azure-dev/blob/main/cli/azd/docs/manual-pipeline-config.md

# Steps:

<!-- ## 1. Create Service Principals for each env -->

<!-- CLI: https://learn.microsoft.com/en-us/cli/azure/azure-cli-sp-tutorial-1?tabs=bash#create-a-service-principal

Portal: https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal

Note: You will need the app name in later steps

```bash
dev_principal_name='<dev-sp-name>'
test_principal_name='<test-sp-name>'
prod_principal_name='<prod-sp-name>'
```

Given the name of the Service Principal, get the client ID. You will need the client ID for later steps.

Login and query for the DisplayName and AppId and place the value in a variable. In the event that there are multiple Service Principals containing the same name, so you need to pull the correct ID. These can also be retrieved from the Azure portal.

```bash
az login
# example: az ad sp list --display-name $dev_principal_name --query "[].{DisplayName:displayName, AppId:appId}" --output table
dev_client_id='<dev-sp-client-id>'
test_client_id='<test-sp-client-id>'
prod_client_id='<prod-sp-client-id>'
``` -->

All commands below are run in a bash shell.

## 1. Create azd environments & Service Principals

`cd` to the root of the repo. Before creating environments, define the environment names. Note that these environment names are reused as the Azure DevOps environment names and service connection names later.

```bash
dev_env='<dev-env-name>' # Example: dev
test_env='<test-env-name>' # Example: test
prod_env='<prod-env-name>' # Example: prod
```

Then, create an azd environment per target environment alongside a pipeline definition. In this guide, pipeline definitions are created with `azd pipeline config`. Read more about azd pipeline config: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/configure-devops-pipeline?tabs=GitHub. CLI Doc: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-pipeline-config

Define the names of the Service Principals that will be used for each environment. You will need the name in later steps.
Note that `azd pipeline config` creates a new Service Principal for each environment.
<!-- There are a variety of ways to complete the setup below, e.g., you may manually perform all steps below for additional control, you may elect to use a single Service Principal for all environments, etc. -->

```bash
dev_principal_name='<dev-sp-name>'
test_principal_name='<test-sp-name>'
prod_principal_name='<prod-sp-name>'
```

Get a personal access token from Azure DevOps and set the AZURE_DEVOPS_EXT_PAT environment variable (https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows#create-a-pat). Ensure the PAT has:

- "Use and manage" Pipeline Resources permissions.
- "Source code, repositories, pull requests, and notifications" and "Full" Code permissions.
- "Read and manage environment" Environment permissions.
- "Read, query, and manage" Service connections permissions.
- "Read & execute" Build permissions.

```
export AZURE_DEVOPS_EXT_PAT=<your-pat>
```

Login to Azure:

```bash
az login
```

When running `azd pipeline config` for each environment, choose **Azure DevOps** as provider, Az subscription, and Az location. When prompted to commit and push your local changes to start the configured CI pipeline, say 'N'.

The `azd pipeline config` command will create the service principal and service connection. Note that the service connection will always be created with the name `azconnection`, so after each `azd pipeline config` command, you will need to perform 2 post-setup actions:

1. Run the provided command to update the Subject identifier in the federated credential. In this example, we will be using the name of the environment.
2. Update the service connection name to match the final section of the Subject identifier (in this example, with the name of the environment). This will be done in the Azure DevOps web app. You may get a warning when you do this - choose 'Keep as draft', then 'Finish setup', then 'Verify and save'.

First, set some variables that will be used:

```bash
org='<your-org-name>'
project='<your-repo-name>'
issuer='https://vstoken.dev.azure.com/be306e75-95ac-461a-a54e-5fd100dbb1b8'
audiences="api://AzureADTokenExchange"
```

Create the environments and update the federated credential for each environment:

### Dev

```bash
azd env new $dev_env
azd pipeline config --principal-name $dev_principal_name --provider azdo

# Post setup 1: Update the subject identifier in the federated credential
echo '{"name": "'"${org}-${project}-${dev_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${dev_env}"'", "description": "'"${dev_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

dev_client_id=$(az ad sp list --display-name $dev_principal_name --query "[].appId" --output tsv) # get client ID

az ad app federated-credential create --id $dev_client_id --parameters ./federated_id.json

# Post setup 2: Update the service connection name to match the environment name in the Azure DevOps Portal
```

### Test

```bash
azd env new $test_env
azd pipeline config --principal-name $test_principal_name --provider azdo

echo '{"name": "'"${org}-${project}-${test_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${test_env}"'", "description": "'"${test_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

test_client_id=$(az ad sp list --display-name $test_principal_name --query "[].appId" --output tsv) # get client ID

az ad app federated-credential create --id $test_client_id --parameters ./federated_id.json

# Post setup 2: Update the service connection name to match the environment name in the Azure DevOps Portal
```

### Prod

```bash
azd env new $prod_env
azd pipeline config --principal-name $prod_principal_name --provider azdo

echo '{"name": "'"${org}-${project}-${prod_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${prod_env}"'", "description": "'"${prod_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

prod_client_id=$(az ad sp list --display-name $prod_principal_name --query "[].appId" --output tsv) # get client ID

az ad app federated-credential create --id $prod_client_id --parameters ./federated_id.json

# Post setup 2: Update the service connection name to match the environment name in the Azure DevOps Portal
```

Clean up the temporary files:
```bash
rm federated_id.json # clean up
```

- _Alternative approach to get the client IDs in the above steps:_

  In the event that there are multiple Service Principals containing the same name, review the table of results to pull the correct ID. The command to do this is exemplified below for the dev environment.

  ```bash
  az ad sp list --display-name $dev_principal_name --query "[].{DisplayName:displayName, AppId:appId}" --output table # return results in a table format
  dev_client_id='<guid>'
  ```

  You can also get the client IDs from the Azure Portal.

Note: The existing/unmodified federated credentials created by Azure Developer CLI in the Service Principals may be deleted.

After performing the above steps, you will see corresponding files to your azd environments in the `.azure` folder.

If you run `azd env list`, you will see the newly created environments.

You may change the default environment by running `azd env select <env-name>`, for example:

```bash
azd env select $dev_env
```

# 2. Set up Azure DevOps Environments

Login to Azure DevOps (ensure you previously ran `az login`) and configure the default organization and project:

```bash
az devops configure --defaults organization=https://dev.azure.com/$org project=$project
```

Run az devops CLI commands to create the environments:

```bash
echo "{\"name\": \"$dev_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

echo "{\"name\": \"$test_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

echo "{\"name\": \"$prod_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

rm azdoenv.json # clean up
```


Consider setting up deployment protection rules for each environment. (https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops&tabs=check-pass)

Once the pipeline YML file is committed to the repository and the environments are set up, navigate to the Pipeline in Azure DevOps, edit the pipeline, open the variables menu, and delete the AZURE_ENV_NAME pipeline variable from the Azure DevOps portal. This value is passed in at the environment level in the pipeline YML file.

# 3. Modify the workflow files as needed for deployment

- The following files in the `.azdo/pipelines` folder are used to deploy the infrastructure and services to Azure:
  - azure-dev.yml
    - This is the main file that triggers the deployment workflow. The environment names are passed as inputs to the deploy job. These environment names are defined as variables within the .yml file, **which needs to be edited to match the environment names you created.** In this example, the environment name is also used as the service connection name. If you used different names for the environment name and service connection name, you will **also need to update the service connection parameter passed in each stage**.
    - You may edit the trigger to suit your pipeline trigger needs.
  - deploy-template.yml
    - This is a template file that is used to deploy the infrastructure and services to Azure.

# TODOs and potential improvements:

- Provide example of how to configure naming conventions
- Provide example of setting up self-hosted runners for network-restricted deployments
- Consider decoupling infrastructure and app code deployments
- Offer branching strategy guidance
- Update deploy.yml to only deploy service(s) which have changed (with `azd deploy <service>`)
  - this would require a more complex workflow to determine which services have changed, and each service is in a separate repository
