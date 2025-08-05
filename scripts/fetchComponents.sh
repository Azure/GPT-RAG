#!/bin/sh

# Delete the gpt-rag-ingestion folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-ingestion ]; then
    rm -rf ./.salesfactory/gpt-rag-ingestion
fi

# Clone the repository into the .salesfactory folder
git clone -b develop https://github.com/Salesfactory/gpt-rag-ingestion ./.salesfactory/gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-orchestrator ]; then
    rm -rf ./.salesfactory/gpt-rag-orchestrator
fi

# Clone the repository into the .salesfactory folder
git clone -b develop https://github.com/Salesfactory/gpt-rag-orchestrator ./.salesfactory/gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .salesfactory if it exists
if [ -d ./.salesfactory/gpt-rag-frontend ]; then
    rm -rf ./.salesfactory/gpt-rag-frontend
fi

# Clone the repository into the .salesfactory folder
git clone -b develop https://github.com/Salesfactory/gpt-rag-frontend ./.salesfactory/gpt-rag-frontend

# Delete the freddAid-MCP-server folder from .salesfactory if it exists
if [ -d ./.salesfactory/freddAid-MCP-server ]; then
    rm -rf ./.salesfactory/freddAid-MCP-server
fi

# Clone the freddAid-MCP-server repository into the .salesfactory folder
git clone -b develop https://github.com/Salesfactory/freddAid-MCP-server ./.salesfactory/freddAid-MCP-server
