#!/bin/sh

# Delete the gpt-rag-ingestion folder from .azure if it exists
if [ -d ./.azure/gpt-rag-ingestion ]; then
    rm -rf ./.azure/gpt-rag-ingestion
fi

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if [ -d ./.azure/gpt-rag-orchestrator ]; then
    rm -rf ./.azure/gpt-rag-orchestrator
fi

# Delete the gpt-rag-frontend folder from .azure if it exists
if [ -d ./.azure/gpt-rag-frontend ]; then
    rm -rf ./.azure/gpt-rag-frontend
fi
