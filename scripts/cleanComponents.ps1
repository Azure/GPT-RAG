# Delete the gpt-rag-ingestion folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-ingestion") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-ingestion" -Recurse -Force
}

# Delete the gpt-rag-orchestrator folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-orchestrator") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-orchestrator" -Recurse -Force
}

# Delete the gpt-rag-frontend folder from .salesfactory if it exists
if (Test-Path -Path ".\.salesfactory\gpt-rag-frontend") {
    Remove-Item -Path ".\.salesfactory\gpt-rag-frontend" -Recurse -Force
}
