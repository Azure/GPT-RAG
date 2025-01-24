# Multi-Environment Azure DevOps Setup

This document outlines the steps to set up a multi-environment workflow to deploy infrastructure and services to Azure using Azure Pipelines, taking the solution from proof of concept to production-ready.

> [!NOTE]
> Note that additional steps may be required when working with the Zero Trust Architecture Deployment to handle deploying to a network-isolated environment. This guide is currently focused on deploying the Basic Architecture Deployment.

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
- Personnel with the following access levels:
  - In Azure: Either Owner role or Contributor + User Access Administrator roles within the Azure subscription, which provides the ability to create and assign roles to a Service Principal
  - In Azure DevOps: Ability create and manage [Service Connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops), contribute to repository, create and manage pipelines, and Administrator access on [Default agent pool](https://learn.microsoft.com/en-us/azure/devops/pipelines/policies/permissions?view=azure-devops#set-agent-pool-security-in-azure-pipelines)
- The repository/respositories are cloned to your local machine

# Steps:

> [!NOTE]
> 1. All commands below are to be run in a Bash shell.
> 2. This guide aims to provide automated/programmatic steps for pipeline setup where possible. Manual setup is also possible, but not covered extensively in this guide. Please read more about manual pipeline setup [here](https://github.com/Azure/azure-dev/blob/main/cli/azd/docs/manual-pipeline-config.md).

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

- "Read & execute" Build permissions.
- "Source code, repositories, pull requests, and notifications" and "Full" Code permissions.
- "Read and manage environment" Environment permissions.
- "Use and manage" Pipeline Resources permissions.
- "Read, query, and manage" Service connections permissions.


```
export AZURE_DEVOPS_EXT_PAT=<your-pat>
```

> [!CAUTION]
> Do _not_ check your PAT into source control.

Then, get the GUID of your Azure DevOps organization. This will be used when setting the [issuer field for the federated credential](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity?view=azure-devops#create-a-managed-identity) in a later step. In this example, we will retrieve the GUID through the browser, but you may also develop a more sophisticated method to retrieve the GUID using the [Azure DevOps Accounts REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/account/accounts/list?view=azure-devops-rest-7.1&tabs=HTTP) (The Accounts API requires an [OAuth 2 token](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops) for authorization, setup of which is not covered in this guide).

To get the GUID of your Azure DevOps organization via browser:
1. In your browser, visit [https://app.vssps.visualstudio.com/_apis/accounts](https://app.vssps.visualstudio.com/_apis/accounts). Note that you must log into the account associated with your Azure DevOps Organization to access this page.
2. Press Ctrl+F to open the search bar and search for your Azure DevOps organization name.
3. The GUID will be in the `AccountId` field. Copy this GUID and set it as a variable.

    ```bash
    azdo_org_guid='<your-org-guid>'
    ```

Then, set some additional variables that will be used when setting up the environments, pipelines, and credentials:

```bash
org='<your-org-name>'
project='<your-repo-name>'
issuer=https://vstoken.dev.azure.com/$azdo_org_guid
audiences="api://AzureADTokenExchange"
```

### `azd` environments and Service Principal creation

Next, you will create an `azd` environment per target environment alongside a pipeline definition. In this guide, pipeline definitions are created with `azd pipeline config`. Read more about azd pipeline config [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/configure-devops-pipeline?tabs=azdo). View the CLI documentation [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-pipeline-config).

Login to Azure and `azd`, and configure the default organization and project:

```bash
az login
azd auth login
az devops configure --defaults organization=https://dev.azure.com/$org project=$project
```

Next, you will create the environments, service principals, and pipelines, followed by a new federated credential and service connection for each environment. The `azd pipeline config` creates a default credential and service connection which we will not use because we need to configure environment-specific connections.

When running `azd pipeline config` for each environment, enter your organization name, and choose your target Azure subscription and location. When prompted to commit and push your local changes to start the configured CI pipeline, enter 'N'.

> [!CAUTION]
> If you choose 'Y' to commit and push your local changes, the pipeline will be triggered, and you may not have the necessary environments or variables set up yet, causing the pipeline to fail. The remaining setup steps must be completed before the pipeline will run successfully.

##### Dev

**Setup:** Set up the Dev environment, pipeline, and service principal:
```bash
azd env new $dev_env
azd pipeline config --principal-name $dev_principal_name --provider azdo
```

**Post setup step #1:** Create a new federated credential in the Dev Service Principal
```bash
echo '{"name": "'"${org}-${project}-${dev_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${dev_env}"'", "description": "'"${dev_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

dev_client_id=$(az ad sp list --display-name $dev_principal_name --query "[].appId" --output tsv)

az ad app federated-credential create --id $dev_client_id --parameters ./federated_id.json

# delete the existing federated credential created by azd pipeline config
federated_cred_id=$(az ad app federated-credential list --id $dev_client_id --query "[?name=='AzureDevOpsOIDC'].id" --output tsv)
az ad app federated-credential delete --id $dev_client_id --federated-credential-id $federated_cred_id

rm federated_id.json # clean up temp file
```

**Post setup step #2:** Create a new service connection for the Dev environment

```bash
# First, delete the default service connection created by azd pipeline config
service_connection_id=$(az devops service-endpoint list --query "[?name=='azconnection'].id" --output tsv)

az devops service-endpoint delete --id $service_connection_id --yes

# Next, configure the parameters for creating a service connection tied to the federated credential created in the previous step.
NAME=$dev_env
PROJECT_ID=$(az devops project show --project $project --query "id" --output tsv)
PROJECT_NAME=$project
SERVICE_PRINCIPAL_ID=$dev_client_id
TENANT_ID=$(az ad sp show --id $dev_client_id --query "appOwnerOrganizationId" --output tsv)
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv)

# Populate the JSON template with the variables
export NAME PROJECT_ID PROJECT_NAME SERVICE_PRINCIPAL_ID TENANT_ID SUBSCRIPTION_ID SUBSCRIPTION_NAME
cat ./.azdo/pipelines/service-endpoint-config-template.json | envsubst > service_connection.json

# Create the new service connection
az devops service-endpoint create --service-endpoint-configuration ./service_connection.json

# Clean up temp files
rm service_connection.json
```

##### Test

**Setup:** Set up the Test environment, pipeline, and service principal:
```bash
azd env new $test_env
azd pipeline config --principal-name $test_principal_name --provider azdo
```

**Post setup step #1:** Create a new federated credential in the Test Service Principal
```bash
echo '{"name": "'"${org}-${project}-${test_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${test_env}"'", "description": "'"${test_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

test_client_id=$(az ad sp list --display-name $test_principal_name --query "[].appId" --output tsv)

az ad app federated-credential create --id $test_client_id --parameters ./federated_id.json

# delete the existing federated credential created by azd pipeline config
federated_cred_id=$(az ad app federated-credential list --id $test_client_id --query "[?name=='AzureDevOpsOIDC'].id" --output tsv)
az ad app federated-credential delete --id $test_client_id --federated-credential-id $federated_cred_id

rm federated_id.json # clean up temp file
```

**Post setup step #2:** Create a new service connection for the Test environment

```bash
# First, delete the default service connection created by azd pipeline config
service_connection_id=$(az devops service-endpoint list --query "[?name=='azconnection'].id" --output tsv)

az devops service-endpoint delete --id $service_connection_id --yes

# Next, configure the parameters for creating a service connection tied to the federated credential created in the previous step.
NAME=$test_env
PROJECT_ID=$(az devops project show --project $project --query "id" --output tsv)
PROJECT_NAME=$project
SERVICE_PRINCIPAL_ID=$test_client_id
TENANT_ID=$(az ad sp show --id $test_client_id --query "appOwnerOrganizationId" --output tsv)
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv)

# Populate the JSON template with the variables
export NAME PROJECT_ID PROJECT_NAME SERVICE_PRINCIPAL_ID TENANT_ID SUBSCRIPTION_ID SUBSCRIPTION_NAME
cat ./.azdo/pipelines/service-endpoint-config-template.json | envsubst > service_connection.json

# Create the new service connection
az devops service-endpoint create --service-endpoint-configuration ./service_connection.json

# Clean up temp files
rm service_connection.json
```

##### Prod

**Setup:** Set up the Prod environment, pipeline, and service principal:
```bash
azd env new $prod_env
azd pipeline config --principal-name $prod_principal_name --provider azdo
```

**Post setup step #1:** Create a new federated credential in the Prod Service Principal
```bash
echo '{"name": "'"${org}-${project}-${prod_env}"'", "issuer": "'"${issuer}"'", "subject": "'"sc://${org}/${project}/${prod_env}"'", "description": "'"${prod_env}"' environment", "audiences": ["'"${audiences}"'"]}' > federated_id.json

prod_client_id=$(az ad sp list --display-name $prod_principal_name --query "[].appId" --output tsv)

az ad app federated-credential create --id $prod_client_id --parameters ./federated_id.json

# delete the existing federated credential created by azd pipeline config
federated_cred_id=$(az ad app federated-credential list --id $prod_client_id --query "[?name=='AzureDevOpsOIDC'].id" --output tsv)
az ad app federated-credential delete --id $prod_client_id --federated-credential-id $federated_cred_id

rm federated_id.json # clean up temp file
```

**Post setup step #2:** Create a new service connection for the Prod environment

```bash
# First, delete the default service connection created by azd pipeline config
service_connection_id=$(az devops service-endpoint list --query "[?name=='azconnection'].id" --output tsv)

az devops service-endpoint delete --id $service_connection_id --yes

# Next, configure the parameters for creating a service connection tied to the federated credential created in the previous step.
NAME=$prod_env
PROJECT_ID=$(az devops project show --project $project --query "id" --output tsv)
PROJECT_NAME=$project
SERVICE_PRINCIPAL_ID=$prod_client_id
TENANT_ID=$(az ad sp show --id $prod_client_id --query "appOwnerOrganizationId" --output tsv)
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv)

# Populate the JSON template with the variables
export NAME PROJECT_ID PROJECT_NAME SERVICE_PRINCIPAL_ID TENANT_ID SUBSCRIPTION_ID SUBSCRIPTION_NAME
cat ./.azdo/pipelines/service-endpoint-config-template.json | envsubst > service_connection.json

# Create the new service connection
az devops service-endpoint create --service-endpoint-configuration ./service_connection.json

# Clean up temp files
rm service_connection.json
```

> [!TIP]
> Verify that the variables in the above steps are set by printing them out with the `echo` command.

> [!NOTE]
> The **"Post setup step #2"** actions above define several variables, populating them in a template JSON structure, found at `.azdo/pipelines/service-endpoint-config-template.json`. Read more about this approach [here](https://learn.microsoft.com/en-us/azure/devops/cli/service-endpoint?view=azure-devops#create-service-endpoint-using-configuration-file).

> [!NOTE]
> _Alternative approach to get the client IDs in the above steps:_
> In the event that there are multiple Service Principals containing the same name, the `az ad sp list` command executed above may not pull the correct ID. You may execute an alternate command to manually review the list of Service Principals by name and ID. The command to do this is exemplified below for the dev environment.
>
> ```bash
> az ad sp list --display-name $dev_principal_name --query "[].{DisplayName:displayName, AppId:appId}" --output table # return results in a table format
> dev_client_id='<guid>' # manually assign the correct client ID
> ```
>
> Also note you may get the client IDs from the Azure Portal.


After performing the above steps, you will see corresponding files to your azd environments in the `.azure` folder.

If you run `azd env list`, you will see the newly created environments.

You may change the default environment by running `azd env select <env-name>`, for example:

```bash
azd env select $dev_env
```

## 2. Set up Azure DevOps Environments

### Environment setup

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
> After environments are created, set up deployment protection rules for each environment. See [this article](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops&tabs=check-pass) for more. While approvers are not always necessary on the development environment, they are crucial for all other environments.

### Variable setup

Once the pipeline YML file is committed to the repository and the environments are set up, the `AZURE_ENV_NAME` pipeline variable needs to be deleted. This value is passed in at the environment level in the pipeline YML file. If you do not delete this pipeline variable, the pipeline will erroneously deploy to the same environment in every stage.

To do this in the Azure DevOps portal, navigate to the pipeline, edit the pipeline, open the variables menu, and delete the `AZURE_ENV_NAME` pipeline variable.

You may alternately run the below command to delete the variable; ensure you replace the pipeline ID with the correct ID. You can find the pipeline ID by navigating to the pipeline in the Azure DevOps portal and looking at the URL. This value is also printed out after running `azd pipeline config`, in the "Link to view your pipeline status".

```bash
az pipelines variable delete --name 'AZURE_ENV_NAME' --pipeline-id <pipeline-id>
```

## 3. Modify the workflow files as needed for deployment

> [!IMPORTANT]
> - The environment names are defined as variables within the below described `azure-dev.yml` file, **which need to be edited to match the environment names you created.** In this example, the environment name is also used as the service connection name. If you used different names for the environment name and service connection name, you will **also need to update the service connection parameter passed in each stage**.
> - The `trigger` in the `azure-dev.yml` file is set to `none` to prevent the pipeline from running automatically. You can change this to `main` or `master` to trigger the pipeline on a push to the main branch.

- The following files in the `.azdo/pipelines` folder are used to deploy the infrastructure and services to Azure:
  - `azure-dev.yml`
    - This is the main file that triggers the deployment workflow. The environment names are passed as inputs to the deploy job.
  - `deploy-template.yml`
    - This is a template file invoked by `azure-dev.yml` that is used to deploy the infrastructure and services to Azure.

## 4. Customization for your Enterprise

This end-to-end DevOps guide serves as a proof of concept of how to deploy your code to multiple environments and promote your code into production rapidly, just as the core RAG solution in this guide is intended to prove an end-to-end architecture with a frontend, orchestrator, and data ingestion service.

In the case of both this DevOps guide and the core RAG solution, you will likely want to customize the code and workflows to fit your enterprise's specific needs. For example, you may want to add additional tests, security checks, or other steps to the workflow. You may also have a different Git branching or deployment strategy that necessitates changes to the workflows. From a design perspective, you may choose to modularize the the workflows differently, or inject naming conventions or other enterprise-specific standards.

# Additional Resources:

- [Support multiple environments with `azd` (github.com)](https://github.com/jasontaylordev/todo-aspnetcore-csharp-sqlite/blob/main/OPTIONAL_FEATURES.md)
- [Azure DevOps Services REST API Reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-7.2)
- [Azure DevOps CLI service endpoint](https://learn.microsoft.com/en-us/azure/devops/cli/service-endpoint?view=azure-devops)