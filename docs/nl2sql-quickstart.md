# NL2SQL Quick Start Guide

Get public access natural language querying of your Azure SQL Database working in **30 minutes** using **automated blob storage ingestion**.

This quickstart enables a public access solution which is for testing purposes only!

## Prerequisites

**You must have:**
- GPT-RAG solution deployed (`azd provision` and `azd deploy` completed)
- Azure subscription with permissions to create SQL resources
- Access to Azure Portal

## What You'll Accomplish

By the end of this guide:
- Create Azure SQL Database with AdventureWorksLT sample data
- Configure networking and firewall rules
- Store database credentials securely in Key Vault
- Register your SQL database as a datasource
- Upload table metadata and example queries to blob storage
- Enable automated ingestion with CRON scheduling
- Enable NL2SQL strategy
- Ask questions in natural language and get SQL results

---

## Step 1: Create Azure SQL Database (5-10 min)

### A. Create SQL Server

**Azure Portal → Create a resource → SQL Database**

1. **Basics tab:**
   - **Subscription:** Your subscription
   - **Resource group:** Same as your GPT-RAG deployment (or create new)
   - **Database name:** `adventureworks-demo`
   - **Server:** Click **Create new**

2. **Create SQL Database Server:**
   - **Server name:** `sql-gptrag-demo-<unique>` (must be globally unique)
   - **Location:** Same region as GPT-RAG (optional - any region works, but same region reduces latency)
   - **Authentication method:** **Use SQL authentication** (simpler for this quickstart; Entra ID authentication is also supported)
   - **Server admin login:** `sqladmin`
   - **Password:** Create a strong password (save this!)
   - Click **OK**

3. **Compute + storage:**
   - Click **Configure database**
   - Select **Basic** (cheapest for testing - $5/month)
   - Click **Apply**

4. **Backup storage redundancy:**
   - Select **Locally-redundant backup storage** (cheapest)

### B. Configure Networking

5. **Networking tab:**
   - **Connectivity method:** **Public endpoint**
   - **Firewall rules:**
     - **Allow Azure services and resources to access this server** - **YES** (CRITICAL!)
     - **Add current client IP address** - **YES** (for your testing)
   - **Connection policy:** Default
   - **Encrypted connections:** TLS 1.2 (default)

### C. Add Sample Data

6. **Additional settings tab:**
   - **Use existing data:** **Sample (AdventureWorksLT)**
   - **Collation:** Default
   - **Enable Microsoft Defender:** Not needed for demo

7. Click **Review + create** → **Create**

⏳ **Wait 3-5 minutes for deployment to complete.**

### D. Verify Firewall Configuration (Post-Deployment)

After deployment completes:

**⚠️ Important:** Go to the **SQL Server** resource (not the database):

**Azure Portal → SQL servers → `sql-gptrag-demo-<unique>` → Security → Networking**

(Note: SQL databases → adventureworks-demo - that's the wrong place!)

Verify these settings:
- **Public network access:** Selected networks
- **Exceptions:** ☑️ **Allow Azure services and resources to access this server** (checked)

The "Allow Azure services" checkbox creates a special firewall rule (`0.0.0.0 - 0.0.0.0`) that permits any Azure service in your subscription to connect.

### E. Test Connection

**Using Azure Portal Query Editor:**

1. Go to your SQL Database → **Query editor**
2. Login with **SQL authentication** (sqladmin / your password)
3. Run test query:

```sql
SELECT TOP 5 ProductID, Name, ListPrice 
FROM SalesLT.Product 
ORDER BY ListPrice DESC
```

**If you see results, your database is ready!**

### F. Gather Connection Info

Save these details (you'll need them later):

```
Server: <your-sql-server-name>.database.windows.net
Database: adventureworks-demo
Username: sqladmin
Password: <your-password>
```

---

## Step 2: Find Your GPT-RAG Resources (3 min)

Locate these in your resource group (they have your deployment suffix):

```
Key Vault: kv-<suffix>
Cosmos DB: cosmos-<suffix>
AI Search: srch-<suffix>
App Config: appcs-<suffix>
Storage Account: st<suffix> (note: no dash in storage account names)
```

**Quick way to find suffix:**
```powershell
# List resource groups
az group list --query "[?contains(name,'gpt-rag')].name" -o table

# List resources in your group
az resource list -g <your-rg> --query "[].name" -o table
```

---

## Step 3: Store Password in Key Vault (3 min)

**CRITICAL:** Secret name MUST be `{datasource-id}-secret`

```powershell
# Using the password you created in Step 1
# If your datasource id will be "adventureworks"
# Then secret name must be "adventureworks-secret"

az keyvault secret set `
  --vault-name "kv-<your-suffix>" `
  --name "adventureworks-secret" `
  --value "<your-sql-password-from-step-1>"
```

**Verify it worked:**
```powershell
az keyvault secret show `
  --vault-name "kv-<your-suffix>" `
  --name "adventureworks-secret" `
  --query "value" -o tsv
```

---

## Step 4: Grant Container App Access to Key Vault (2 min)

```powershell
# Get orchestrator's managed identity
$principalId = az containerapp show `
  --name "ca-<your-suffix>-orchestrator" `
  --resource-group <your-rg> `
  --query "identity.principalId" -o tsv

# Grant access
az role assignment create `
  --assignee $principalId `
  --role "Key Vault Secrets User" `
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/kv-<your-suffix>"
```

---

## Step 5: Register Database in Cosmos DB (3 min)

**Azure Portal → Cosmos DB → cosmos-`<suffix>` → Data Explorer → ragdata database → datasources container → New Item**

Paste this JSON, replacing `<your-sql-server-name>` with the **server name you created in Step 1** (e.g., `sql-gptrag-demo-xyz123`):

```json
{
    "id": "adventureworks",
    "type": "sql_database",
    "description": "AdventureWorksLT sample database with products and customers",
    "server": "<your-sql-server-name>.database.windows.net",
    "database": "adventureworks-demo",
    "uid": "sqladmin",
    "metadata": {
        "created_date": "2025-11-17"
    }
}
```

**💡 How to find your server name:**
- Azure Portal → SQL servers → Look for the server you just created
- Copy the name (e.g., `sql-gptrag-demo-ragpace`)
- Add `.database.windows.net` to the end

**⚠️ CRITICAL RULES:**
- Use `uid` (NOT `username`)
- DO NOT include `password` field
- DO NOT include `connection_info` field
- The `id` must match Key Vault secret prefix (`adventureworks` → `adventureworks-secret`)

Click **Save**.

---

## Step 6: Create Metadata JSON Files (5 min)

**What you'll do in this step:**
- Create JSON files on your **local machine** (in your working directory)
- These files describe your database tables and example queries
- In **Step 7**, you'll upload these files to Azure Blob Storage
- The automated ingestion system will then index them into AI Search

### A. Create Local Folder Structure

On your local machine, create folders to organize the metadata files:

```powershell
mkdir blob-upload
mkdir blob-upload\queries
mkdir blob-upload\tables
```

### B. Create Example Query Files

**Why example queries?** They help the AI understand your database patterns and generate better SQL. The system uses these as few-shot examples when translating natural language to SQL.

> 📝 **Note:** We're only adding 3 queries here for quick setup. **Ideally, add 10-20 diverse examples** covering:
> - Simple queries (counts, filters)
> - Complex joins across multiple tables
> - Aggregations (SUM, AVG, GROUP BY)
> - Date/time filtering
> - Common business questions your users ask
> 
> More examples = better SQL generation accuracy!

**Create these files on your local machine:**

Create `blob-upload\queries\how_many_products.json`:
```json
{
    "question": "How many products are in the database?",
    "query": "SELECT COUNT(*) as product_count FROM SalesLT.Product",
    "reasoning": "Simple count of all products",
    "datasource": "adventureworks"
}
```

Create `blob-upload\queries\top_expensive_products.json`:
```json
{
    "question": "Show me the top 5 most expensive products",
    "query": "SELECT TOP 5 ProductID, Name, ListPrice FROM SalesLT.Product ORDER BY ListPrice DESC",
    "reasoning": "Get highest priced products",
    "datasource": "adventureworks"
}
```

Create `blob-upload\queries\product_categories.json`:
```json
{
    "question": "What product categories exist?",
    "query": "SELECT DISTINCT Name FROM SalesLT.ProductCategory ORDER BY Name",
    "reasoning": "List all unique categories",
    "datasource": "adventureworks"
}
```

### C. Create Table Metadata Files

**Why table metadata?** 

The system uses **AI Search for semantic table discovery** instead of live database introspection. When users ask questions, the system:
1. Searches your table metadata using embeddings (vector search)
2. Finds the most relevant tables based on descriptions
3. Then calls `GetSchemaInfo` to retrieve detailed column information

**Benefits of this approach:**
- **Fast semantic search** - Find relevant tables using natural language ("revenue data" matches "SalesOrderHeader")
- **Control what's exposed** - Only include tables relevant to end users (exclude admin/audit tables)
- **Add business context** - Descriptions help the AI understand table purpose beyond raw schema
- **Avoid token limits** - Don't send 500 table schemas to GPT-4 every query

**⚠️ Schema updates:**
- If you add/drop columns or tables later, create new JSON files and upload them
- The automated ingestion will detect changes and re-index automatically

!!! note
    Column descriptions are not specified here because the column names are sufficiently descriptive for the LLM

**Create these files on your local machine:**

Create `blob-upload\tables\saleslt_product.json`:
```json
{
    "table": "SalesLT.Product",
    "description": "Product catalog with names, prices, and descriptions",
    "datasource": "adventureworks"
}
```

Create `blob-upload\tables\saleslt_productcategory.json`:
```json
{
    "table": "SalesLT.ProductCategory",
    "description": "Product categories for organizing products",
    "datasource": "adventureworks"
}
```

Create `blob-upload\tables\saleslt_customer.json`:
```json
{
    "table": "SalesLT.Customer",
    "description": "Customer information including names and contact details",
    "datasource": "adventureworks"
}
```

---

## Step 7: Upload Files to Blob Storage (3 min)

**What this step does:**
- Uploads the local JSON files you created in Step 6 to Azure Blob Storage
- Files go into the `nl2sql` container (this container already exists from your deployment)
- The folder structure (`queries/` and `tables/`) will be created automatically during upload

**Upload command:**

```powershell
# Upload all files (queries and tables)
az storage blob upload-batch `
  --account-name "st<your-suffix>" `
  --destination nl2sql `
  --source blob-upload `
  --auth-mode login
```

**Verify uploads:**
```powershell
# List all blobs in nl2sql container
az storage blob list `
  --account-name "st<your-suffix>" `
  --container-name nl2sql `
  --auth-mode login `
  --query "[].name" -o table
```

You should see:
```
queries/how_many_products.json
queries/top_expensive_products.json
queries/product_categories.json
tables/saleslt_product.json
tables/saleslt_productcategory.json
tables/saleslt_customer.json
```

---

## Step 8: Enable Automated Ingestion (3 min)

**Azure Portal → App Configuration → appcs-`<suffix>` → Configuration explorer**

Click **+ Create** to add a new key-value:

**Key:** `CRON_RUN_NL2SQL_INDEX`  
**Value:** `*/15 * * * *`  
**Label:** `gpt-rag-ingestion`  
**Content type:** `text/plain`

Click **Apply**.

**What this does:**
- Runs the NL2SQL indexer job every 15 minutes
- Scans the `nl2sql` container for new/changed files
- Automatically indexes them into AI Search
- Generates embeddings for semantic search
- Skips unchanged files (smart change detection)

**Alternative schedules:**
- `*/5 * * * *` - Every 5 minutes (faster updates)
- `*/2 * * * *` - Every 2 minutes (testing/development only)
- `0 * * * *` - Every hour on the hour
- `0 0 * * *` - Once daily at midnight

**Cost considerations:**
- CRON schedules are free - they're just timers, not separate compute
- The Container App runs 24/7 regardless of schedule (~$30-50/month)
- Each run generates embeddings via Azure OpenAI (~$0.001 per run)
- Smart change detection skips unchanged files (saves costs)
- **Recommended for production:** `*/15 * * * *` balances responsiveness with costs (~$3-5/month in embeddings)
- **For testing:** Use `*/2 * * * *` to see results faster, then change to `*/15 * * * *`

---

## Step 9: Enable NL2SQL Strategy (2 min)

**Azure Portal → App Configuration → appcs-`<suffix>` → Configuration explorer**

1. Search for key: `AGENT_STRATEGY`
2. Click the key → Click **Edit**
3. Change value to: `nl2sql`
4. Click **Apply**

---

## Step 10: Wait for Initial Ingestion (2-3 min)

The data ingestion Container App runs the indexer job:
- **On startup** (happens once when container starts)
- **Every 15 minutes** (based on CRON schedule)

**Option 1: Wait for next CRON run** (up to 15 minutes, or 2 minutes if you used `*/2 * * * *` for testing)

**How it works:**
- The Container App runs the indexer on startup (immediate first run)
- Then runs on the CRON schedule you configured
- CRON runs at the next matching time (e.g., if schedule is `*/15 * * * *`, next run is at :00, :15, :30, or :45)

**Option 2: Force immediate ingestion by restarting the container:**

```powershell
az containerapp revision restart `
  --name "ca-<your-suffix>-dataingest" `
  --resource-group <your-rg> `
  --revision $(az containerapp revision list --name "ca-<your-suffix>-dataingest" --resource-group <your-rg> --query "[0].name" -o tsv)
```

**Verify indexing completed:**

Check the logs in blob storage:
```powershell
# List ingestion run logs
az storage blob list `
  --account-name "st<your-suffix>" `
  --container-name jobs `
  --prefix "nl2sql-indexer/runs/" `
  --auth-mode login `
  --query "[].{name:name, modified:properties.lastModified}" -o table
```

Download the most recent log:
```powershell
# Get the latest run log
$latestLog = az storage blob list `
  --account-name "st<your-suffix>" `
  --container-name jobs `
  --prefix "nl2sql-indexer/runs/" `
  --auth-mode login `
  --query "[-1].name" -o tsv

# Download and view it
az storage blob download `
  --account-name "st<your-suffix>" `
  --container-name jobs `
  --name $latestLog `
  --file run-log.json `
  --auth-mode login

Get-Content run-log.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Look for:**
- `"success": 3` (for queries)
- `"success": 3` (for tables)
- `"failed": 0`
- `"skipped": 0` (first run - nothing skipped yet)
- `"vectorsGenerated": 6` (embeddings created)

**On subsequent runs:**
- Files with no changes will show `"skipped": 6` and `"candidates": 0`
- Only new or modified files will be re-indexed
- This smart change detection saves costs and time

---

## Step 11: Test It! (2 min)

**Navigate to your UI:** `https://ca-<suffix>-frontend.livelyglacier-<random>.eastus2.azurecontainerapps.io`

**Try these questions:**
1. "How many products are in the database?"
2. "Show me the top 5 most expensive products"
3. "What product categories exist?"

**Expected response:**
- Natural language answer with data
- Shows SQL query that was executed
- Cites the datasource

---


## What You Just Enabled 🪄

**Congratulations!** You've set up an automated NL2SQL ingestion pipeline. Your system now:

### 🧠 Automated Metadata Management

**`Change detection`** - Only re-indexes modified files (checks ETag and lastModified)
**`Smart scheduling`** - Runs every 15 minutes, can be adjusted
**`Startup sync`** - Runs once on container startup for immediate availability
**`Detailed logging`** - Per-file and per-run logs in blob storage
**`Scalable`** - Handles hundreds of tables and queries efficiently

### 🧩 Advanced Query Capabilities (Already working!)

**`Complex JOINs`** - "Show me orders with customer names and product details" automatically generates multi-table joins
**`Aggregations`** - "What's the average order value by product category?" generates GROUP BY with AVG/SUM/COUNT
**`Date filtering`** - "Show orders from last 30 days" uses DATEADD and date functions
**`Subqueries`** - Handles nested queries when needed for complex business logic
**`Pattern matching`** - "Find customers whose email contains 'adventure'" uses LIKE operators

### 🔐 Enabling Zero Trust Architecture

The guide used **SQL authentication** for simplicity, but production deployments support:

**`Azure AD authentication`** - No passwords, just managed identities
**`Private Endpoints`** - Database never exposed to internet
**`VNet integration`** - Container Apps and SQL in same private network
**`Conditional Access`** - MFA and device compliance requirements


---

