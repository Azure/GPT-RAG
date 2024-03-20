#!/bin/sh

# Delete the gpt-rag-ingestion folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-ingestion ]; then
    rm -rf ./.salesfactory/gpt-rag-ingestion
fi

# Delete the gpt-rag-orchestrator folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-orchestrator ]; then
    rm -rf ./.salesfactory/gpt-rag-orchestrator
fi

# Delete the gpt-rag-frontend folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-frontend ]; then
    rm -rf ./.salesfactory/gpt-rag-frontend
fi
