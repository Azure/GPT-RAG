# Multi-Environment Azure DevOps Setup

This document outlines the steps to set up a multi-environment workflow to deploy infrastructure and services to Azure using Azure Pipelines, taking the solution from proof of concept to production-ready.

# Assumptions:

- This example assumes you have an Azure DevOps Organization and Project already set up.
- This example deploys the infrastructure in the same pipeline as all of the services.
- This example deploys three environments: dev, test, and prod. You may modify the number and names of environments as needed.
- This example uses [`azd pipeline config`](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/configure-devops-pipeline?tabs=azdo) to rapidly set up Azure Pipelines and federated identity configuration for enhanced security.
- All below commands are run as a one-time setup on a local machine by an admin who has access to the Azure DevOps Project and Azure tenant.
- This example does not cover configuring any naming conventions.
- The original remote versions of the [orchestrator](https://github.com/Azure/gpt-rag-orchestrator), [frontend](https://github.com/Azure/gpt-rag-frontend), and [ingestion](https://github.com/Azure/gpt-rag-ingestion) repositories are used; in a real scenario, you would fork these repositories and use your forked versions. This would require updating the repository URLs in the `scripts/fetchComponents.*` files.
- Bicep is the IaC language used in this example.

# Decisions required:

- Service Principals that will be used for each environment
- Decisions on which Azure DevOps Repo, Azure subscription, and Azure location to use

# Prerequisites:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli) with [Azure DevOps extension](https://learn.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows)
- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4)
- [Git](https://git-scm.com/downloads)
- Azure DevOps organization
- Bash shell (e.g., Git Bash)
- Personnel with Azure admin (can create Service Principals) and Azure DevOps admin (owns repository/project) access
- The code in the repository needs to exist in Azure Repos and you need to have it cloned locally. [This guide](https://github.com/Azure/azure-dev/blob/main/cli/azd/docs/manual-pipeline-config.md) may be useful if you run into issues setting up your repository.

# Steps:

> [!NOTE]
> All commands below are to be run in a Bash shell.

## 1. Create `azd` environments & Service Principals

### Setup

`cd` to the root of the repo. Before creating environments, you need to define the environment names. Note that these environment names are reused as the Azure DevOps environment names and service connection names later.

```bash
dev_env='<dev-env-name>' # Example: dev
test_env='<test-env-name>' # Example: test
prod_env='<prod-env-name>' # Example: prod
```

Next, define the names of the Service Principals that will be used for each environment. You will need the name in later steps.
Note that `azd pipeline config` creates a new Service Principal for each environment.

```bash
dev_principal_name='<dev-sp-name>'
test_principal_name='<test-sp-name>'
prod_principal_name='<prod-sp-name>'
```

Then, get a personal access token (PAT) from Azure DevOps and set the AZURE_DEVOPS_EXT_PAT environment variable. [This guide](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows#create-a-pat) describes how to create a PAT. Ensure the PAT has:

- "Use and manage" Pipeline Resources permissions.
- "Source code, repositories, pull requests, and notifications" and "Full" Code permissions.
- "Read and manage environment" Environment permissions.
- "Read, query, and manage" Service connections permissions.
- "Read & execute" Build permissions.

```
export AZURE_DEVOPS_EXT_PAT=<your-pat>
```

### `azd` environments

Next, you will create an `azd` environment per target environment alongside a pipeline definition. In this guide, pipeline definitions are created with `azd pipeline config`. Read more about azd pipeline config [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/configure-devops-pipeline?tabs=azdo). View the CLI documentation [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-pipeline-config).

> [!IMPORTANT]
> The `azd pipeline config` command will create the service principal and service connection. Note that the service connection will always be created with the name `azconnection`, so after each `azd pipeline config` command, you will need to perform 2 post-setup actions:
>
> 1. Run the provided command to update the Subject identifier in the federated credential. _In this example, we will be using the name of the environment._
> 2. [Update the service connection](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops#edit-a-service-connection) name to match the final section of the Subject identifier (in this example, with the name of the environment). This will be done in the Azure DevOps web app. You may get a warning when you do this - choose 'Keep as draft', then 'Finish setup', then 'Verify and save'.

When running `azd pipeline config` for each environment, choose **Azure DevOps** as the provider, choose your target Azure subscription, and Azure location. When prompted to commit and push your local changes to start the configured CI pipeline, say 'N'.

Login to Azure:

```bash
az login
```

Then, set some variables that will be used:

```bash
org='<your-org-name>'
project='<your-repo-name>'
issuer='https://vstoken.dev.azure.com/be306e75-95ac-461a-a54e-5fd100dbb1b8'
audiences="api://AzureADTokenExchange"
```

Create the environments and update the federated credential for each environment:

#### Dev

```bash
azd env new $dev_env
azd pipeline config --principal-name $dev_principal_name --provider azdo

# Post setup 1: Update the subject identifier in the federated credential
echo '{"name": "'"${org}-${project}-${dev_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${dev_env}"'", "description": "'"${dev_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

dev_client_id=$(az ad sp list --display-name $dev_principal_name --query "[].appId" --output tsv) # get client ID

az ad app federated-credential create --id $dev_client_id --parameters ./federated_id.json

# Post setup 2: Update the service connection name to match the environment name in the Azure DevOps Portal
```

#### Test

```bash
azd env new $test_env
azd pipeline config --principal-name $test_principal_name --provider azdo

echo '{"name": "'"${org}-${project}-${test_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${test_env}"'", "description": "'"${test_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

test_client_id=$(az ad sp list --display-name $test_principal_name --query "[].appId" --output tsv) # get client ID

az ad app federated-credential create --id $test_client_id --parameters ./federated_id.json

# Post setup 2: Update the service connection name to match the environment name in the Azure DevOps Portal
```

#### Prod

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
rm federated_id.json # clean up temp file
```

> [!NOTE]
> _Alternative approach to get the client IDs in the above steps:_
> In the event that there are multiple Service Principals containing the same name, the `az ad sp list` command executed above may not pull the correct ID. You may execute an alternate command to manually review the list of Service Principals by name and ID. The command to do this is exemplified below for the dev environment.
>
> ```bash
> az ad sp list --display-name $dev_principal_name --query "[].{DisplayName:displayName, > AppId:appId}" --output table # return results in a table format
> dev_client_id='<guid>' # manually assign the correct client ID
> ```
>
> Also note you may also get the client IDs from the Azure Portal.

> [!NOTE]
> The existing/unmodified federated credentials created by Azure Developer CLI in the Service Principals may be deleted.

After performing the above steps, you will see corresponding files to your azd environments in the `.azure` folder.

If you run `azd env list`, you will see the newly created environments.

You may change the default environment by running `azd env select <env-name>`, for example:

```bash
azd env select $dev_env
```

## 2. Set up Azure DevOps Environments

### Environment setup

Login to Azure DevOps (ensure you previously ran `az login`) and configure the default organization and project:

```bash
az devops configure --defaults organization=https://dev.azure.com/$org project=$project
```

Run `az devops` CLI commands to create the environments:

```bash
echo "{\"name\": \"$dev_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

echo "{\"name\": \"$test_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

echo "{\"name\": \"$prod_env\"}" > azdoenv.json
az devops invoke --area distributedtask --resource environments --route-parameters project=$project --api-version 7.1 --http-method POST --in-file ./azdoenv.json

rm azdoenv.json # clean up temp file
```

> [!TIP]
> After environments are created, consider setting up deployment protection rules for each environment. See [this article](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops&tabs=check-pass) for more.

### Variable setup

Once the pipeline YML file is committed to the repository and the environments are set up, the `AZURE_ENV_NAME` pipeline variable needs to be deleted. This value is passed in at the environment level in the pipeline YML file. If you do not delete this pipeline variable, the pipeline will erroneously deploy to the same environment in every stage.

To do this in the Azure DevOps portal, navigate to the pipeline, edit the pipeline, open the variables menu, and delete the `AZURE_ENV_NAME` pipeline variable.

You may alternately run the below command to delete the variable; ensure you replace the pipeline ID with the correct ID. You can find the pipeline ID by navigating to the pipeline in the Azure DevOps portal and looking at the URL.

```bash
az pipelines variable delete --name 'AZURE_ENV_NAME' --pipeline-id <pipeline-id>
```

## 3. Modify the workflow files as needed for deployment

- The following files in the `.azdo/pipelines` folder are used to deploy the infrastructure and services to Azure:
  - `azure-dev.yml`
    - This is the main file that triggers the deployment workflow. The environment names are passed as inputs to the deploy job. These environment names are defined as variables within the .yml file, **which needs to be edited to match the environment names you created.** In this example, the environment name is also used as the service connection name. If you used different names for the environment name and service connection name, you will **also need to update the service connection parameter passed in each stage**.
    - You may edit the trigger to suit your pipeline trigger needs.
  - `deploy-template.yml`
    - This is a template file invoked by `azure-dev.yml` that is used to deploy the infrastructure and services to Azure.

# Additional Resources:

- [Support multiple environments with `azd` (github.com)](https://github.com/jasontaylordev/todo-aspnetcore-csharp-sqlite/blob/main/OPTIONAL_FEATURES.md)
