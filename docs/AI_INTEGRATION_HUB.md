# AI Integration HUB

Leverages the power of various external data sources to enhance its capabilities. 

Currently, we have integrated the following sources:

+ Search AI
+ Bing Custom Services
+ SQL Service
+ Teradata

The AI Integration HUB enhances GPT-RAG by integrating various external data sources:

 - Search AI: Enables access to vast online databases, providing precise and up-to-date information.

 - Bing Custom Services: Customizes search results for specific business needs, ensuring relevance and quality.

 - SQL Service: Queries extensive internal databases for accurate and current organizational data, performing analytical functions like count, sum, average, and more.

 - Teradata: Integrates large-scale data warehousing capabilities, enhancing data retrieval and analysis.
Integrating these sources allows for more comprehensive, contextually accurate responses tailored to user needs, leading to better decision-making, improved efficiency, and significant value addition while ensuring data security and ethical use.

# Custom Bing Search Service

Custom Bing Search is a service provided by Microsoft that allows users to create tailored search experiences using the power of Bing's search capabilities. This service enables the customization of search results to better align with specific business needs, by focusing on specific domains, filtering out unwanted content, and ranking results based on the importance to the organization.

### Benefits of Custom Bing Search:

1. **Personalized Search Experience**: Custom Bing Search allows businesses to fine-tune search results to match their specific requirements. This means that users can get more relevant and context-specific results based on predefined criteria.
2. **Domain-Specific Searches**: You can restrict searches to specific websites or domains, ensuring that the results are more relevant to your industry or area of interest. This is particularly useful for businesses that need to focus on niche information or sources.
3. **Content Filtering**: Custom Bing Search provides the ability to filter out unwanted content, ensuring that search results meet the quality and relevance standards set by the organization.
4. **Improved Relevance and Ranking**: By customizing the ranking of search results, businesses can ensure that the most important and relevant information is prioritized, improving the overall efficiency of the search process.
5. **Enhanced Control**: Businesses have more control over the search experience, allowing them to tailor the search functionality to better serve their users' needs and expectations.

In summary, Custom Bing Search empowers organizations to deliver a more effective and efficient search experience by customizing the search parameters to align with their specific needs and priorities. This leads to improved user satisfaction and better utilization of information resources.

### **BING Deployment Procedure**

1. Create Custom Bing Services from Azure Portal
2. Once the service is created go to the following site: https://www.customsearch.ai/ click Sign In in top right and create a new instance. 
3. Add the URLs that I need to include for my solution, make sure to order the ranking of the results using the arrows.
4. Click on Publish and that will generate the CustomCustomConfigID.
5. Open the Azure Key Vault located in the Resource Group of GPT-RAG and add the following secrets: (bingAPIKey & bingCustomConfigID)
6. Create/Update the following Environment Variables under the Orchestrator:
    1. "BING_SEARCH_TOP_K": 3 (Top 3 Results from Bing)
    2. "BING_RETRIEVAL":"true"
    3. "RETRIEVAL_PRIORITY": "bing" (If you have multiple sources you are prioritizing the Bing as first query)
    4. "BING_SEARCH_MAX_TOKENS": "1000"
7. Once is done you can open the Orchestrator Log Stream from Azure Portal in order to confirm the retrieval are coming from the sites.

# SQL Integration Queries as Natural Language

SQL Integration is a service that allows users to seamlessly connect and query their SQL databases. This service enhances the capabilities of GPT-RAG by enabling the retrieval and analysis of structured data from various SQL databases.

### Benefits of SQL Integration:

1. **Custom Queries**: SQL Integration allows users to create custom queries to extract specific data points, ensuring that the information retrieved is highly relevant to their needs.
   
2. **Analytical Functions**: Users can perform various analytical functions such as count, sum, average, min, and max, enabling detailed insights and data analysis directly from the database.
   
3. **Data Aggregation**: SQL Integration supports data aggregation and grouping, which helps in summarizing large datasets and extracting meaningful patterns and trends.
   
4. **Real-Time Data Access**: By integrating with SQL databases, users can access real-time data, ensuring that the responses generated are based on the most current information available.
   
5. **Enhanced Data Management**: The service allows for efficient data management and retrieval, helping organizations maintain a well-organized and easily accessible data repository.

### **SQL Deployment Procedure**

Currently the integration is performed by SQL User & Password. 

1. **Add/Update Environment Variable**: "DB_RETRIEVAL": "true" in the Orchestrator Function.
2. **Add/Update Environment Variable**: "DB_TYPE": "sql" in the Orchestrator Function.
3. **Add/Update Environment Variable**: ""RETRIEVAL_PRIORITY": "db" in the Orchestrator Function.
4. **Add/Update Environment Variable**: "DB_TOP_K": "3" in the Orchestrator Function.
5. **Add/Update Environment Variable**: "DB_MAX_TOKENS": "1000" in the Orchestrator Function.
6. **Add/Update Environment Variable**: "DB_SERVER": "{your_sql_server}" in the Orchestrator Function.
7. **Add/Update Environment Variable**: "DB_USERNAME": "{your_sql_username}" in the Orchestrator Function.
8. **Add/Update Environment Variable**: "DB_DATABASE": "{your_sql_database}" in the Orchestrator Function.
9. **Add the following secrets** in the Azure Key Vault: "sqlpassword" and enter the password for the SQL Authentication.
10. Once is done you can open the Orchestrator Log Stream from Azure Portal in order to confirm the retrieval comes from SQL.



# Teradata

Integrating Azure OpenAI with Teradata allows users to seamlessly connect and query their Teradata databases. This integration enhances analytical capabilities by enabling the retrieval and analysis of structured data from various Teradata databases.

### Benefits of Integration with Teradata:

- **Custom Queries**: Users can create specific queries to extract highly relevant data points.
- **Analytical Functions**: Perform functions such as count, sum, average, min, and max directly from the database, providing detailed insights.
- **Data Aggregation**: Supports data aggregation and grouping to summarize large datasets and extract meaningful patterns and trends.
- **Real-Time Data Access**: Access to real-time data ensures that responses are based on the most current information available.
- **Enhanced Data Management**: Enables efficient data management and retrieval, helping organizations maintain a well-organized and easily accessible data repository.
- **Predictive Analytics**: Utilize predictive analytics to forecast future trends and behaviors based on historical data.
- **Machine Learning Integration**: Seamlessly incorporate machine learning models to enhance data analysis, enabling more accurate predictions and insights.
- **Natural Language Processing (NLP)**: Leverage Azure OpenAI’s NLP capabilities for advanced text and sentiment analysis on unstructured data.
- **Advanced Data Visualization**: Supports advanced data visualization techniques, helping users better understand and communicate complex data through interactive and intuitive visual formats.
- **Automated Insights**: AI-driven algorithms automatically generate insights and recommendations, reducing the time and effort required for manual data analysis.

This integration offers a powerful combination of advanced analytical capabilities and efficient data management, enhancing the use of artificial intelligence in decision-making and extracting valuable insights for organizations.

### **Teradata Deployment Procedure**
1. **Add/Update Environment Variable**: "DB_RETRIEVAL": "true" in the Orchestrator Function.
2. **Add/Update Environment Variable**: "DB_TYPE": "teradata" in the Orchestrator Function.
3. **Add/Update Environment Variable**: ""RETRIEVAL_PRIORITY": "db" in the Orchestrator Function.
4. **Add/Update Environment Variable**: "DB_TOP_K": "3" in the Orchestrator Function.
5. **Add/Update Environment Variable**: "DB_MAX_TOKENS": "1000" in the Orchestrator Function.
6. **Add/Update Environment Variable**: "DB_SERVER": "{your_teradata_server}" in the Orchestrator Function.
7. **Add/Update Environment Variable**: "DB_USERNAME": "{your_teradata_username}" in the Orchestrator Function.
8. **Add/Update Environment Variable**: "DB_DATABASE": "{your_teradata_database}" in the Orchestrator Function.
9. **Add the following secrets** in the Azure Key Vault: "teradatapassword" and enter the password for the SQL Authentication.
10. Once is done you can open the Orchestrator Log Stream from Azure Portal in order to confirm the retrieval comes from teradata.

# Multiple databases

To connect to more than one database, the DBRetrieval should be replicated, once per required database.
### **Multiple databases Deployment Procedure**
1. **Replicate DBRetrieval function**: Duplicate the “DBRetrieval” function in the orchestrator retrieval plugin. You’ll find it in the file “native_function.py” in "/orc/plugins/Retrieval".
2. **Create Enviroment Variable**: Make a copy of the following set of variables: [DB_TYPE, DB_SERVER, DB_USERNAME, DB_DATABASE, DB_TOP_K, DB_MAX_TOKENS]. Assign them new names.
3. **Create Secret on Key Vault**: Create a new secret on the key vault with the password to the added database.
4. **Create File With Table Data**: Create a new file with a description of each table in the database.
5. **Include Variables in File**: Include the New Variables in Your Code: For example: 
```python
DB_SERVER_2 = os.environ.get("DB_SERVER_2")
DB_DATABASE_2 = os.environ.get("DB_DATABASE_2")
DB_USERNAME_2 = os.environ.get("DB_USERNAME_2")
DB_TOP_K_2 = os.environ.get("DB_TOP_K_2")
DB_MAX_TOKENS_2 = os.environ.get("DB_MAX_TOKENS_2")
DB_TYPE_2 = os.environ.get("DB_TYPE_2")
```
Then, replace the environment variables, secret and table info file only in the replicated “DBRetrieval” function with the created ones.

6. **Include Replicated Function in Orchestration Code**: In the file “code_orchestration.py,” add the replicated function. For example:
```python
if(DB_RETRIEVAL):
    db_function_result= await kernel.invoke(retrievalPlugin["DBRetrieval"], sk.KernelArguments(input=search_query))
    formatted_sources = db_function_result.value[:100].replace('\n', ' ')
    escaped_sources = escape_xml_characters(db_function_result.value)
    db_sources=escaped_sources
    db_function_result_2=await kernel.invoke(retrievalPlugin["DBRetrieval2"], sk.KernelArguments(input=search_query))
    formatted_sources_2 = db_function_result_2.value[:100].replace('\n', ' ')
    escaped_sources_2 = escape_xml_characters(db_function_result.value)
    db_sources+=escaped_sources_2
    logging.info(f"[code_orchest] generated DB sources: {formatted_sources + formatted_sources_2}")

```