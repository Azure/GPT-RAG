# Delete the gpt-rag-ingestion folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-ingestion") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-ingestion" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Salesfactory/gpt-rag-ingestion .\.salesfactory\gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-orchestrator") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-orchestrator" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Salesfactory/gpt-rag-orchestrator .\.salesfactory\gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-frontend") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-frontend" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone https://github.com/Salesfactory/gpt-rag-frontend .\.salesfactory\gpt-rag-frontend
