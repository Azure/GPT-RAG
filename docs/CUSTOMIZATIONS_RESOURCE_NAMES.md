# Customizing resources names

By default, `azd` will automatically generate a unique name for each resource. The unique name is created based on the azd-environment name, the subscription name and the location. However, you can also manually define the name for each resource.

Each resource name has a direct mapping to an environment variable, for example, Storage Account name is defined by the `AZURE_STORAGE_ACCOUNT_NAME` variable.

So you can set `AZURE_STORAGE_ACCOUNT_NAME` to define the name for the storage account, by running the command before provisioning your resources:

```
azd env set AZURE_STORAGE_ACCOUNT_NAME <yourResourceNameHere>
```

This is the full list of resource names variables:

- AZURE_AI_SERVICES_NAME
- AZURE_AI_SERVICES_PE
- AZURE_AI_SUBNET_NAME
- AZURE_APP_INSIGHTS_NAME
- AZURE_APP_INT_SUBNET_NAME
- AZURE_APP_SERVICE_NAME
- AZURE_APP_SERVICE_PLAN_NAME
- AZURE_APP_SERVICES_SUBNET_NAME
- AZURE_BASTION_KV_NAME
- AZURE_BASTION_SUBNET_NAME
- AZURE_DATABASE_SUBNET_NAME
- AZURE_DATA_INGEST_FUNC_NAME
- AZURE_DATA_INGESTION_PE
- AZURE_DB_ACCOUNT_NAME
- AZURE_DB_ACCOUNT_PE
- AZURE_FRONTEND_PE
- AZURE_KEY_VAULT_NAME
- AZURE_KEYVAULT_PE
- AZURE_LOAD_TESTING_NAME
- AZURE_OPENAI_SERVICE_NAME
- AZURE_OPEN_AI_PE
- AZURE_ORCHESTRATOR_FUNCTION_APP_NAME
- AZURE_ORCHESTRATOR_PE
- AZURE_RESOURCE_GROUP_NAME
- AZURE_SEARCH_PE
- AZURE_SEARCH_SERVICE_NAME
- AZURE_STORAGE_ACCOUNT_NAME
- AZURE_STORAGE_ACCOUNT_PE
- AZURE_VM_NAME
- AZURE_VNET_NAME


> The resource related to the name can be directly inferred from the variable name. However, if you have any doubts, you can visit the [main.bicep](../infra/main.bicep) file and look for the resource associated with this variable (the variables can be found at the end of the file in the template outputs section).