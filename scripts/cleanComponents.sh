#!/bin/sh

# Delete the gpt-rag-ingestion folder from .azure if it exists
if [ -d ./.azure/gpt-rag-ingestion ]; then
    rm -rf ./.azure/gpt-rag-ingestion
fi
