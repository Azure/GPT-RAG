#!/bin/sh

# Delete the gpt-rag-ingestion folder from .azure if it exists
if [ -d ./.azure/gpt-rag-ingestion ]; then
    rm -rf ./.azure/gpt-rag-ingestion
fi

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-ingestion ./.azure/gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if [ -d ./.azure/gpt-rag-orchestrator ]; then
    rm -rf ./.azure/gpt-rag-orchestrator
fi

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-orchestrator ./.azure/gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .azure if it exists
if [ -d ./.azure/gpt-rag-frontend ]; then
    rm -rf ./.azure/gpt-rag-frontend
fi

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-frontend ./.azure/gpt-rag-frontend
