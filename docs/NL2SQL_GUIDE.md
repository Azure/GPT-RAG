# NL2SQL and Fabric Scenario

Integrating Natural Language to SQL (NL2SQL) into GPT-RAG enhances its capabilities, enabling it to go beyond traditional RAG scenarios by allowing users to generate SQL statements from natural language queries, streamlining data interaction. For Fabric's semantic models, this functionality extends through Natural Language to DAX (NL2DAX), facilitating intuitive data analysis within these models.

## How It Works

In these scenarios, the **orchestrator** interprets the user's query, identifies the relevant **data sources** and **tables** containing the required information, formulates the necessary **queries**, executes them, and generates a response based on the retrieved results.

To implement these scenarios, the solution relies on two key components of GPT-RAG:

1. **Orchestrator** – Generates and executes queries, retrieves results, and formulates the final response for the user.
2. **Data Ingestion** – Ingests data source metadata, like data dictionaries, to enhance query generation accuracy.

Learn how the **orchestrator** works and configure it for NL2SQL and Fabric in the [Orchestrator Repository](https://github.com/Azure/gpt-rag-agentic/blob/main/docs/NL2SQL.md).

To configure the **data ingestion** process for these scenarios, refer to the [Data Ingestion Repository](https://github.com/Azure/gpt-rag-agentic/blob/main/docs/NL2SQL.md).

> [!NOTE]
> Currently, only the Agentic Orchestrator supports NL2SQL feature.

## SQL Data Sources

SQL data sources, such as SQL Databases or Fabric SQL endpoints, are essential for GPT-RAG. We currently support three types of SQL data sources, with plans to expand this list as more options become available.

### Supported SQL Data Source Types

The following **data source types** are currently supported:

1. **Semantic Model** (Fabric)  
2. **SQL Endpoint** (Fabric)  
3. **SQL Database**

> [!NOTE]  
> Although the **Semantic Model** is listed as an SQL data source, queries against this model are actually performed using **DAX**. However, for simplicity, we use the **NL2SQL** terminology for these cases as well.

## Authentication Methods

Authentication is required for connecting to SQL databases and Fabric endpoints. Different authentication methods are used depending on the type of data source:

- For **Semantic Models** and **SQL Endpoints**, the orchestrator connects using a **Service Principal/App Registration**.  
- For **SQL Database**, the connection is established using **Managed Identity**.

## Service Principal Authentication

For **datasources that require Service Principal authentication** (i.e., those that include a `client_id` in their configuration), the corresponding **client secret** must be stored in **Azure Key Vault**. The standard naming convention for storing these secrets follows this pattern:

```
{datasource_id}-secret
```

For example, the secret for the **`wwi-sales-aggregated-data`** datasource should be stored as:

```
wwi-sales-aggregated-data-secret
```

![Sample Datasource Secrets](../media/admin-guide-datasource-secrets.png)
<BR>*Sample Datasource Secrets*

For details on how to create Service Principals for these scenarios, refer to the [Orchestrator Repository](https://github.com/Azure/gpt-rag-agentic?tab=readme-ov-file#nl2sql-strategies-configuration).

## SQL Data Sources Configuration

Each data source, such as an SQL Database or a Fabric SQL endpoint, must be configured. Data source configurations are stored as JSON documents in the `datasources` container within **CosmosDB**, which is used by GPT-RAG. Each document contains key details such as the data source type and connection information.

![Sample Datasource Configuration](../media/admin-guide-datasource-configuration.png)
<BR>*Sample Datasource Configuration*

Below you can see examples of configurations for each data source type.

### **Semantic Model Datasource**
```json
{
    "id": "wwi-sales-aggregated-data",    
    "description": "This data source is a semantic model containing aggregated sales data. It is ideal for insights such as sales by employee or city.",
    "type": "semantic_model",
    "organization": "myorg",
    "dataset": "your_dataset_or_semantic_model_name",
    "tenant_id": "your_sp_tenant_id",
    "client_id": "your_sp_client_id"    
}
```

### **SQL Endpoint Datasource**
```json
{
    "id": "wwi-sales-star-schema",
    "description": "This data source is a star schema that organizes sales data. It includes a fact table for sales and dimension tables such as city, customer, and inventory items (products).",
    "type": "sql_endpoint",
    "organization": "myorg",
    "server": "your_sql_endpoint. Ex: xpto.datawarehouse.fabric.microsoft.com",
    "database": "your_lakehouse_name",
    "tenant_id": "your_sp_tenant_id",
    "client_id": "your_sp_client_id"
}
```

### **SQL Database Datasource**
```json
{
    "id": "adventureworks",
    "description": "AdventureWorksLT is a database featuring a schema with tables for customers, orders, products, and sales.",
    "type": "sql_database",
    "database": "adventureworkslt",
    "server": "sqlservername.database.windows.net"
}
```