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

1. **Add/Update Environment Variable**: ""RETRIEVAL_PRIORITY": "sql" in the Orchestrator Function.
2. **Add/Update Environment Variable**: "SQL_TOP_K": "3" in the Orchestrator Function.
3. **Add/Update Environment Variable**: "SQL_MAX_TOKENS": "1000" in the Orchestrator Function.
4. **Add the following secrets** in the Azure Key Vault: "sqlpassword" and enter the password for the SQL Authentication.
5. **Copy the following example in the code_orchestrator.py** in order to perform the query.
6. **Test Connectivity** perform a GET using Postman with the following params:
```json
   'sql_search': sql_search,
   'sql_server': sql_server,
   'sql_database': sql_database,
   'sql_table_info': sql_table_info,
   'sql_username': sql_username,
   'sql_top_k': sql_top_k,
```


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
1. **Add/Update Environment Variable**: ""RETRIEVAL_PRIORITY": "teradata" in the Orchestrator Function.
2. **Add/Update Environment Variable**: "TERADATA_TOP_K": "3" in the Orchestrator Function.
3. **Add/Update Environment Variable**: "TERADATA_MAX_TOKENS": "1000" in the Orchestrator Function.
4. **Add the following secrets** in the Azure Key Vault: "teradatapassword" and enter the password for the Teradata Authentication.
5. **Copy the following example in the code_orchestrator.py** in order to perform the query.
6. **Test Connectivity** perform a GET using Postman with the following params:
```json
        'teradata_search': teradata_search,
        'teradata_username': teradata_username,
        'teradata_server': teradata_server,
        'teradata_database': teradata_database,
        'teradata_table_info': teradata_table_info,
        'teradata_top_k': teradata_top_k
```