# Authentication and Document-Level Security

This page explains how authentication works in GPT-RAG, from the GPT-RAG UI sign-in to querying Azure AI Search with document-level access control enabled (POSIX-like ACL / RBAC scopes). The key idea is intentionally simple: when authentication is configured, the UI forwards a single user token to the orchestrator, and the orchestrator takes responsibility for producing the correct “user context” token required by Azure AI Search.

> In OAuth mode, the orchestrator receives a user access token (for the orchestrator API) and then performs an On-Behalf-Of (OBO) exchange to obtain a separate token for Azure AI Search. The two tokens have different audiences and are not interchangeable.

## Concepts

GPT-RAG uses Microsoft Entra ID authentication end-to-end, and Azure [AI Search document-level access control (POSIX-like ACL / RBAC scopes)](https://learn.microsoft.com/en-us/azure/search/search-document-level-access-overview) relies on three related steps:

1) The UI signs the user in and sends an access token to the orchestrator. This token is meant for the orchestrator API.

2) The orchestrator validates the incoming token (signature, issuer, and audience) and extracts the user identity (for example, user object ID). This is how the orchestrator knows which user is calling.

3) When the orchestrator queries Azure AI Search with document-level security enabled, it must send a different delegated token whose audience is Azure AI Search. The orchestrator obtains that token by performing an On-Behalf-Of exchange with Entra ID.

The diagram below shows where each token is used. Azure AI Search receives the orchestrator credential (to authorize the call) and a separate “query source authorization” token (to enforce document-level access control).

<div class="no-wrap">
```
	+---------------------------+                 +----------------------------------+
	|  Microsoft Entra ID       |                 |  Azure AI Search                 |
	|  Tenant                   |                 |  Index with ACL/RBAC enforcement |
	|                           |                 |  permissionFilterOption=enabled  |
	+---------------------------+                 +----------------------------------+
			^													   ^
			|													   |
			| (4) user access                                      | (6) Search query
			|  aud: https://search.azure.com                       |   Authorization: (orchestrator identity)
			|  scope: https://search.azure.com/user_impersonation  |   x-ms-query-source-authorization: (user access token)
			|													   |
			|													   |
			|													   |
	+---------------------------+         (3) OBO exchange         |
	|  Orchestrator             |----------------------------------+
	|  Container App            |   to Entra ID token endpoint
	|                           |
	|  Validates API token      |   Inputs
	|  Uses client secret       |   - incoming user access token
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

When authentication is configured (OAuth enabled), the UI includes the user access token for the orchestrator API on calls to the orchestrator. This is the token shown as (2) in the diagram. If OAuth is not configured and the UI is running in anonymous mode, the UI calls the orchestrator without an `Authorization` header. In OAuth mode, the UI sends the token like this:

```
Authorization: Bearer <orchestrator_api_user_access_token>
```

On the orchestrator side, this user access token is validated before any downstream call is made. The orchestrator verifies the token signature and issuer using the tenant signing keys (JWKS), checks the expected audience for the orchestrator API, and extracts the user identity (for example, user object ID). That identity can be used to enforce access to the orchestrator itself.

To query Azure AI Search with document-level access control enabled, the orchestrator performs an On-Behalf-Of (OBO) exchange using the incoming user access token as the user assertion. This returns a delegated user token whose audience is Azure AI Search. The orchestrator includes that token in the header below when running queries.

```
x-ms-query-source-authorization: Bearer <search_user_access_token>
```

Document-level access control is enforced by Azure AI Search when the index is configured for document permissions (see `permissionFilterOption` in the index definition) and documents include permission metadata. 

GPT-RAG uses these field names consistently across ingestion paths:

```
metadata_security_user_ids
metadata_security_group_ids
metadata_security_rbac_scope
```

For GPT-RAG, the document-level access control model is POSIX-style ACL plus RBAC scopes. Each document can carry ACL metadata such as user and group object IDs. When applicable, a document can also carry an RBAC scope such as a storage container resource ID.

GPT-RAG ingestion is responsible for collecting and attaching the permission metadata for each document automatically. This repo does not rely on the built-in Azure AI Search indexers for permission extraction. Permissions are handled by the pipeline implemented in `gpt-rag-ingestion`.

When ACL and RBAC scope metadata are present, Azure AI Search evaluates them as alternatives. Access is granted when any one permission type matches: userIds, groupIds, or rbacScope.

In normal usage, userIds and groupIds contain Microsoft Entra ID object IDs as strings. They also support special values.

    - `["all"]` makes every caller match this ACL type.

    - `["none"]` and `[]` mean no caller matches this ACL type.

These values only apply to that ACL type. For example, userIds set to `["none"]` does not block access through groupIds or RBAC scope.

RBAC scopes are applied at the storage container level. When RBAC is used for a document, users must have the appropriate Azure role assignment on the container scope, typically Storage Blob Data Reader.

In test environments, if you do not want Azure AI Search to enforce document permissions, set `permissionFilterOption` to `disabled` in the index definition. This is the default.

Azure AI Search enforces limits for document permission fields. The `userIds` and `groupIds` fields accept up to 32 values each. The `rbacScope` field is limited to five distinct values across the entire index.

## Prerequisites

**For user authentication**
- A Microsoft Entra ID App Registration used by both the UI and the orchestrator. The UI uses it to sign users in and request an access token for the orchestrator API. The orchestrator then validates that token and uses the app's client secret to perform the On-Behalf-Of (OBO) token exchange when the Azure AI Search index is configured for document-level access control.
- You have permissions in the tenant to create or update the App Registration, add API permissions.

**For document-level security**
- User authentication is configured.
- Your Azure AI Search index is configured for document-level access control and includes the required document permission fields. *
- Your documents are indexed with the correct security metadata for each document (user object IDs, group object IDs, and RBAC scope). **
- Tenant admin consent is granted for the Azure AI Search delegated permission `user_impersonation` in the App Registration.

\* If you use the GPT-RAG provisioning workflow, it already creates the index with this configuration.

\** If you use gpt-rag data ingetion pipeline documents are automatically indexed with ACL when they're set in the blobs metadata fields

## Setup

**1) Create one App Registration in Microsoft Entra ID.**

After creating it, go to the **App Registration Overview** page and copy the Application (client) ID and the Directory (tenant) ID. You will use them later as `OAUTH_AZURE_AD_CLIENT_ID` and `OAUTH_AZURE_AD_TENANT_ID`.

If you plan to use group-based access control, in the **App Registration** go to **Manage > Token configuration** and add a `groups` claim. 

If users belong to many groups, Entra may emit an overage indicator instead of the full group list, which typically requires resolving membership via Microsoft Graph.

**2) In the App Registration, go to Manage > Authentication.**

**Under Platform configurations > Web, add the frontend redirect URI.**

```
https://<YOUR-APP-URL>/auth/oauth/azure-ad/callback
```

**3) In the App Registration, go to Manage > Expose an API.** 

Set the Application ID URI to `api://<OAUTH_AZURE_AD_CLIENT_ID>`.


Then create a delegated scope named `user_impersonation` and add this scope to the app.

```
api://<OAUTH_AZURE_AD_CLIENT_ID>/user_impersonation
```

**4) In the App Registration, go to Manage > Certificates & secrets.**

**Create a new client secret and copy the secret value.**

You can only copy the secret value once. Store it securely (for example, in Key Vault) and use it later for the orchestrator configuration.

**5) Add the Azure AI Search delegated permission `user_impersonation` and grant tenant consent.**

In the App Registration, go to **Manage > API permissions**.

```
Add a permission
	APIs my organization uses
		Azure Cognitive Search
			Delegated permissions
				user_impersonation

Grant admin consent
```

CLI alternative if Azure Cognitive Search does not appear in the picker. First, discover the Azure AI Search resource application ID and the scope ID.

```
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals?$filter=servicePrincipalNames/any(s:s eq 'https://search.azure.com')&$select=appId,displayName,oauth2PermissionScopes" --query "value[0].{resourceAppId:appId,scopeId:oauth2PermissionScopes[?value=='user_impersonation'].id | [0],name:displayName}"
```

Then add the permission and grant consent.

```
az ad app permission add --id <replace-by-app-client-id> --api <SEARCH_RESOURCE_APP_ID> --api-permissions <SCOPE_ID>=Scope
az ad app permission admin-consent --id <replace-by-app-client-id>
```

Validate the configured permissions.

```
az ad app permission list --id <replace-by-app-client-id>
```

**6) Configure the following app configuration settings used by the authentication flow.**

GPT-RAG authentication settings are configured in **Azure App Configuration**. Create the keys below in App Configuration and apply the **gpt-rag** label. For non-secret settings, store the value as plain text. For secret settings, store the value in **Key Vault** and add the key in App Configuration as a **Key Vault reference** (also under the **gpt-rag** label).

At a minimum, you only need to set the settings marked as **Required** in the table below. The remaining settings are optional and only needed if you want to customize behavior.

| Setting | Required | Secret? | What it controls |
| --- | --- | --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID` | Yes (for OAuth) | No | Entra App Registration application (client) ID used by the UI OAuth provider to request tokens for the orchestrator API. |
| `OAUTH_AZURE_AD_TENANT_ID` | Yes (for OAuth) | No | Entra tenant ID used to validate/target the tenant for the OAuth flow (single-tenant by default). |
| `OAUTH_AZURE_AD_CLIENT_SECRET` | Yes (for OAuth) | Yes | Client secret used by the app for confidential-client flows (for example, completing the OAuth code flow and performing the OBO exchange). Store as a Key Vault secret and reference it from App Configuration (or from App Settings if you bypass App Configuration). |
| `CHAINLIT_AUTH_SECRET` | Yes | Yes | Secret used by Chainlit to sign its session JWT. If missing, the UI generates a temporary value (sessions reset on restart). Store as a Key Vault secret and reference it from App Configuration (or from App Settings if you bypass App Configuration). |
| `CHAINLIT_URL` | No | No | Public base URL of the UI. Used to build the OAuth redirect/callback URL (and normalized without a trailing slash). |
| `OAUTH_AZURE_AD_SCOPES` | No | No | Scopes requested during interactive login. If omitted, the UI defaults to the orchestrator API scope plus OpenID Connect scopes. Setting this explicitly helps avoid accidentally getting Microsoft Graph tokens. |
| `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | No | No | Defaults to `true`. When `true`, the UI enforces single-tenant behavior for the OAuth flow. Set to `false` only for multi-tenant scenarios. |
| `ALLOW_ANONYMOUS` | No | No | When `true`, the UI runs without OAuth (anonymous mode). Defaults to `true` locally when OAuth is not configured. |


**7) Configure the Azure AI Search index for document-level access control and ensure your documents include permission metadata.**

In the index definition, set `permissionFilterOption` to `enabled`.

These are the Azure AI Search index fields used for document-level access control:

```
metadata_security_user_ids   Collection(Edm.String)   permissionFilter=userIds
metadata_security_group_ids  Collection(Edm.String)   permissionFilter=groupIds
metadata_security_rbac_scope Edm.String               permissionFilter=rbacScope
```

During Blob Storage ingestion, the GPT-RAG ingestion pipeline reads the following blob metadata keys and adds them to the corresponding documents in the index. If you want to specify which users or groups can access a document, set these metadata fields on each blob.

```
metadata_security_user_ids
metadata_security_group_ids
```

> Note: For SharePoint ingestion, you don't need any additional steps. The GPT-RAG ingestion pipeline typically derives the user and group ACLs from the source SharePoint document or list item permissions and populates the same fields automatically.

Examples of how to populate `metadata_security_user_ids` and `metadata_security_group_ids`.


```
["11111111-1111-1111-1111-111111111111"]
["11111111-1111-1111-1111-111111111111","22222222-2222-2222-2222-222222222222"]
11111111-1111-1111-1111-111111111111,22222222-2222-2222-2222-222222222222
['11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222']
```

> Note: For Blob Storage ingestion, the GPT-RAG ingestion pipeline will populate `metadata_security_rbac_scope` automatically. The value is the Azure resource ID of the container, for example:
*/subscriptions/<subscriptionId\>/resourceGroups/<resourceGroup\>/providers/Microsoft.Storage/storageAccounts/<storageAccount\>/blobServices/default/containers/<container\>*
