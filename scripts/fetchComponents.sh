#!/bin/sh

# Delete the gpt-rag-ingestion folder from .azure if it exists
if [ -d ./.azure/gpt-rag-ingestion ]; then
    rm -rf ./.azure/gpt-rag-ingestion
fi

# Clone the repository into the .azure folder
#git clone https://github.com/Azure/gpt-rag-ingestion ./.azure/gpt-rag-ingestion
git clone https://github.com/vhvb1989/gpt-rag-ingestion ./.azure/gpt-rag-ingestion
