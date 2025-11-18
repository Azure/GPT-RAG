# Simple RAG Quick Start Guide

Get document-based AI question answering working in **60 minutes** using **GPT-RAG's automated deployment**.

This quickstart enables a public access solution which is for testing purposes only!

## Prerequisites

✅ **You must have:**
- Azure subscription with permissions to create resources
- Azure Developer CLI (azd): 1.21.1+
- Azure CLI (az): 2.79.0+
- PowerShell 7.5+
- Docker Desktop installed and running
- Git & Python 3.11+

## What You'll Accomplish

By the end of this guide:
- ✅ Deploy complete GPT-RAG infrastructure (~20 Azure resources)
- ✅ Upload documents to Azure Blob Storage
- ✅ Enable automated document ingestion and indexing
- ✅ Configure AI Foundry search connection
- ✅ Generate embeddings with text-embedding-3-large
- ✅ Ask questions about your documents using GPT-4o
- ✅ Get answers grounded in your data with citations

---

## Step 1: Initialize GPT-RAG Project (5 min)

```powershell
# Create fresh directory
mkdir C:\MyCode\my-gpt-rag
cd C:\MyCode\my-gpt-rag

# Initialize from template
azd init -t azure/gpt-rag
```

**You'll be prompted for:**
1. **Environment name** - Choose a short name (e.g., `myrag`, `demorag`)
2. **Azure subscription** - Select from list
3. **Azure region** - Choose wisely:
   - ✅ **East US 2** - Best OpenAI quota availability
   - ✅ **West US** - Good quota, lower latency for West Coast
   - ✅ **East US** - Backup option if East US 2 full
   - ⚠️ **North Europe, West Europe** - Often quota-constrained

**💡 Note:** If you have quota limitations, see the Troubleshooting section at the end for how to adjust model capacity.

---

## Step 2: Authenticate Azure CLIs (2 min)

```powershell
# Login to Azure CLI (yes, both required)
az login
azd auth login
```

---

## Step 3: Provision Infrastructure (30 min)

```powershell
azd provision
```

**What this creates (~20 Azure resources):**
- ✅ **Resource Group** - Container for all resources
- ✅ **Storage Accounts** - For documents and job logs
- ✅ **AI Search Services (2)** - Main index (srch-*) and AI Foundry index (srch-aif-*)
- ✅ **AI Foundry** - Hub and project for agent orchestration
- ✅ **OpenAI Models** - GPT-4o and text-embedding-3-large deployments
- ✅ **Container Registry** - Stores Docker images
- ✅ **Container Apps (4)** - Frontend, orchestrator, ingestion, MCP
- ✅ **App Configuration** - Centralized configuration store
- ✅ **Key Vault** - Secrets management
- ✅ **Cosmos DB** - Agent state and metadata
- ✅ **Log Analytics** - Monitoring and diagnostics
- ✅ **Managed Identities** - Secure service-to-service auth

⏳ **Wait ~27 minutes for provisioning to complete.**

**Save your resource prefix:**

After provisioning completes, you'll see output like:
```
Resource prefix: y5sbzlaazfxok
```

**Keep this prefix handy** - you'll use it to identify your resources in Azure Portal.

---

## Step 4: Start Docker and Deploy Services (35 min)

**⚠️ CRITICAL:** Docker must be running before `azd deploy`!

### A. Start Docker Desktop


### B. Deploy Services

```powershell
azd deploy
```

**What this does:**
1. **Clones 4 service repositories** from GitHub:
   - `gpt-rag-frontend` - React web interface
   - `gpt-rag-orchestrator` - Agent orchestration and RAG logic
   - `gpt-rag-ingestion` - Document processing and indexing
   - `gpt-rag-mcp` - Model Context Protocol integration

2. **Builds Docker images locally**:
   - Creates containers for each service
   - Tags them with version info
   - Requires ~5-10 GB disk space

3. **Pushes images to Azure Container Registry**:
   - Uploads to `cr{prefix}.azurecr.io`
   - Typically 1-2 GB total

4. **Deploys to Container Apps**:
   - Creates 4 container apps
   - Configures networking, secrets, environment variables
   - Sets up auto-scaling rules

⏳ **Wait ~30 minutes for deployment to complete.**


---

## Step 5: Upload Documents and Verify Indexing (10 min)

### A. Upload Your Documents

**Azure Portal → Storage accounts → st`<prefix>` → Containers → documents → Upload**

**Supported formats:**
- ✅ **PDF** - Most common (OCR with Document Intelligence)
- ✅ **Word** (.docx) - Extracts text and tables
- ✅ **PowerPoint** (.pptx) - Extracts slides and speaker notes
- ✅ **Excel** (.xlsx) - Extracts sheets and data (v4.0+)
- ✅ **Text** (.txt, .md) - Direct text ingestion
- ✅ **Images** (.jpg, .png, .bmp, .tiff) - OCR extraction
- ✅ **HTML** - Web page content extraction

**What happens after upload:**
1. File stored in `documents` container
2. Ingestion service monitors for new files
3. On next CRON run or restart, files are processed
4. Azure Document Intelligence extracts text (OCR for images/PDFs)
5. Text chunked into semantic segments
6. Embeddings generated with text-embedding-3-large
7. Chunks uploaded to AI Search index `ragindex-{prefix}`

### B. Trigger Document Indexing

The indexing service runs automatically:
- ✅ **On container startup** (immediate first run)
- ✅ **Hourly on CRON** (at :10 minutes past the hour)

**Option 1: Wait for next CRON run** (up to 60 minutes)

**Option 2: Force immediate indexing by restarting:**

**Azure Portal → Container Apps → ca-`<prefix>`-dataingest

1. Click **Stop**
2. Wait 10 seconds
3. Click **Start**

**Why restart?** The indexer runs on CRON schedule (hourly at :10 past). Restarting triggers it to run immediately instead of waiting up to an hour.

### C. Verify Indexing Completed


**Azure Portal → AI Search → srch-`<prefix>` → Indexes → ragindex-`<prefix>`**

- ✅ **Document count > 0** (indicates chunks were indexed)

---

## Step 6: Configure AI Foundry Search Connection for Public Access RAG (5 min)

**⚠️ CRITICAL STEP:** The deployment creates two AI Search services. You must configure AI Foundry to use the correct one for public access!

### A. Why Two Search Services?

- **srch-`<prefix>`** - Main search service with your indexed documents (use this one!)
- **srch-aif-`<prefix>`** - AI Foundry's empty search service (created by default, ignore)

The orchestrator needs the connection ID for the main search service.

### B. Add Search Connection in AI Foundry

1. **Azure Portal → AI services → aif-`<prefix>` → Overview**
2. Click the **"View in Azure AI Foundry"** link (opens ai.azure.com)
3. Should land in your project (likely named **aifoundry-default-project**)
4. Left menu → **Connected resources** or **Connections**
5. Click **+ New connection**
6. Select **Azure AI Search**
7. Select **srch-`<prefix>`** (NOT srch-aif-*)
8. **Authentication:** ✅ **Microsoft Entra ID** (NOT API Key)
9. **Connection name:** Use the resource name (e.g., `srchqitxxnnt4igs6`)
10. Click **Save**

### C. Copy Connection ID

After saving, the connection details page shows the connection ID.

**Example:**
```
/subscriptions/f94c002c-2212-4bfb-b7a4-f8898b7ea4e5/resourceGroups/rg-demorag/providers/Microsoft.CognitiveServices/accounts/aif-qitxxnnt4igs6/projects/aifoundry-default-project/connections/srchqitxxnnt4igs6
```

**Copy this entire connection ID** - you'll paste it in the next step.

---

## Step 7: Update App Configuration and Restart Orchestrator (5 min)

### A. Update App Configuration

**Azure Portal → App Configuration → appcs-`<prefix>` → Configuration explorer**

1. Find key: **SEARCH_CONNECTION_ID**
2. Filter by label: **gpt-rag**
3. Click the key → Click **Edit**
4. **Value field:** Paste the connection ID you copied from AI Foundry
5. Verify:
   - ✅ **Content type:** `text/plain`
   - ✅ **Label:** `gpt-rag`
6. Click **Apply** → Click **Save**

### B. Restart Orchestrator

**Azure Portal → Container Apps → ca-`<prefix>`-orchestrator

1. Click **Deactivate**
2. Wait 10 seconds
3. Click **Activate**

**Why restart?** Container apps read configuration from App Configuration at startup. Restarting loads the new SEARCH_CONNECTION_ID value you just updated.

---

## Step 8: Access Frontend and Test! (3 min)

**Azure Portal → Container Apps → ca-`<prefix>`-frontend → Overview**

Copy the **Application URL** and open it in your browser. You should see the GPT-RAG chat interface.

**Try these test questions:**
1. "What is this document about?"
2. "Summarize the key points from my document"
3. "What does the document say about [specific topic]?"

**Expected response:**
- ✅ Natural language answer based on your document
- ✅ **Citations** showing which chunks were used
- ✅ **Source references** with page numbers (if PDF)
- ✅ Response generated by GPT-4o using retrieved context

---

## Troubleshooting Common Issues

### Issue 1: Quota Exceeded Errors

**Error during provision:**
```
Deployment failed: Quota exceeded for model gpt-4o
```

**Background:** The default deployment requires 80 TPM total (40 for GPT-4o + 40 for text-embedding-3-large). Many subscriptions don't have this quota available.

**Solution A: Reduce Model Capacity**

Edit `infra/main.parameters.json` BEFORE running `azd provision`:

```json
"modelDeploymentList": {
  "value": [
    {
      "name": "chat",
      "model": {
        "format": "OpenAI",
        "name": "gpt-4o",
        "version": "2024-11-20"
      },
      "sku": {
        "name": "GlobalStandard",
        "capacity": 8
      }
    },
    {
      "name": "text-embedding",
      "model": {
        "format": "OpenAI",
        "name": "text-embedding-3-large",
        "version": "1"
      },
      "sku": {
        "name": "Standard",
        "capacity": 8
      }
    }
  ]
}
```

**Capacity guidelines:**
- **8 TPM** - Good for testing/demos (supports ~5-10 users)
- **16 TPM** - Better for development (supports ~15-20 users)
- **40 TPM** - Production (default, supports ~50+ users)
- **Minimum: 4 TPM** - Will work but responses may be slower

**Solution B: Check Available Quota**

```powershell
# List your OpenAI resources and regions
az cognitiveservices account list `
  --subscription "<your-subscription-id>" `
  --query "[?kind=='OpenAI'].{Name:name, ResourceGroup:resourceGroup, Location:location}" `
  -o table
```

**Check quota in Azure Portal:**
- Go to any OpenAI resource → Quotas
- Look at TPM (Tokens Per Minute) for gpt-4o and text-embedding-3-large
- Note which regions have available quota

**Solution C: Try Different Region**

If you've already started provisioning, delete the failed resource group and try a different region:

```powershell
az group delete --name <your-rg> --yes
azd env set AZURE_LOCATION eastus
azd provision
```

### Issue 2: "ServiceInvocationException" Error

**Error message:**
```
ServiceInvocationException: Error at: project_client.agents.threads.create()
```

**Root cause:** AI Foundry capability host lacks vector store connections (immutable configuration).

**Workaround:**
1. Check orchestrator logs: `ca-<prefix>-orchestrator` → Logs → Console logs
2. Verify SEARCH_CONNECTION_ID is correctly set in App Configuration
3. Try restarting orchestrator again
4. If persists, check AI Foundry Connections page for connection status

**Note:** This is a known issue with the current GPT-RAG template. The AI Foundry agent infrastructure may need manual configuration.

### Issue 3: No Documents Indexed

**Symptoms:**
- AI Search index shows 0 documents
- Answers are generic, not grounded in your data

**Checks:**
1. **Verify upload:** Storage account → `documents` container → your file should be there
2. **Check indexer logs:** `ca-<prefix>-dataingest` → Logs → Look for errors
3. **Verify format:** Ensure file is supported (PDF, DOCX, TXT, etc.)
4. **Restart indexer:** Deactivate/Activate `ca-<prefix>-dataingest`



---

## What You Just Enabled 🪄

**Congratulations!** You've deployed a production-ready RAG system. Your solution now provides:

### 🧠 Intelligent Document Understanding

**`Semantic chunking`** - Documents split into meaningful segments (not arbitrary 512-char blocks)
**`Vector embeddings`** - text-embedding-3-large generates 3072-dimensional embeddings
**`Hybrid search`** - Combines keyword (BM25) and semantic (vector) search for best results
**`OCR extraction`** - Azure Document Intelligence handles PDFs, images, scanned documents
**`Multi-format support`** - PDF, Word, PowerPoint, Excel, text, images, HTML

### 🎯 Grounded Response Generation

**`Retrieval-Augmented Generation (RAG)`** - GPT-4o generates answers using retrieved document chunks
**`Citation tracking`** - Every answer links back to source documents and specific passages
**`Relevance filtering`** - Only high-confidence matches are sent to GPT-4o (reduces hallucination)
**`Context windowing`** - Smart selection of most relevant chunks (handles long documents)

### 🔄 Automated Ingestion Pipeline

**`Change detection`** - Only re-indexes modified files (checks ETag and lastModified)
**`CRON scheduling`** - Runs hourly at :10 past (configurable)
**`Startup sync`** - Indexes on container start for immediate availability
**`Detailed logging`** - Per-file and per-run logs in blob storage
**`Error handling`** - Failed files logged without blocking successful files

### 🔐 Enterprise-Ready Architecture

**`Managed identities`** - No passwords stored, secure service-to-service auth
**`Role-based access`** - Uses Azure RBAC for all resources
**`Centralized config`** - App Configuration for runtime settings (no redeployment needed)
**`Secrets management`** - Key Vault for sensitive data
**`Monitoring`** - Log Analytics and Application Insights built-in
**`Scalability`** - Container Apps auto-scale based on load

### 🎨 User-Friendly Interface

**`React frontend`** - Modern, responsive chat interface
**`Real-time responses`** - Streaming GPT-4o responses (see text appear live)
**`Citation preview`** - Click citations to see source context
**`Multi-turn conversations`** - Maintains context across questions
**`Feedback loop`** - Users can rate answers for quality tracking

---

