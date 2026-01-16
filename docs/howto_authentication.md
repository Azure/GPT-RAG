# Authentication and Document level Security

This page explains how authentication works in GPT-RAG, from the Chainlit UI sign-in to calling Azure AI Search with permission trimming. The key idea is intentionally simple: the UI forwards a single user token to the orchestrator, and the orchestrator takes responsibility for producing the correct “user context” token required by Azure AI Search.

Key takeaway: the orchestrator receives an API token and then performs an On-Behalf-Of exchange to obtain a separate token for Azure AI Search. The two tokens have different audiences and are not interchangeable.

**Prerequisites**

Microsoft Entra ID must be configured to allow an On-Behalf-Of exchange. That means the orchestrator must be a confidential client and needs access to a client secret.

The UI must forward the signed-in user’s access token to the orchestrator in the `Authorization` header. Without a user token, the orchestrator cannot acquire the delegated Azure AI Search token.

Your Azure AI Search index must be configured for permission trimming, and your indexed documents must include the required security metadata fields.

Tenant consent must be granted for the Azure AI Search delegated permission. If consent is missing, the On-Behalf-Of exchange fails. In this repo, the only supported fallback is to run without authentication by setting `ALLOW_ANONYMOUS` to `true`.

Microsoft Graph delegated permissions such as `User.Read` are not required for this flow. The UI must request an access token for the orchestrator API. If the UI sends a token whose audience is Microsoft Graph, the orchestrator rejects it and the exchange cannot succeed.

**How it works**

<div class="no-wrap">
```
	+---------------------------+                 +----------------------------------+
	|  Microsoft Entra ID       |                 |  Azure AI Search                 |
	|  Tenant                   |                 |  Index with permission trimming  |
	|                           |                 |  permissionFilterOption=enabled  |
	+---------------------------+                 +----------------------------------+
			^													   ^
			|													   |
			| (4) Search user token                                | (6) Search query
			|  aud: https://search.azure.com                       |   Authorization: (orchestrator identity)
			|  scope: https://search.azure.com/user_impersonation
			|													   | x-ms-query-source-authorization: (search user token)
			|													   |
			|													   |
	+---------------------------+         (3) OBO exchange         |
	|  Orchestrator             |----------------------------------+
	|  Container App            |   to Entra ID token endpoint
	|                           |
	|  Validates API token      |   Inputs
	|  Uses client secret       |   - incoming user token
	|  Uses MI or admin key     |   - client id and client secret
	+---------------------------+   - requested scope for Search
						^
						|
						| (2) API token
						|     aud: api://<CLIENT_ID>
						|     scope: api://<CLIENT_ID>/user_impersonation
						|
	+---------------------------+
	|  Frontend                 |
	|  Container App            |
	|  Chainlit OAuth           |
	+---------------------------+
						^
						|
						| (1) User sign-in
						|     Entra issues API token
						|
	+---------------------------+
	|  App Registration         |
	|  Single registration for  |
	|  UI and orchestrator      |
	+---------------------------+
```
</div>

**Which token goes where**

After the user signs in, the UI forwards the API access token to the orchestrator.

```
Authorization: Bearer <api_access_token>
```

When the orchestrator calls Azure AI Search with permission trimming enabled, it sends two independent credentials:

1) The orchestrator authenticates the request using its own identity.

2) The orchestrator includes a delegated user token for Azure AI Search, produced via On-Behalf-Of.

```
x-ms-query-source-authorization: Bearer <search_user_access_token>
```

Do not send the API token in `x-ms-query-source-authorization`. Azure AI Search expects a token issued for `https://search.azure.com`.

**Setup**

This procedure configures Microsoft Entra ID so the UI can sign users in and the orchestrator can perform an On-Behalf-Of exchange.

1) Create one App Registration in Microsoft Entra ID. Use the same application identity for the UI and the orchestrator.

2) In the App Registration, add a Web platform redirect URI for the Chainlit callback endpoint.

```
https://<YOUR-APP-URL>/auth/oauth/azure-ad/callback
```

3) Expose an API for the orchestrator and create one delegated scope.

```
api://<OAUTH_AZURE_AD_CLIENT_ID>
api://<OAUTH_AZURE_AD_CLIENT_ID>/user_impersonation
```

4) Create a client secret. The orchestrator uses it to authenticate as a confidential client during the On-Behalf-Of exchange.

5) Grant the Azure AI Search delegated permission `user_impersonation`, then grant tenant consent.

If you configure this in the portal, the navigation usually looks like this.

```
API permissions
  Add a permission
    APIs my organization uses
      Azure Cognitive Search
        Delegated permissions
          user_impersonation
  Grant admin consent
```

If Azure Cognitive Search does not appear in the picker for your tenant, configure the permission using CLI. First, discover the Azure AI Search resource application id and the scope id for `user_impersonation`.

```
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals?$filter=servicePrincipalNames/any(s:s eq 'https://search.azure.com')&$select=appId,displayName,oauth2PermissionScopes" --query "value[0].{resourceAppId:appId,scopeId:oauth2PermissionScopes[?value=='user_impersonation'].id | [0],name:displayName}"
```

Then add the permission to your App Registration and grant consent.

```
az ad app permission add --id <OAUTH_AZURE_AD_CLIENT_ID> --api <SEARCH_RESOURCE_APP_ID> --api-permissions <SCOPE_ID>=Scope
az ad app permission admin-consent --id <OAUTH_AZURE_AD_CLIENT_ID>
```

You can validate configured permissions with the following command.

```
az ad app permission list --id <OAUTH_AZURE_AD_CLIENT_ID>
```

**Group-based trimming**

If your indexed documents include group object ids in `metadata_security_group_ids`, Azure AI Search needs group identifiers for the querying user. The most straightforward setup is to configure the App Registration to emit a `groups` claim in access tokens.

If users belong to many groups, Entra may emit a group overage indicator instead of the full group list. In that case, group membership must be resolved via Microsoft Graph. GPT-RAG tries to avoid that dependency, so keep group sets small where possible.

**Permission trimming fields in Azure AI Search**

Permission trimming works when the index is configured for it and when each document contains security metadata in fields that Azure AI Search recognizes. To enable trimming, set `permissionFilterOption` to `enabled` in the index definition.

The index must include one field for each permission filter type.

```
metadata_security_user_ids   Collection(Edm.String)   permissionFilter=userIds
metadata_security_group_ids  Collection(Edm.String)   permissionFilter=groupIds
metadata_security_rbac_scope Edm.String               permissionFilter=rbacScope
```

Azure AI Search enforces limits for permission filter fields. The `userIds` and `groupIds` fields accept up to 32 values each. The `rbacScope` field is limited to five distinct values across the entire index. The fields should also be marked as `filterable=true`.

**How GPT-RAG populates permission fields**

GPT-RAG uses the same field names across ingestion paths.

Blob ingestion reads `metadata_security_user_ids` and `metadata_security_group_ids` from blob metadata when present. If more than 32 values are supplied, ingestion removes duplicates and truncates to 32 to avoid indexing failures.

Blob ingestion also sets `metadata_security_rbac_scope` to the container resource id when it can compute it. SharePoint ingestion populates user and group fields and does not set `metadata_security_rbac_scope`.

**Blob metadata keys and accepted formats**

For Blob Storage ingestion, GPT-RAG reads two optional metadata keys from each blob. If they are missing or empty, ingestion still succeeds and documents are indexed with empty ACL arrays.

```
metadata_security_user_ids
metadata_security_group_ids
```

Values can be provided as a JSON array, a Python-style list, or a comma-separated string. JSON is recommended because it is unambiguous.

Examples for `metadata_security_user_ids`.

```
["11111111-1111-1111-1111-111111111111"]
["11111111-1111-1111-1111-111111111111","22222222-2222-2222-2222-222222222222"]
11111111-1111-1111-1111-111111111111,22222222-2222-2222-2222-222222222222
['11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222']
```

Examples for `metadata_security_group_ids`.

```
["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
```

User ids must be Entra user object ids. Group ids must be Entra group object ids.

**RBAC scope for Blob ingestion**

For Blob Storage ingestion, `metadata_security_rbac_scope` should be the Azure resource id of the container.

```
/subscriptions/<subscriptionId>/resourceGroups/<resourceGroup>/providers/Microsoft.Storage/storageAccounts/<storageAccount>/blobServices/default/containers/<container>
```

The blob indexer computes this value from configuration when possible. If you want to set it explicitly, use `DOCUMENTS_STORAGE_CONTAINER_RESOURCE_ID`. Otherwise, the indexer attempts to build it using `SUBSCRIPTION_ID` or `AZURE_SUBSCRIPTION_ID`, together with `AZURE_RESOURCE_GROUP`.

**Configuration keys used by this repo**

Required keys.

```
OAUTH_AZURE_AD_CLIENT_ID
OAUTH_AZURE_AD_TENANT_ID
OAUTH_AZURE_AD_CLIENT_SECRET
CHAINLIT_AUTH_SECRET
```

Optional keys.

```
CHAINLIT_URL
OAUTH_AZURE_AD_SCOPES
OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT
ALLOW_ANONYMOUS
```

**Scopes used by this repo**

Interactive login commonly includes `openid`, `profile`, and `offline_access`. If `OAUTH_AZURE_AD_SCOPES` is not set, the default is the orchestrator API scope plus those OpenID Connect scopes.

```
api://<CLIENT_ID>/user_impersonation,openid,profile,offline_access
```

If you add Microsoft Graph scopes such as `User.Read` to the interactive login request, Entra may issue a Microsoft Graph access token. That is not the token the orchestrator needs for the On-Behalf-Of exchange to Azure AI Search. When Graph is required, prefer backend-to-Graph calls using application permissions.

Refresh-token exchange behaves differently. MSAL rejects reserved OpenID Connect scopes during refresh. For refresh flows, GPT-RAG requests only the API scope.

**Local development**

If you have not configured OAuth, you can run in anonymous mode by setting `ALLOW_ANONYMOUS` to `true`.

If you want to load configuration locally from Azure App Configuration, set `APP_CONFIG_ENDPOINT` and authenticate using `az login`.