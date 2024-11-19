# Estimated Monthly Cost for Running the Accelerator

This page provides reference estimates for the cost of running the accelerator for one month.

## 1. Default GPT-RAG Zero Trust Deployment

To view the cost estimate for this scenario, visit the [Azure Pricing Calculator](https://azure.com/e/75c446632f8c4c4ba613610d9fb0f68b). The link provides a breakdown of all solution components and their respective costs.

### Usage Parameters Used for the Estimate:

#### Document Intelligence
- **Number of documents**: 500
- **Pages per document**: 20
- **Total pages**: 10,000

#### CosmosDB
- **Data stored**: 500 GB
- **Operations per second**: 
  - **Creates**: 20 
  - **Reads**: 20 
  - **Updates**: 20


#### Azure OpenAI
- **Number of user conversations per day**: 100
- **Average interactions per conversation**: 5
- **Total Azure GPT requests per month**: 15,000

---

### Token Calculation for Azure OpenAI

#### **Prompt Tokens**
1. **Triage**: 450 tokens
2. **Answer**: 221 tokens + Sources = 2,221 tokens
3. **Is Grounded**: 99 tokens + Sources = 2,099 tokens

**Total prompt tokens per 1,000 requests**:
```
(2099 + 2221 + 450) * 15000 / 1000 = 71,550 tokens
```

#### **Completion Tokens**
1. **Is Grounded**: 4 tokens
2. **Triage**: 10 tokens
3. **Answer**: 800 tokens

**Total completion tokens per 1,000 requests**:
```
(4 + 800 + 10) * 15000 / 1000 = 12,210 tokens
```
---

### Note on Embeddings
For **Ada embeddings**, considering the volume of 500 documents used to generate embeddings, estimate an additional cost of approximately **$100**.

---

### References
1. [CosmosDB Capacity Calculator](https://cosmos.azure.com/capacitycalculator/)
2. [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
