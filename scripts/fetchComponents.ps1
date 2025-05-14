# Delete the gpt-rag-ingestion folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-ingestion") {
    Remove-Item -Path ".\.azure\gpt-rag-ingestion" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/givenscj/gpt-rag-ingestion .\.azure\gpt-rag-ingestion

# Delete the gpt-rag-agentic folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-agentic") {
    Remove-Item -Path ".\.azure\gpt-rag-agentic" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/givenscj/gpt-rag-agentic .\.azure\gpt-rag-agentic

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-orchestrator") {
    Remove-Item -Path ".\.azure\gpt-rag-orchestrator" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/givenscj/gpt-rag-orchestrator .\.azure\gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-frontend") {
    Remove-Item -Path ".\.azure\gpt-rag-frontend" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/givenscj/gpt-rag-frontend .\.azure\gpt-rag-frontend

if ($env:AZURE_USE_MCP -eq "true")
{    
    # Delete the gpt-rag-frontend folder from .azure if it exists
    if (Test-Path -Path ".\.azure\gpt-rag-mcp") {
        Remove-Item -Path ".\.azure\gpt-rag-mcp" -Recurse -Force
    }

    # Clone the repository into the .azure folder
    git clone https://github.com/givenscj/gpt-rag-mcp .\.azure\gpt-rag-mcp
}