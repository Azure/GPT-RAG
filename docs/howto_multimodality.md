GPT-RAG supports end-to-end multimodal processing: from document ingestion (extracting figures and generating captions) through orchestration (retrieving and presenting images alongside text to a vision-capable model). This page covers both sides.

> Multimodal processing is opt-in. When disabled (the default), the ingestion pipeline ignores figures and the orchestrator works with text only.

> **Retrieval backend note:** Multimodal captioning parity for Foundry IQ Pattern
> A is not yet proven. Keep multimodal workloads on `RETRIEVAL_BACKEND=ai_search`
> or Foundry IQ Pattern B (`FOUNDRY_IQ_PATTERN=searchIndex`) until your own smoke
> tests confirm that managed-source captioning returns equivalent visual context.

The feature spans two components:

- **Ingestion** (`gpt-rag-ingestion`) — extracts figures from documents, generates captions, creates caption embeddings, and stores everything in Azure AI Search.
- **Orchestrator** (`gpt-rag-orchestrator`) — retrieves chunks with their images from the search index, downloads figures from blob storage, and sends multimodal content (text + base64 images) to a vision-capable model so the answer can reference and embed diagrams, charts, and photos.

---

## Ingestion

The multimodal ingestion pipeline goes through four steps: document analysis, figure extraction, caption generation, and chunk attachment. The first two steps differ depending on the analysis backend; the last two are shared.

**Analysis backends: Content Understanding vs Document Intelligence**

GPT-RAG supports two Azure AI services for document analysis. The choice is controlled by the `USE_DOCUMENT_INTELLIGENCE` setting in App Configuration (default `false`).

| | Content Understanding (default) | Document Intelligence |
| --- | --- | --- |
| **Setting** | `USE_DOCUMENT_INTELLIGENCE=false` | `USE_DOCUMENT_INTELLIGENCE=true` |
| **What it does** | Analyzes the document and returns structured markdown with inline figure references (`![caption](figures/X.Y)`) plus figure metadata (IDs, bounding regions, page associations). Does **not** provide figure image bytes — only metadata. | Analyzes the document and returns structured markdown with `<figure>` tags plus figure metadata. Also exposes a server-side `get_figure` API that returns the actual figure image bytes on demand. |
| **How figures are extracted** | **Locally**, from the original source file. The pipeline downloads the source document and uses format-specific extraction: PyMuPDF for PDFs (page rendering + bounding-box crop), ZIP media extraction for DOCX (`word/media/`) and PPTX (`ppt/media/`). | **Server-side**, via the `get_figure(model_id, result_id, figure_id)` API call. Document Intelligence crops and returns the figure image directly — no local file processing needed. |
| **Bounding regions** | Returned for native PDFs; often missing for scanned PDFs. When missing, the pipeline falls back to full-page rendering and maps figures to pages using the figure ID convention `X.Y` (where `X` = page number). | Typically returned for all figure types. The server-side API handles cropping internally. |
| **Cost model** | Per-page analysis pricing (Content Understanding) | Per-page analysis pricing (Document Intelligence) |
| **When to use** | Default choice. Broader format support, lower cost for most workloads. | When you need the DI-specific `get_figure` API or other DI-only features (e.g., key-value extraction, custom models). |

Both backends produce the same downstream result: figure metadata that the pipeline uses to extract images, generate captions, and populate the search index. From step 3 onward the flow is identical regardless of which backend was used.

**The four pipeline steps**

1. **Document analysis** — the document is sent to the chosen analysis service, which returns structured markdown content with figure references embedded inline at the position where each figure appears in the source document. Content Understanding uses `![caption](figures/X.Y)` markdown syntax (normalized to `<figureX.Y>` tags internally); Document Intelligence uses `<figure>` XML tags directly.

2. **Figure extraction** — for each detected figure, the pipeline obtains the image bytes. With Content Understanding this means local extraction from the source file (PDF: PyMuPDF render + crop; DOCX/PPTX: ZIP media extraction). With Document Intelligence this means a server-side API call (`get_figure`). Either way, the result is PNG image bytes per figure.

3. **Caption generation** — each extracted figure image is sent to a vision-capable Azure OpenAI model (e.g. `gpt-4o`, `gpt-4o-mini`) which generates a natural-language description optimized for retrieval.

4. **Chunk attachment** — figure references (`<figureX.Y>` tags) are naturally distributed across text chunks because they appear inline in the markdown content. Each chunk only gets the figures that fall within its text region. The pipeline uploads the figure image to blob storage, attaches the blob URL and caption to the chunk, and generates an embedding vector for the caption.

The result in Azure AI Search is that each chunk document may contain:

- `relatedImages` — an array of blob URLs pointing to the extracted figure images
- `imageCaptions` — a combined text description of all figures in that chunk
- `captionVector` — an embedding vector for the combined caption, enabling semantic search over visual content

<div class="no-wrap">
```
Source Document (PDF, DOCX, PPTX)
    │
    ▼
Analysis Service
    ├─ Content Understanding (default)     ├─ Document Intelligence
    │  Returns: markdown + figure metadata │  Returns: markdown + figure metadata
    │  No image bytes                      │  + get_figure API for image bytes
    ▼                                      ▼
Figure Extraction                     Figure Extraction
    ├─ PDF: PyMuPDF render + crop          └─ DI get_figure API call
    ├─ DOCX: word/media/ ZIP extraction
    └─ PPTX: ppt/media/ ZIP extraction
    │                                      │
    ▼──────────────────────────────────────▼
Caption Generation (Azure OpenAI vision model)
    │  Returns: natural-language description per figure
    ▼
Chunk Assembly
    │  Each chunk gets: text + figure URLs + captions + caption embedding
    ▼
Azure AI Search Index
    Fields: content, contentVector, relatedImages, imageCaptions, captionVector
```
</div>

**How figures relate to chunks**: the analysis service embeds figure references at the exact position in the markdown where the figure appears in the document. When the text is split into chunks, each chunk inherits only the figure references that fell within its text region. A chunk covering pages 4–6 will only contain figures from those pages. Figures are never duplicated across chunks.

**Fallback behavior for scanned PDFs (Content Understanding path)**: when Content Understanding does not return `boundingRegions` for a figure (common with scanned documents), the pipeline renders the entire page and maps figures to pages using the figure ID convention `X.Y`, where `X` is the page number and `Y` is the figure index on that page. Multiple figures on the same page will reference the same full-page render but receive separate captions. This fallback does not apply to the Document Intelligence path, which handles cropping server-side.

**Supported formats**

| Format | Figure extraction method | Notes |
| --- | --- | --- |
| **PDF** | PyMuPDF page rendering + bounding-box crop | Falls back to full-page render when no bounding regions |
| **DOCX** | ZIP extraction from `word/media/` | Images mapped to figures by document order |
| **PPTX** | ZIP extraction from `ppt/media/` | Images mapped to figures by document order |
| **Images** (PNG, JPEG, BMP, TIFF) | Processed as single-page documents | The entire image is treated as one figure |

**Configuration** — all settings are configured in Azure App Configuration with the `gpt-rag` label.

*Required settings for multimodal processing:*

| Setting | Value | Description |
| --- | --- | --- |
| `MULTIMODAL` | `true` | Master switch — enables multimodal chunking. When `false` (default), figures are ignored. |
| `VISION_DEPLOYMENT_NAME` | e.g. `gpt-4o-mini` | Azure OpenAI deployment name for the vision-capable model used to generate figure captions. Must support image input. If not set, falls back to `CHAT_DEPLOYMENT_NAME`, which may not support vision. |

*Related settings (typically pre-configured):*

| Setting | Default | Description |
| --- | --- | --- |
| `CHAT_DEPLOYMENT_NAME` | *(required)* | Primary Azure OpenAI deployment for text completions. Used as fallback for vision if `VISION_DEPLOYMENT_NAME` is not set. |
| `EMBEDDING_DEPLOYMENT_NAME` | *(required)* | Azure OpenAI deployment for generating embedding vectors (used for caption vectors). |
| `STORAGE_ACCOUNT_NAME` | *(required)* | Azure Storage account where figure images are uploaded. |
| `DOCUMENTS_IMAGES_STORAGE_CONTAINER` | `documents-images` | Blob container for extracted figure images. |
| `MINIMUM_FIGURE_AREA_PERCENTAGE` | `4.0` | Minimum figure area as a percentage of the page. Figures smaller than this threshold are skipped to avoid extracting decorative elements, logos, or tiny icons. |

*Analysis service settings:*

| Setting | Default | Description |
| --- | --- | --- |
| `USE_DOCUMENT_INTELLIGENCE` | `false` | Selects the analysis backend. When `false` (default), uses Content Understanding — figure images are extracted locally from the source file using PyMuPDF (PDF) or ZIP media extraction (DOCX/PPTX). When `true`, uses Document Intelligence — figure images are retrieved server-side via the `get_figure` API, with no local extraction needed. See the comparison table above for details. |
| `AI_FOUNDRY_ACCOUNT_ENDPOINT` | *(required)* | Azure AI Foundry endpoint used by both Content Understanding and Document Intelligence. |
| `CONTENT_UNDERSTANDING_ANALYZER` | `prebuilt-layout` | Content Understanding analyzer name (only used when `USE_DOCUMENT_INTELLIGENCE=false`). |

**Setup**

**1) Ensure you have a vision-capable Azure OpenAI deployment.**

The model must support image input for caption generation to work. Recommended models: `gpt-4o`, `gpt-4o-mini`. You can check your deployments with:

```bash
az cognitiveservices account deployment list \
  --name <your-ai-services-name> \
  --resource-group <your-resource-group> \
  --query "[].{name:name, model:properties.model.name}" -o table
```

If you don't have a vision-capable deployment, create one in the Azure portal under your Azure AI Services resource > Model deployments.

**2) Configure the App Configuration settings.**

Set the following keys in Azure App Configuration with the `gpt-rag` label:

```bash
# Enable multimodal processing
az appconfig kv set --name <your-appconfig-name> \
  --key MULTIMODAL --value true --label gpt-rag --yes

# Set the vision model deployment name
az appconfig kv set --name <your-appconfig-name> \
  --key VISION_DEPLOYMENT_NAME --value gpt-4o-mini --label gpt-rag --yes
```

**3) Verify the `documents-images` blob container exists.**

The pipeline uploads extracted figure images to this container. It is typically created during GPT-RAG provisioning. If missing, create it:

```bash
az storage container create \
  --account-name <your-storage-account> \
  --name documents-images \
  --auth-mode login
```

**4) Redeploy the data ingestion container app** to pick up the new configuration, then re-process your documents.

When multimodal is enabled and a document contains figures, the container app logs will show:

```
[multimodal_chunker][filename.pdf] Pre-extracted 12 figure image(s) from source document.
[multimodal_chunker][filename.pdf] Generating caption for figure 1.1.
[multimodal_chunker][filename.pdf] Attached 4 figures to chunk 0.
```

**Troubleshooting**

**Empty captions ("No caption available.")**
The vision model deployment does not support image input, or the deployment name is incorrect. Check that `VISION_DEPLOYMENT_NAME` points to a model like `gpt-4o` or `gpt-4o-mini`. If not set, the pipeline falls back to `CHAT_DEPLOYMENT_NAME`, which may not support vision.

**Figures not appearing in search results**
Check that `MULTIMODAL` is set to `true` in App Configuration with the `gpt-rag` label. Also verify the document was re-indexed after enabling multimodal (existing documents need to be re-processed).

**Scanned PDFs produce full-page images instead of cropped figures**
This is expected behavior. When Content Understanding does not return `boundingRegions` (common with scanned documents), the pipeline renders the full page for each figure. The captions are still generated individually per figure, so the semantic content is preserved even though the image is a full-page render.

**Figure images not uploaded to blob storage**
Check that the `documents-images` container exists in your storage account and that the container app's managed identity has `Storage Blob Data Contributor` on the storage account.

**Some figures are skipped**
Figures smaller than `MINIMUM_FIGURE_AREA_PERCENTAGE` of the page area (default 4%) are automatically skipped. This filters out decorative elements, logos, and small icons. Adjust the threshold in App Configuration if needed.

---

## Orchestrator

Once the ingestion pipeline has populated the Azure AI Search index with text chunks, figure blob URLs, image captions, and caption embeddings, the orchestrator can leverage all of that at query time to produce answers that include diagrams, charts, and photos from the original documents.

The multimodal orchestrator strategy (`MultimodalStrategy`) is a specialized RAG flow built on top of the Microsoft Agent Framework (MAF). It extends the standard text-only approach with vision capabilities. When a user sends a question, the strategy goes through five stages:

1. **Intent classification** — a lightweight LLM call determines whether the message is a greeting/small talk or a real question. If it is a greeting, the search step is skipped entirely and the model responds conversationally.

2. **Dual-vector hybrid search** — the `MultimodalSearchContextProvider` queries Azure AI Search using the user's question. The search combines keyword matching with two vector queries in parallel: one against `contentVector` (text embeddings) and one against `captionVector` (image-caption embeddings). This means a user asking "show me the rocker arm diagram" can match documents not only by text content but also by what their figures depict. Semantic ranking is applied when configured.

3. **Image retrieval and filtering** — for each search result, the provider reads the `relatedImages` field (blob URLs) and the `imageCaptions` field. It selects relevant figures using a two-stage filter:
   - **Heuristic filter** — a fast keyword-based check against the figure path, caption, surrounding text, and user query. Decorative elements (logos, cartoons, footers) are dropped; procedural content (diagrams, assembly steps, cross-sections) is kept.
   - **Vision-based classifier** (optional) — each candidate image is sent to the vision model with a classification prompt. The model returns `KEEP` or `SKIP`. This catches cases the heuristic misses.

   Selected images are downloaded from Azure Blob Storage in parallel and encoded as base64.

4. **Multimodal context assembly** — the provider builds a structured JSON payload where text and images are interleaved in document order. Each image appears at the same position it occupied in the original document, preceded by a label (`📎 Image (embed once only): <path>`) and an image hint derived from its caption. The companion `MultimodalChatClient` detects this structured payload and converts it to OpenAI's vision content format (`[{"type": "text", ...}, {"type": "image_url", ...}]`).

5. **Streaming response with guardrails** — the agent streams the model's answer, then applies two post-processing steps:
   - **Deduplication** — removes any duplicate `![alt](path)` markdown image references, keeping only the first occurrence.
   - **Post-response image validation** (optional) — each image the model chose to embed is re-evaluated by the vision model. Images classified as decorative or irrelevant are stripped from the final answer.

The result is an answer that cites document sources, embeds relevant figures inline next to the text they illustrate, and avoids decorative or off-topic images.

<div class="no-wrap">
```
User Question
    │
    ▼
Intent Classifier (greeting → skip search)
    │
    ▼ (question)
Azure AI Search (keyword + contentVector + captionVector)
    │  Returns: chunks with text, figure blob URLs, captions
    ▼
Image Selection (heuristic + optional vision classifier)
    │  Downloads figure PNGs from Blob Storage → base64
    ▼
Multimodal Context Assembly (text + images interleaved)
    │  JSON payload with MULTIMODAL_PREFIX marker
    ▼
MultimodalChatClient → OpenAI vision format
    │  Sends: [text parts, image_url parts] to vision model
    ▼
Streaming Response + Post-processing
    │  Dedup images, optional validation guardrail
    ▼
Final Answer (text with inline ![Figure](path) references)
```
</div>

**User profile memory**: the strategy also maintains a per-user profile stored in Cosmos DB. The `UserProfileMemory` plugin extracts facts about the user from conversations (e.g., preferences, context) and injects them as context in subsequent sessions. This enables personalized answers across sessions.

**Conversation history**: the strategy sends the last N messages (configurable via `CHAT_HISTORY_MAX_MESSAGES`) to the model for multi-turn context. Image markdown from previous assistant messages is stripped to prevent stale figure references from leaking into the current context.

**Configuration** — the multimodal strategy is activated by setting `AGENT_STRATEGY` to `multimodal` in Azure App Configuration (with the `gpt-rag` label). All other settings below also go in App Configuration with the same label.

*Selecting the strategy:*

| Setting | Value | Description |
| --- | --- | --- |
| `AGENT_STRATEGY` | `multimodal` | Activates the multimodal orchestrator strategy. Other valid values: `maf_lite`, `single_agent_rag`, `mcp`, `nl2sql`, `maf_agent_service`. |

*Core model and search settings (shared with other strategies, typically already configured):*

| Setting | Example | Description |
| --- | --- | --- |
| `AI_FOUNDRY_ACCOUNT_ENDPOINT` | `https://aif-xxx.cognitiveservices.azure.com/` | Azure AI Foundry endpoint for the OpenAI client. |
| `CHAT_DEPLOYMENT_NAME` | `gpt-4o` | The vision-capable model deployment used for answering. Must support image input. |
| `EMBEDDING_DEPLOYMENT_NAME` | `text-embedding-3-large` | Embedding model for hybrid vector search. |
| `SEARCH_SERVICE_QUERY_ENDPOINT` | `https://search-xxx.search.windows.net` | Azure AI Search endpoint. |
| `SEARCH_RAG_INDEX_NAME` | `ragindex` | Name of the search index populated by the ingestion pipeline. |
| `SEARCH_RAGINDEX_TOP_K` | `3` | Number of documents to retrieve per query. |
| `SEARCH_SEMANTIC_SEARCH_CONFIG` | `my-semantic-config` | Semantic ranker configuration name (optional, but recommended). |

*Multimodal-specific settings:*

| Setting | Default | Description |
| --- | --- | --- |
| `MULTIMODAL_MAX_IMAGES` | `10` | Maximum total images sent to the model per request (across all retrieved documents). |
| `MULTIMODAL_MAX_IMAGES_PER_DOC` | `5` | Maximum images extracted from a single search result document. |
| `MULTIMODAL_MAX_CONTENT_CHARS` | `4000` | Maximum characters of text content displayed per document. Figures beyond this cutoff are still included as appended images. |
| `MULTIMODAL_CLASSIFY_IMAGES` | `true` | When enabled, each candidate image is sent to the vision model for a KEEP/SKIP classification before being included in the context. Adds latency but significantly improves image relevance. |
| `MULTIMODAL_IMAGE_CLASSIFICATION_TIMEOUT_SECONDS` | `15` | Timeout for each image classification call. |
| `MULTIMODAL_IMAGE_CLASSIFICATION_CONCURRENCY` | `2` | How many image classification calls run in parallel. |
| `MULTIMODAL_VALIDATE_RESPONSE_IMAGES` | `true` | When enabled, images the model chose to embed in its response are re-validated by the vision model. Decorative or irrelevant images are stripped from the final answer. |
| `MULTIMODAL_IMAGE_VALIDATION_TIMEOUT_SECONDS` | `15` | Timeout for each post-response image validation call. |

*Other relevant settings:*

| Setting | Default | Description |
| --- | --- | --- |
| `CHAT_HISTORY_MAX_MESSAGES` | `10` | Number of recent conversation messages included as context for multi-turn conversations. |
| `MAX_COMPLETION_TOKENS` | `4096` | Hard cap on output tokens for the main agent response. |
| `REASONING_EFFORT` | `medium` | Reasoning effort level for models that support it (e.g., `gpt-5-mini`). Values: `low`, `medium`, `high`. |
| `OPENAI_API_VERSION` | `2025-04-01-preview` | Azure OpenAI API version. |

**Setup** — setting up multimodal orchestration assumes you have already completed the ingestion-side setup (Part 1 above) and have documents with figures indexed in Azure AI Search.

**1) Set the orchestration strategy to multimodal.**

```bash
az appconfig kv set --name <your-appconfig-name> \
  --key AGENT_STRATEGY --value multimodal --label gpt-rag --yes
```

**2) Ensure `CHAT_DEPLOYMENT_NAME` points to a vision-capable model.**

The orchestrator uses the same model for answering, intent classification, image classification, and image validation. It must support image input (e.g., `gpt-4o`, `gpt-4o-mini`).

```bash
az appconfig kv set --name <your-appconfig-name> \
  --key CHAT_DEPLOYMENT_NAME --value gpt-4o --label gpt-rag --yes
```

**3) Verify search index fields exist.**

The multimodal orchestrator expects these fields in the search index (created by the ingestion pipeline when `MULTIMODAL=true`):

- `contentVector` — text embedding vector
- `captionVector` — image-caption embedding vector
- `relatedImages` — array of blob URLs pointing to figure images
- `imageCaptions` — concatenated caption text for all figures in the chunk

If these fields are missing, re-run the ingestion pipeline with multimodal enabled.

**4) (Optional) Tune image filtering behavior.**

If the model is embedding too many irrelevant images, enable both classification and validation:

```bash
az appconfig kv set --name <your-appconfig-name> \
  --key MULTIMODAL_CLASSIFY_IMAGES --value true --label gpt-rag --yes

az appconfig kv set --name <your-appconfig-name> \
  --key MULTIMODAL_VALIDATE_RESPONSE_IMAGES --value true --label gpt-rag --yes
```

If latency is a concern and your documents contain mostly relevant figures, you can disable classification (`false`) and rely on the heuristic filter alone.

**5) Redeploy the orchestrator container app** to pick up the new configuration.

**Customizing the system prompt** — the multimodal strategy reads its system prompt from `src/prompts/multimodal/main.txt`. This prompt controls how the model handles citations, image embedding, language policy, and answer formatting. You can edit this file to adjust behavior — for example, changing citation style, adding domain-specific instructions, or modifying image embedding rules.

The prompt is loaded once and cached for the lifetime of the strategy instance. Redeploying the container app picks up changes.

**Troubleshooting**

**Images not appearing in answers**
Verify that the search index contains `relatedImages` and `captionVector` fields with data. Check that `AGENT_STRATEGY` is set to `multimodal` (not `maf_lite` or another strategy). Confirm that `CHAT_DEPLOYMENT_NAME` points to a vision-capable model.

**Too many irrelevant images in answers (cartoons, logos, decorative art)**
Enable both `MULTIMODAL_CLASSIFY_IMAGES` and `MULTIMODAL_VALIDATE_RESPONSE_IMAGES`. The classifier filters images before they reach the model; the validator catches any the model still chose to embed. You can also increase `MULTIMODAL_IMAGE_CLASSIFICATION_CONCURRENCY` to reduce the latency impact.

**High latency on image-heavy documents**
Image classification and validation add LLM calls per image. Reduce `MULTIMODAL_MAX_IMAGES` or `MULTIMODAL_MAX_IMAGES_PER_DOC` to limit the number of images processed. You can also disable `MULTIMODAL_CLASSIFY_IMAGES` if your documents are mostly technical (the heuristic filter may be sufficient).

**Model ignores images or lists filenames as plain text instead of embedding them**
This is a prompt-following issue. The system prompt in `src/prompts/multimodal/main.txt` contains detailed instructions for inline image embedding. If the model consistently ignores them, try a more capable model (e.g., switch from `gpt-4o-mini` to `gpt-4o`), or simplify the prompt instructions.

**User profile not persisting across sessions**
The profile is stored in the Cosmos DB conversations container. Check that the container exists and that the orchestrator's managed identity has read/write access. Look for `post_flow_cleanup failed` in the logs.

**Intent classifier always returns "question" (search runs on greetings)**
Check the logs for `intent_classification` entries. If the classifier is failing (timeout or error), it defaults to `question`. Ensure the model endpoint is reachable and the deployment supports low-token completions.
