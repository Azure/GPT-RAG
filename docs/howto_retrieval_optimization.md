# Optimize retrieval

Use this guide to measure and improve the documents GPT-RAG retrieves before
you tune prompts, models, or orchestration. It supports both retrieval backends:

| Backend | Role in this guide | What it queries |
| --- | --- | --- |
| `foundry_iq` | Primary, modern path | A Foundry IQ knowledge base |
| `ai_search` | Control and direct path | The GPT-RAG Azure AI Search index |

The backends do not return the same identifiers, candidate sets, or scores.
Measure each backend through its own adapter and qrels. Compare normalized
ranking and answer-quality metrics, never raw backend scores.

## Before you start

You need:

- a deployed GPT-RAG environment and access to its Azure App Configuration,
  Search, model, and Container Apps resources;
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows),
  [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd),
  Python 3.10 or later, and an authenticated `az login`;
- a fixed corpus snapshot and questions that require facts from that corpus;
- an evaluation environment. Do not run tuning sweeps against production.

Run all retrieval experiments with:

```text
AGENT_STRATEGY=single_agent_rag
```

`single_agent` and `maf_single_agent` are **not valid strategy values**. After
you select a retrieval configuration, you can separately compare
`maf_agent_service` and `maf_lite`. Mixing strategy and retrieval changes in
the same experiment makes the result impossible to attribute.

## 1. Freeze the experiment

Split questions before running a sweep:

- **tuning set**: use this to choose settings;
- **held-out set**: open it only after selecting a candidate.

Use JSON Lines so every question has a durable ID:

```powershell
New-Item -ItemType Directory -Force .\retrieval-lab | Out-Null

@'
{"id":"fuel-pressure","split":"tune","query":"How is fuel pressure maintained in the fuel delivery system?"}
{"id":"pressure-failure","split":"held_out","query":"What happens when fuel pressure is too low?"}
'@ | Set-Content .\retrieval-lab\questions.jsonl
```

The [fuel-system PDF](assets/vw-fuel-system.pdf) is available for a small
walkthrough. Ingest it before using the sample questions. Your generated chunk
identifiers will differ from any illustrative identifiers in this guide.

Keep these conditions fixed across runs:

- corpus and ingestion version;
- question file and split;
- user identity and document permissions;
- `AGENT_STRATEGY=single_agent_rag`;
- answer model, prompt, and temperature for downstream evaluation;
- the final document limit being compared;
- region and comparable load conditions.

## 2. Read the deployed configuration

Do not guess generated index, semantic configuration, or knowledge base names.
GPT-RAG loads App Configuration labels in this precedence order:

1. `orchestrator`
2. `gpt-rag-orchestrator`
3. `gpt-rag`
4. no label

The following PowerShell reads the active value and reports the label that
supplied it. Run it from the deployed GPT-RAG project after selecting the
correct `azd` environment.

```powershell
$env:APP_CONFIG_ENDPOINT = azd env get-value APP_CONFIG_ENDPOINT
if (-not $env:APP_CONFIG_ENDPOINT) {
    throw "APP_CONFIG_ENDPOINT is not set in the selected azd environment."
}

$script:AppConfigName = ([uri]$env:APP_CONFIG_ENDPOINT).Host.Split('.')[0]

function Get-ActiveSetting {
    param([Parameter(Mandatory)][string]$Key)

    foreach ($label in @('orchestrator', 'gpt-rag-orchestrator', 'gpt-rag', '\0')) {
        $json = az appconfig kv show `
            --name $script:AppConfigName `
            --key $Key `
            --label $label `
            --auth-mode login `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $json) {
            $item = $json | ConvertFrom-Json
            $displayLabel = if ($label -eq '\0') { '<no label>' } else { $label }
            return [pscustomobject]@{
                Key = $Key
                Value = [string]$item.value
                Label = $displayLabel
            }
        }
    }

    return [pscustomobject]@{ Key = $Key; Value = ''; Label = '<not set>' }
}

$keys = @(
    'AGENT_STRATEGY',
    'RETRIEVAL_BACKEND',
    'SEARCH_SERVICE_QUERY_ENDPOINT',
    'SEARCH_API_VERSION',
    'SEARCH_RAG_INDEX_NAME',
    'SEARCH_RAGINDEX_TOP_K',
    'SEARCH_APPROACH',
    'SEARCH_USE_SEMANTIC',
    'SEARCH_SEMANTIC_SEARCH_CONFIG',
    'AI_FOUNDRY_ACCOUNT_ENDPOINT',
    'EMBEDDING_DEPLOYMENT_NAME',
    'OPENAI_API_VERSION',
    'KNOWLEDGE_BASE_ENDPOINT',
    'KNOWLEDGE_BASE_NAME',
    'FOUNDRY_IQ_API_VERSION',
    'FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME',
    'FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND',
    'FOUNDRY_IQ_FILTER_ADD_ON_ENABLED',
    'FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS',
    'FOUNDRY_IQ_FORWARD_SOURCE_AUTH'
)

$active = $keys | ForEach-Object { Get-ActiveSetting $_ }
$active | Format-Table -AutoSize
$active | ConvertTo-Json | Set-Content .\retrieval-lab\deployed-settings.json

foreach ($setting in $active) {
    if ($setting.Value) {
        [Environment]::SetEnvironmentVariable($setting.Key, $setting.Value, 'Process')
    }
}
```

If `SEARCH_SEMANTIC_SEARCH_CONFIG` is not set, read the index's deployed
default instead of inventing a name:

```powershell
if (-not $env:SEARCH_SEMANTIC_SEARCH_CONFIG) {
    $searchToken = az account get-access-token `
        --resource https://search.azure.com `
        --query accessToken `
        --output tsv

    $headers = @{ Authorization = "Bearer $searchToken" }
    $indexUri = '{0}/indexes/{1}?api-version={2}' -f `
        $env:SEARCH_SERVICE_QUERY_ENDPOINT.TrimEnd('/'), `
        [uri]::EscapeDataString($env:SEARCH_RAG_INDEX_NAME), `
        $env:SEARCH_API_VERSION

    $indexDefinition = Invoke-RestMethod -Uri $indexUri -Headers $headers
    $env:SEARCH_SEMANTIC_SEARCH_CONFIG = $indexDefinition.semantic.defaultConfiguration
}
```

Confirm that `AGENT_STRATEGY` resolves to `single_agent_rag`. Record the
starting values and their labels. They are your baseline and rollback values.

!!! important "Configuration changes require a restart"
    The orchestrator loads these settings into an in-memory provider at startup,
    and its retrieval backend selector is also cached. GPT-RAG does not configure
    automatic App Configuration refresh. A key change does **not** affect the next
    request. Restart the active orchestrator revision after every promoted or
    rolled-back configuration change.

## 3. Install the lab helpers

Download these repository-maintained helpers into the same directory, or run
them from a checkout of this documentation:

- [`retrieve.py`](assets/retrieval_optimization/retrieve.py)
- [`pool_candidates.py`](assets/retrieval_optimization/pool_candidates.py)
- [`evaluate_retrieval.py`](assets/retrieval_optimization/evaluate_retrieval.py)

Download them and create an isolated environment on Windows:

```powershell
$tools = '.\retrieval-lab\tools'
New-Item -ItemType Directory -Force $tools | Out-Null
$rawBase = 'https://raw.githubusercontent.com/Azure/GPT-RAG/docs/docs/assets/retrieval_optimization'
foreach ($file in @('retrieve.py', 'pool_candidates.py', 'evaluate_retrieval.py')) {
    Invoke-WebRequest "$rawBase/$file" -OutFile "$tools\$file"
}

python -m venv .\retrieval-lab\.venv
.\retrieval-lab\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install azure-identity openai requests azure-ai-evaluation
```

For bash:

```bash
python3 -m venv ./retrieval-lab/.venv
source ./retrieval-lab/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install azure-identity openai requests azure-ai-evaluation
```

The retrieval helper uses the same service surfaces as GPT-RAG:

- `ai_search`: Azure OpenAI embeddings plus
  `POST /indexes/{index}/docs/search`;
- `foundry_iq`:
  `POST /knowledgebases/{knowledge-base}/retrieve`.

It writes raw responses and normalized documents. The Foundry IQ request uses
the configured primary documents knowledge source and asks the service to
include source data. It does not invent a Foundry IQ SDK or endpoint.
For a document-retrieval experiment, keep optional Work IQ, Fabric, web, MCP,
and other knowledge sources out of the run. The helper deliberately isolates
the primary documents source. If Pattern B document security enables
`FOUNDRY_IQ_FILTER_ADD_ON_ENABLED`, the helper stops instead of constructing an
unsafe filter. Run those permission-sensitive checks through the live
orchestrator, which builds the filter from the authenticated user context.
For direct Search, the helper uses the current lab identity for native
permission trimming and applies GPT-RAG's shared-corpus conversation filter.
It therefore excludes conversation-specific uploads. Test uploaded-file and
other request-specific security behavior through the live orchestrator.

## 4. Capture baselines

Use a new output directory for every run. The helper refuses to overwrite an
existing run.

```powershell
$runs = '.\retrieval-lab\runs'
New-Item -ItemType Directory -Force $runs | Out-Null

$foundryTopK = if ($env:FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS) {
    [int]$env:FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS
} else {
    5
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$foundryBaseline = "$runs\$stamp-foundry-iq-baseline"
python "$tools\retrieve.py" `
    --backend foundry_iq `
    --questions .\retrieval-lab\questions.jsonl `
    --split tune `
    --top-k $foundryTopK `
    --out $foundryBaseline

$searchApproach = if ($env:SEARCH_APPROACH) { $env:SEARCH_APPROACH } else { 'hybrid' }
$searchTopK = if ($env:SEARCH_RAGINDEX_TOP_K) {
    [int]$env:SEARCH_RAGINDEX_TOP_K
} else {
    5
}
$searchArgs = @(
    "$tools\retrieve.py",
    '--backend', 'ai_search',
    '--questions', '.\retrieval-lab\questions.jsonl',
    '--split', 'tune',
    '--approach', $searchApproach,
    '--top-k', $searchTopK
)
$searchArgs += if ($env:SEARCH_USE_SEMANTIC -eq 'true') {
    '--semantic'
} else {
    '--no-semantic'
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$searchBaseline = "$runs\$stamp-ai-search-baseline"
$searchArgs += @('--out', $searchBaseline)
python @searchArgs
```

The example records `5` when a deployed document limit is missing instead of
silently relying on a service default. Choose a different explicit value if it
better represents your current environment.

Each run contains:

```text
runs/<timestamp>-<backend>-<variant>/
|-- config.json
|-- environment.json
|-- questions.jsonl
|-- raw/
|   |-- <question-id>.json
|-- retrieved.json
`-- timings.json
```

Add qrels version and hash, metrics, answer-evaluation output, and cost
observations to the run directory before archiving it. Treat a completed run
as immutable. Also record the GPT-RAG manifest versions and the running
Container App image digests so a later session can reproduce the service state.
The evaluation helper writes the retrieved-data and qrels SHA-256 hashes into
`metrics.json`.

!!! warning "Protect experiment artifacts"
    Raw responses and normalized documents can contain customer content,
    security metadata, and source locations. Store runs in an access-controlled
    location and apply the same retention rules as the source corpus.

## 5. Build backend-specific qrels

Qrels are relevance judgments for a specific question and retrieved document.
Use one rubric for both backends:

| Label | Meaning |
| --- | --- |
| `4` | Directly and fully answers the question |
| `3` | Strongly relevant |
| `2` | Partially relevant |
| `1` | Weakly related |
| `0` | Not relevant |

Before labeling, run every configuration you plan to test on the tuning set.
Pool and de-duplicate their candidates **within each backend**:

```powershell
New-Item -ItemType Directory -Force .\retrieval-lab\qrels\foundry_iq | Out-Null
New-Item -ItemType Directory -Force .\retrieval-lab\qrels\ai_search | Out-Null

python "$tools\pool_candidates.py" `
    --retrieved .\retrieval-lab\runs\*-foundry-*\retrieved.json `
    --output .\retrieval-lab\qrels\foundry_iq\candidate-pool.json

python "$tools\pool_candidates.py" `
    --retrieved .\retrieval-lab\runs\*-ai-search-*\retrieved.json `
    --output .\retrieval-lab\qrels\ai_search\candidate-pool.json
```

Label every pooled candidate, including irrelevant ones, and save the results
as `qrels/<backend>/v1.json`:

```json
{
  "fuel-pressure": [
    {
      "document_id": "<exact identifier emitted by that backend adapter>",
      "query_relevance_label": 4
    }
  ]
}
```

The example is a schema illustration, not a measured judgment.

### Why the identifiers and scores differ

- Direct Azure AI Search uses the index key (`id`) as `document_id`. Its
  `relevance_score` is the semantic reranker score when present, otherwise the
  Search score.
- A Foundry IQ `references[].id` is a response-scoped citation identifier. It
  is not durable and the adapter never uses it for qrels.
- For a `searchIndex` knowledge source, the adapter prefers
  `references[].docKey`. For document sources such as `azureBlob`, it combines
  stable source metadata with a content fingerprint. Save the adapter version
  and raw response with the run.
- Foundry IQ's retrieve response does not expose a Search reranker score that
  can be compared with `@search.score` or `@search.rerankerScore`. The adapter
  emits a strictly descending, rank-derived value only so the Document
  Retrieval evaluator can preserve returned order. It is not a service
  confidence score.

If a Foundry IQ source returns neither a durable key nor stable source
metadata, define and version an identity mapping before creating persistent
qrels. Do not fall back to `references[].id`.

## 6. Score retrieval

Run the Microsoft Foundry
[Document Retrieval evaluator](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/rag-evaluators#document-retrieval)
once per backend:

```powershell
python "$tools\evaluate_retrieval.py" `
    --retrieved "$foundryBaseline\retrieved.json" `
    --qrels .\retrieval-lab\qrels\foundry_iq\v1.json `
    --timings "$foundryBaseline\timings.json" `
    --output "$foundryBaseline\metrics.json"

python "$tools\evaluate_retrieval.py" `
    --retrieved "$searchBaseline\retrieved.json" `
    --qrels .\retrieval-lab\qrels\ai_search\v1.json `
    --timings "$searchBaseline\timings.json" `
    --output "$searchBaseline\metrics.json"
```

Track at least:

| Area | Metrics | Direction |
| --- | --- | --- |
| Ranking | `ndcg@3`, `xdcg@3`, `fidelity`, top relevance | Higher |
| Qrels coverage | `holes`, `holes_ratio` | Lower |
| Client latency | p50 and p95 | Lower, within your SLO |
| Answer quality | Retrieval and Groundedness LLM-judge scores | Higher |
| Cost | model tokens, billed operations, and estimated cost per question | Lower, within budget |

The helper calculates retrieval metrics and client-side latency. Run the
selected configuration through the live orchestrator to collect answer,
token, and service-cost data. Use
[AgentOps](https://azure.github.io/agentops/tutorial-http-agent/) or your
existing Microsoft Foundry evaluation pipeline for Retrieval and Groundedness.
Archive that output with the same run ID.

## 7. Sweep one variable at a time

Start from each backend's deployed baseline. Change one lever, run the same
tuning questions, and restore the baseline before changing a different lever.

| Backend | First sweeps | GPT-RAG setting |
| --- | --- | --- |
| `foundry_iq` | final document count, for example 3, 5, 8 | `FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS` |
| `ai_search` | `term`, `vector`, `hybrid` | `SEARCH_APPROACH` |
| `ai_search` | semantic reranker off/on for term or hybrid | `SEARCH_USE_SEMANTIC` |
| `ai_search` | final document count, for example 3, 5, 8 | `SEARCH_RAGINDEX_TOP_K` |
| Either | chunk size and overlap, last | ingestion settings; requires re-ingestion |

Example direct-search sweep:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
python "$tools\retrieve.py" `
    --backend ai_search `
    --questions .\retrieval-lab\questions.jsonl `
    --split tune `
    --approach hybrid `
    --top-k 5 `
    --no-semantic `
    --out "$runs\$stamp-ai-search-hybrid-k5-no-semantic"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
python "$tools\retrieve.py" `
    --backend ai_search `
    --questions .\retrieval-lab\questions.jsonl `
    --split tune `
    --approach hybrid `
    --top-k 5 `
    --semantic `
    --out "$runs\$stamp-ai-search-hybrid-k5-semantic"
```

Only the semantic-ranker switch changes between these runs. Do not enable it
for vector-only search.

Foundry IQ plans and executes retrieval differently from direct Search. Even
when both use the same underlying corpus, they can return different chunks and
ordering. A fair backend comparison keeps the conditions from Step 1 fixed,
uses the same relevance rubric, completes each backend's candidate pool, and
compares normalized metrics and downstream answers. Raw scores are not a
cross-backend metric.

## 8. Select on held-out questions

Write promotion criteria before opening the held-out results. For example:

- mean held-out `ndcg@3` improves by at least the chosen margin;
- no material `xdcg@3`, fidelity, Retrieval, or Groundedness regression;
- `holes_ratio` stays below the qrels-coverage threshold;
- p95 latency stays within the service-level objective;
- estimated cost per question stays within budget;
- every permission-sensitive question returns only authorized content.

Choose thresholds that match your application. Values such as a `0.03`
minimum NDCG gain, a `0.02` maximum metric regression, or a `15%` p95 latency
increase are **illustrative policy examples**, not GPT-RAG measured results or
product defaults.

Do not select on one impressive question. Promote only after the held-out
aggregate and critical slices pass.

After selecting one candidate per backend, rerun only the baseline and selected
candidate with `--split held_out`. Pool those held-out candidates, label them
without looking at system names or scores, and run the same evaluator. Do not
reuse tuning-set averages as held-out evidence.

## 9. Promote, restart, and validate

Write the winner to the same active App Configuration label you identified in
Step 2. In most deployments this is `gpt-rag`; a higher-precedence
service-specific override must be changed or removed instead.

```powershell
$targetLabel = 'gpt-rag'

az appconfig kv set `
    --name $script:AppConfigName `
    --key RETRIEVAL_BACKEND `
    --value foundry_iq `
    --label $targetLabel `
    --auth-mode login `
    --yes

az appconfig kv set `
    --name $script:AppConfigName `
    --key AGENT_STRATEGY `
    --value single_agent_rag `
    --label $targetLabel `
    --auth-mode login `
    --yes
```

Set only the additional winning keys. Then restart the active orchestrator
revision:

```powershell
$env:RESOURCE_GROUP = azd env get-value AZURE_RESOURCE_GROUP
$env:ORCHESTRATOR_APP = azd env get-value ORCHESTRATOR_APP_NAME

$revision = az containerapp revision list `
    --name $env:ORCHESTRATOR_APP `
    --resource-group $env:RESOURCE_GROUP `
    --query "[?properties.active].name | [0]" `
    --output tsv

if (-not $revision) {
    throw "No active orchestrator revision was found."
}

az containerapp revision restart `
    --name $env:ORCHESTRATOR_APP `
    --resource-group $env:RESOURCE_GROUP `
    --revision $revision
```

Validate after restart:

1. confirm the orchestrator is healthy and logs the expected backend;
2. run known-answer, no-answer, and permission-sensitive questions;
3. rerun the held-out retrieval metrics through the production path;
4. rerun Retrieval and Groundedness answer evaluation;
5. compare p50/p95 latency and cost with the archived baseline.

## 10. Roll back

Keep `deployed-settings.json` and the active labels from Step 2. If validation
fails, restore every changed key to its previous value, restart the active
revision again, and rerun the smoke questions. You do not need to delete the
Foundry IQ knowledge base to roll back to `ai_search`.

## After re-ingestion

Chunking, parsing, embedding, or corpus changes can alter both candidate
content and identifiers. After re-ingestion:

1. freeze the new corpus and ingestion version;
2. rerun every planned configuration;
3. rebuild each backend's candidate pool;
4. re-author or re-verify qrels;
5. capture a new baseline before comparing settings.

Do not compare a new-corpus run with stale qrels from the previous ingestion.

## Illustrative walkthrough

Suppose the tuning question is "How is fuel pressure maintained in the fuel
delivery system?" and your pooled qrels assign labels 4, 2, and 0 to three
returned chunks.

| Variant | Mean `ndcg@3` | Mean `holes_ratio` | p95 latency |
| --- | ---: | ---: | ---: |
| Baseline | 0.63 | 0.00 | 780 ms |
| One-variable candidate | 0.74 | 0.00 | 840 ms |

These values are **illustrative only**. They show how to make a decision:
ranking improved, qrels coverage did not worsen, and latency stayed within a
hypothetical SLO. They are not results measured by the GPT-RAG team. Your run
artifacts are the evidence for your environment.

## Related

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Direct Azure AI Search](howto_grounding_ai_search_direct.md)
- [Ingestion](services_ingestion.md)
- [Orchestrator](services_orchestrator.md)
- [Foundry IQ retrieve action](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve)
- [Hybrid search](https://learn.microsoft.com/azure/search/hybrid-search-overview)
- [Semantic ranking](https://learn.microsoft.com/azure/search/semantic-search-overview)
- [Azure Container Apps revision restart](https://learn.microsoft.com/cli/azure/containerapp/revision)
