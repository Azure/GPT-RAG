# Multimodal RAG Overview

This document outlines the architecture and workflow for our **multimodal Retrieval Augmented Generation (RAG)** solution, integrating **AI Search Service**, **Azure OpenAI embeddings**, and **Azure Functions**. The goal is to enrich responses with **textual and visual content** (e.g., images) extracted from ingested documents, all managed within a unified search index.

## Key Components

- **Azure Blob Storage**: Stores original documents, extracted text, and associated images.
- **Azure Functions**: Orchestrates ingestion, text and image extraction, embedding generation, indexing, and data cleanup.
- **Azure Document Processing Service**: Extracts text segments and identifies images from source documents, enabling multimodal content association.
- **Azure OpenAI**: Generates semantic embeddings for both text and image descriptions.
- **AI Search Service**: Hosts a unified index for both textual embeddings and image descriptions.

## Multimodal End-to-End Workflow

1. **Data Ingestion**  
   - Documents files are uploaded to Azure Blob Storage.
   - An Azure Function triggers upon new file uploads.

2. **Preprocessing & Content Extraction**  
   - The Azure Function invokes the Azure Document Processing Service to extract:
     - Text segments (e.g., paragraphs, sections).
     - Associated images, stored separately in Blob Storage.
   - For each text segment with related images, a GPT model generates a **combined textual description** of the images.

3. **Embedding Generation**  
   - Azure OpenAI generates:
     - Text embeddings stored in `contentVector`.
     - Embeddings for combined image descriptions stored in a new field, `captionVector`.

4. **Unified Multimodal Indexing**  
   The search index is extended to include multimodal data:
   - **Fields**:
     - `content` & `contentVector`: Original text and its embeddings.
     - `imageCaptions` & `captionVector`: Descriptions of associated images and their embeddings.
     - `relatedImages`: URLs pointing to images in Blob Storage.
   - Each document represents a text segment and its associated images, forming a complete multimodal unit.

5. **Query & Retrieval**  
   When a user submits a query:
   - Convert the query to embeddings using Azure OpenAI.
   - Perform retrieval, searching both `contentVector` and `captionVector` fields.
   - Results include both textual context and references to relevant images.

6. **Response Generation (GPT-4o)**  
   - Build a multimodal prompt that includes retrieved text, image descriptions, and image URLs.
   - GPT-4 generates a final enriched response, referencing both textual and visual elements.

7. **Document & Image Lifecycle Management**  
   - Deleting a document from the index triggers an Azure Function to remove associated images from Blob Storage.
   - This ensures synchronization between the index and storage.

## Architectural Decisions

- **Multimodal Unified Index**: A single index consolidates both text and image data, simplifying retrieval and management.
- **Single Embedding Model**: Azure OpenAI embeddings are reused for both text and image descriptions, reducing complexity.
- **Combined Image Captions**: Related images are grouped into one descriptive field for easier retrieval.
- **Two Vector Fields**:
  - `contentVector`: For text embeddings.
  - `captionVector`: For image description embeddings.

## Benefits

- **Multimodal Capabilities**: Supports text-only, image-focused, or hybrid queries seamlessly.
- **Simplified Architecture**: Reuses the same embedding model and index for multimodal data.
- **Enhanced User Experience**: Delivers enriched responses combining textual and visual elements.
- **Scalability**: Leverages Azure-native services (Functions, Storage, AI Search Service, and Azure OpenAI) for robust and scalable performance.
