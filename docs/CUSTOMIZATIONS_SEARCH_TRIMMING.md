# Filter Files with AI Search Using Security Trimming

This customization allows the GPT-RAG solution to filter information during searches in AI Search based on a specific field defined in the index schema. **AI Search security trimming** ensures that only authorized users or groups can access specific search results by enforcing access control at query time. It checks the `metadata_security_id` field in the index against the user or group identifiers provided during the search.

The AI Search setup automatically creates an index with a `metadata_security_id` field. This field is mapped in the skillset for use during indexing, enabling secure and targeted searches while protecting sensitive information.

## General Instructions

In the following sections, we will provide detailed instructions on how to configure and use this functionality.

### Pre-requisites:

- **Storage Metadata**: Ensure that the files in the storage container to be indexed include a `metadata_security_id` field in their metadata. This field should contain a list of values, which may include:
  - Entra ID `object_ids` of authorized users.
  - Entra ID group names.

- **Orchestrator Payload**: The following attributes must be included in the JSON payload sent to the Orchestrator to enable the search trimming functionality:
   - `"client_principal_id"`: Unique identifier of the client.  
   - `"client_principal_name"`: Principal name of the client.  
   - `"client_group_names"`: List of group names associated with the client.

> [!NOTE]
> Orchestrator Payload: These attributes are already added by the Frontend and populated correctly if authentication is properly configured.

By default, the Security Trimming feature is activated and always returns documents where the `metadata_security_id` field is blank, ensuring broad accessibility when no specific restrictions are defined.

### Setup Steps:

1. **Deploy the Solution**:
   Deploy the GPT-RAG solution. The Function Apps for Ingestion and Orchestration will be set up to handle security trimming by default. This ensures that the AI Search index includes the `metadata_security_id` field and that the skillset is correctly mapped.

2. **Verify Metadata**:
   Ensure that all files in the storage container have the `metadata_security_id` metadata field populated with the relevant values, such as Entra ID `object_ids` and/or group names. This step is crucial for restricting document access to authorized users only.

![Storage Metadata - Search Trimming](../media/readme-search_trimming_sample.png)

3. **Check Deployment**:
   After deployment, verify that the AI Search index has been created with the `metadata_security_id` field and that the skillset mappings are functioning correctly.

> [!NOTE]
> For step 2, ensure that the `metadata_security_id` field follows this format: `['00000000-0000-0000-0000-000000000123', 'Group Name', '00000000-0000-0000-0000-000000000456']`. This field specifies who or which group can access the blob. Leave it blank if there are no access restrictions.

## References:

* [Azure AI Search - Search Trimming Documentation](https://learn.microsoft.com/en-us/azure/search/search-security-trimming-for-azure-search)
