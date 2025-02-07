# Delete the gpt-rag-ingestion folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-ingestion") {
    Remove-Item -Path ".\.azure\gpt-rag-ingestion" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-ingestion .\.azure\gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-orchestrator") {
    Remove-Item -Path ".\.azure\gpt-rag-orchestrator" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-orchestrator .\.azure\gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-frontend") {
    Remove-Item -Path ".\.azure\gpt-rag-frontend" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Azure/gpt-rag-frontend .\.azure\gpt-rag-frontend
