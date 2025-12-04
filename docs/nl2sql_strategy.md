# NL2SQL and NL2DAX (Fabric) Strategy

This page provides an overview of how the NL2SQL scenario works within the GPT-RAG Agentic Orchestrator. It explores the key components, including architecture, agent orchestration, authentication methods, and the configuration of data sources and NL2SQL metadata.

## Table of Contents

1. [**Architecture Overview**](#architecture-overview)
2. [**Agent Orchestration**](#agent-orchestration)
   - [2.1 Key Agents and Their Roles](#key-agents-and-their-roles)
3. **Prerequisites (by data source type)**
   - [3.1 Azure SQL Databases](#azure-sql-databases)
   - [3.2 Microsoft Fabric](#microsoft-fabric)
4. [**Data Sources Configuration**](#data-sources-configuration)
5. [**NL2SQL metadata**](#nl2sql-metadata)

---

## Architecture Overview

These scenarios extend the GPT-RAG Agentic Orchestrator's ability to convert user requests into SQL or DAX queries, supporting **Azure SQL Database** and **Microsoft Fabric** as data sources.

- In **NL2SQL** strategies, the orchestrator uses ODBC drivers to connect to Azure SQL databases. It can authenticate using either **Managed Identity** or **SQL Database authentication** with database credentials stored in **Azure Key Vault**.

- In **Chat with Fabric**, SQL endpoints are accessed using a **App Registration** (Service Principal) via ODBC. For semantic models like **Power BI datasets**, connections are made through the **REST API**, using either delegated authentication or a service principal depending on the scenario.

<!-- ![NL2SQL Architecture Diagram](../media/nlsql-architecture.png)
*Architecture Overview* -->

---

## Agent Orchestration

The orchestrator employs a multi-agent system to process queries and manage conversations. The current implementation uses a single strategy, NL2SQL, which consists of a team of agents working together in a fixed sequence.

<!-- ![Agent Team](../media/nl2sql-agent-and-tools.png)
*Agent Team for NL2SQL Strategies* -->

### Key Agents and Their Roles:

- **Triage Agent:** Analyzes user input and selects the appropriate SQL data source.
- **SQL Query Agent:** Translates the user question into a SQL query, retrieves relevant examples, validates, and executes the query.
- **Answer Synthesis Agent:** Formats the SQL results into a clear, concise natural-language answer and signals the end of the conversation.

>
> You can create custom variations of this strategy to fit your project requirements.

---

## Prerequisites (by Data Source Type)

The orchestrator supports different authentication methods depending on the data source used. This section outlines the prerequisites for each data source type. Specific configuration instructions are provided in the next section.

### **Azure SQL Databases**

When connecting to **Azure SQL Databases**, you have two authentication options:

- **Managed Identity (Preferred):** Uses the system-assigned or user-assigned identity of the Orchestrator Container App. The prerequisite is to ensure that the orchestrator’s managed identity has the `db_datareader` role on the target database.

![SQL Database configuration](../media/sql-database-configuration-role-assignment.png)  
*SQL Database configuration — example: assigning read access to the Container App.*

- **SQL Server Authentication:** Requires a `uid` and password for a user with read access to the database. The password must be stored in **Azure Key Vault**, following the naming convention `{datasource_id}-secret`. Configuration details are provided in the next section.

> 
> Make sure **Allow Azure services and resources to access this server** is set to true in SQL Database Server page in both options.

### **Microsoft Fabric**

The Microsoft Fabric connector can be configured in one of the following modes:

- **SQL Endpoint:** Used for executing SQL queries on lakehouses and warehouses.
- **Semantic Model:** Used for executing DAX queries on Power BI datasets.

#### **SQL Endpoint**

SQL Endpoint connections use the **Microsoft ODBC Driver** and authenticate via an **App Registration** in **Entra ID**.

The prerequisites include:

1. Creating an App Registration in Entra ID.
2. Adding the App Registration to a security group for easier access management.
3. Enabling **Service principals can use Fabric APIs** under **Developer settings** in the tenant.

![Fabric Configuration - Semantic Model](../media/semantic-model-configuration02.png)  
*Developer settings*

4. Assigning the Viewer role to the App Registration or security group in the target workspace.

For more details, refer to: [Entra ID Authentication for SQL Endpoint](https://learn.microsoft.com/en-us/fabric/data-warehouse/entra-id-authentication).

#### **Semantic Model**

Semantic model connections are based on the **Power BI REST API** and require the following:

1. Creating an App Registration in Entra ID.
2. Adding the App Registration to a security group for access management.
3. Grant **Dataset.Read.All** permission to your App Service: Go to **App Registration > API permissions > Add a permission**, select **Power BI Service > Delegated permissions**, then choose **Dataset.Read.All**.

4. Enabling **Semantic Model Execute Queries REST API** under **Integration settings** in the tenant.

![Fabric Configuration - Semantic Model](../media/semantic-model-configuration.png)  
*Integration settings*

5. Ensuring users have **dataset read** and **build permissions** on the semantic model.

For more details, refer to: [Power BI REST API Guide](https://learn.microsoft.com/en-us/rest/api/power-bi/datasets/execute-queries).

---

## Data Sources Configuration

**Supported data source types include:**  
- **Semantic Model:** Executes DAX queries using the Power BI REST API.  
- **SQL Endpoint:** Connects via ODBC using a **Service Principal**.  
- **SQL Database:** Connects via ODBC using **Managed Identity**.  

Data source configuration in **GPT-RAG** is managed through JSON documents stored in the `datasources` container of **CosmosDB**. 

![Sample Datasource Configuration](../media/admin-guide-datasource-configuration.png)
<BR>*Sample Datasource Configuration*

### **Semantic Model Example**
```json
{
    "id": "wwi-sales-aggregated-data",    
    "description": "Aggregated sales data for insights such as sales by employee or city.",
    "type": "semantic_model",
    "organization": "myorg",
    "dataset": "your_dataset_or_semantic_model_name",
    "tenant_id": "your_sp_tenant_id",
    "client_id": "your_sp_client_id"    
}
```

### **SQL Endpoint Example**
```json
{
    "id": "wwi-sales-star-schema",
    "description": "Star schema with sales data and dimension tables.",
    "type": "sql_endpoint",
    "organization": "myorg",
    "server": "your_sql_endpoint.fabric.microsoft.com",
    "database": "your_lakehouse_name",
    "tenant_id": "your_sp_tenant_id",
    "client_id": "your_sp_client_id"
}
```

### **SQL Database Example**
```json
{
    "id": "adventureworks",
    "description": "AdventureWorksLT database with customers, orders, and products.",
    "type": "sql_database",
    "database": "adventureworkslt",
    "server": "sqlservername.database.windows.net"
}
```

For data sources that require secrets—such as those accessed via a **Service Principal** or **SQL Server** using SQL authentication—passwords are stored in **Azure Key Vault** following the naming convention `{datasource_id}-secret`.  

**Example:** If the `datasource_id` is `wwi-sales-star-schema`, the corresponding secret name in Key Vault should be `wwi-sales-star-schema-secret`.

<!-- ![Sample Datasource Secrets](../media/admin-guide-datasource-secrets.png)
<BR>*Sample Datasource Secrets* -->

> 
> Example data source configuration files are available in the [sample folder](../samples/fabric/datasources.json).

---

## NL2SQL metadata

NL2SQL metadata is essential for **NL2SQL** and **Chat with Fabric** scenarios, providing metadata about queries, tables, and measures that the orchestrator uses to generate optimized SQL and DAX queries. This section explains how to document the metadata and outlines the indexing process.

### **How to document NL2SQL metadata**

NL2SQL metadata includes three types of content:

- **Tables:** Descriptions of tables used by the chatbot to generate queries. In the column descriptions, provide at least the column names and their descriptions; optionally, you can include data types and example values for greater clarity
- **Queries:** Sample queries used for few-shot learning by the orchestrator. These are optional, use this only for frequently used queries that help optimize the AI agents' performance.
- **Measures:** Definitions of measures for **Semantic Model** data sources, including name, description, data type, and source information. Only include measures that are essential and beneficial for the chatbot to answer user questions clearly and accurately.

Each content type is represented as a JSON file with specific attributes and should be organized into folders:

- **`tables/`**: Store JSON files that describe tables.
- **`measures/`**: Store JSON files that define measures.
- **`queries/`**: Store JSON files that contain sample queries.

The file names are flexible and should follow a clear naming convention for easy identification:

- Table files should be named after the table (e.g., `dimension_city.json`).
- Measure files should use the measure name (e.g., `total_revenue.json`).
- Query files should have descriptive names that indicate their purpose (e.g., `top_5_expensive_products.json`).

> 
> The `datasource` field can be any name of your choice. This name will be used to reference the datasource within GPT-RAG and must contain only alphanumeric characters and dashes.

### **NL2SQL metadata elements**

Before the examples, here are the field descriptions for each element type:

#### **Tables**
- **table:** The name of the table.  
- **description:** A brief description of the table's purpose and content.  
- **datasource:** The data source where the table resides.  
- **columns:** A list of columns within the table, each with the following attributes:  
  - **name:** The name of the column.  
  - **description:** A brief description of the column's content.  
  - **type:** (Optional) The data type of the column, using the datasource's type names.
  - **examples:**  (Optional) Sample values that the column might contain.  

#### **Queries**
- **datasource:** The data source where the query is executed.  
- **question:** The natural language question that the query answers.  
- **query:** The SQL or DAX query that retrieves the desired data.  
- **reasoning:**  (Optional) An explanation of how the query works and its purpose.  

#### **Measures**
- **datasource:** The data source where the measure is defined.  
- **name:** The name of the measure.  
- **description:** A brief description of what the measure calculates.  
- **type:** "external" (from another model) or "local" (calculated within the current model). 
- **source_table:** (Local only) The table associated with the local measure.  
- **data_type:** (External only) Measure's data type (e.g., CURRENCY, INTEGER, FLOAT).  
- **source_model:** (External only) The source model for external measures.  

---

### **Examples**

#### **Tables**

Example of table metadata file with example column values:

```json
{
    "table": "dimension_city",
    "description": "City dimension table containing details of locations associated with sales and customers.",
    "datasource": "wwi-sales-star-schema",
    "columns": [
        { "name": "CityKey", "description": "Primary key for city records.", "type": "int", "examples": [1, 2, 3, 4, 5] },
        { "name": "City", "description": "Name of the city.", "type": "string", "examples": ["New York", "London", "Tokyo", "Paris", "Sydney"] },
        { "name": "Population", "description": "Population of the city.", "type": "int", "examples": [8419600, 8982000, 13929286, 2148000, 5312000] }
    ]
}
```

Example of simplified table metadata file with only required attributes:

```json
{
    "table": "sales_order",
    "description": "Table containing sales order data, including order IDs, dates, and customer information.",
    "datasource": "wwi-sales-data",
    "columns": [
        { "name": "OrderID", "description": "Unique identifier for each sales order." },
        { "name": "OrderDate", "description": "Date when the sales order was placed." },
        { "name": "CustomerName", "description": "Name of the customer who placed the order." }
    ]
}
```

#### **Queries**

Example of an SQL query file:

```json
{
    "datasource": "adventureworks",
    "question": "What are the top 5 most expensive products currently available for sale?",
    "query": "SELECT TOP 5 ProductID, Name, ListPrice FROM SalesLT.Product WHERE SellEndDate IS NULL ORDER BY ListPrice DESC",
    "reasoning": "This query retrieves the top 5 products with the highest selling prices that are currently available for sale."
}
```

Example of a DAX query file:

```json
{
    "datasource": "wwi-sales-aggregated-data",
    "question": "Who are the top 5 employees with the highest total sales including tax?",
    "query": "EVALUATE TOPN(5, SUMMARIZE(aggregate_sale_by_date_employee, aggregate_sale_by_date_employee[Employee], aggregate_sale_by_date_employee[SumOfTotalIncludingTax]), aggregate_sale_by_date_employee[SumOfTotalIncludingTax], DESC)",
    "reasoning": "This DAX query identifies the top 5 employees based on the total sales amount including tax."
}
```

#### **Measures**

Example of an external measure JSON:

```json
{
    "datasource": "Ecommerce",
    "name": "Total Revenue (%)",
    "description": "Calculates the percentage of total revenue for the selected period.",
    "type": "external",
    "data_type": "CURRENCY",
    "source_model": "Executive Sales Dashboard"
}
```

Example of a local measure JSON:

```json
{
    "datasource": "SalesDatabase",
    "name": "Total Orders",
    "description": "Counts the total number of sales orders for the selected period.",
    "type": "local",
    "source_table": "sales_order"
}
```

>
> You can find more exampes in the [samples folder](../samples/).

### **How to ingest NL2SQL metadata**

Every NL2SQL metadata element is indexed into an AI Search Index based on its element type: measure, table, or query. This process is handled by an AI Search Indexer, which runs on a scheduled basis or can be triggered manually. 

The diagram below illustrates the NL2SQL data ingestion pipeline:  

![NL2SQL Ingestion Pipeline](../media/nl2sql_ingestion_pipeline.png)
<BR>*NL2SQL Ingestion Pipeline*

#### **Workflow Description**

1. File Detection:
   - The AI Search indexers scan their designated folders:
     - `queries-indexer` scans the `queries` folder.
     - `tables-indexer` scans the `tables` folder.
     - `measures-indexer` scans the `measures` folder.

2. Vector Embedding:
   - The indexer uses the `#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill` to generate vector embeddings with Azure OpenAI Embeddings.
     - For queries, the `question` field is vectorized.
     - For tables, the `description` field is vectorized.
     - For measures, the `description` field is vectorized.

3. Content Indexing:
   - The vectorized content is added to the respective Azure AI Search indexes:
     - Queries are indexed in `nl2sql-queries`.
     - Tables are indexed in `nl2sql-tables`.
     - Measures are indexed in `nl2sql-measures`.

>   
> For proper indexing, ensure that files are placed in their designated folders, as the indexers only scan specific subfolders.