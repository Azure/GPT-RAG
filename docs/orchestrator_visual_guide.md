# Orchestrator: Start Your Code Reading with Visuals

*A picture is worth a thousand words.*  
Yet many engineers write another thousand words instead of drawing a single useful diagram.  
Let’s reverse this evolution — with visuals.

Starting with diagrams — with a bit of simplification and abstraction — can significantly accelerate the comprehension of complex codebases. This is especially true when the data flow spans multiple execution environments (container app, AI Foundry, Azure cloud resources), where the initial orientation can otherwise be challenging.

## Why This Article Exists

When I started reading the code, I struggled:

- Where is the entry point?
- What calls what?
- What is the role of the Orchestrator in the data flow?

If you have ever felt **dazed and confused by a codebase with many layers of abstraction**, this is for you.

If you prefer talking for hours about a diagram instead of drawing it, just leave.

## Core Architecture & Flow

The orchestrator's entry point is in src/main.py: `orchestrator_endpoint()`.
In what follows we will consider the Single-Agent RAG Strategy.
```
@app.post(
    "/orchestrator",
    dependencies=[Depends(validate_auth)], 
    summary="Ask orchestrator a question",
    response_description="Returns the orchestrator’s response in real time, streamed via SSE.",
    responses=ORCHESTRATOR_RESPONSES
)
async def orchestrator_endpoint(
    body: OrchestratorRequest,
    x_api_key: Optional[str] = Header(None, alias="X-API-KEY"),
    dapr_api_token: Optional[str] = Header(None, alias="dapr-api-token"),
):
```

## Essential Tasks of the Orchestrator

The `Orchestrator` class serves as the **conversation state manager** and **strategy coordinator**. Its core responsibilities are:

1. **Conversation Lifecycle Management**: Creates, loads, and persists conversation documents in the CosmosDB.
2. **Strategy Delegation**: Routes processing to appropriate agent strategies via factory pattern (`AgentStrategyFactory`).
3. **State Coordination**: Ensures conversation state is properly synchronized between database and strategy
4. **Response Streaming**: Coordinates real-time response delivery while maintaining state consistency

## Single Agent Strategy

This section explores how the Single-Agent RAG Strategy orchestrates the entire request-response lifecycle, from receiving a user's question to delivering a grounded, streamed answer. The diagrams below illustrate the conversation lifecycle, state management, and the interaction between the Orchestrator container app and AI Foundry services.

[🟦 SVG](./media/orchestrator_strategy/orchestrator-strategy.drawio.svg) ·
[🟨 PNG](./media/orchestrator_strategy/orchestrator-strategy.drawio.png) ·
[🟥 JPG](./media/orchestrator_strategy/orchestrator-strategy.jpg)

![Orchestrator Strategy Setup and Streaming](./media/orchestrator_strategy/orchestrator-strategy.drawio.svg)

You will have noticed the use of the Factory Design Pattern (`AgentStrategyFactory`) for the various Strategies, ensuring that all of them comply with the same `BaseAgentStrategy` interface.
For the sake of clarity, I have abstracted away the different roles of the `Orchestrator` class and the `Orchestrator` object.

<div class="no-wrap">
```
------------------------------------------------------------------
┌────────────────────────────────────────────────────────────────┐
│                         Orchestrator                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  - conversation_id: str                                  │  │
│  │  - database_client: CosmosDBClient     <<reference>>     │  │
│  │  - agentic_strategy: BaseAgentStrategy ───────────────┐  │  │
│  │                                                       │  │  │
│  │  + create()                                           │  │  │
│  │  + stream_response()                                  │  │  │
│  │  + save_feedback()                                    │  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────┬──────────────────────────────────────────┘
                      │                                    │
                      │ uses (delegation)                  │ 
                      ▼                                    │
           ┌──────────────────────┐                        │  
           │ AgentStrategyFactory │ <<factory>>            │
           ├──────────────────────┤                        │
           │ + get_strategy(key)  │                        │
           └──────────┬───────────┘                        │
                      │                                    │
                      │ instantiates                       │
                      ▼                                    │
        ┌─────────────────────────────┐                    │
        │    BaseAgentStrategy        │ <<abstract>> ◄─────┘
        ├─────────────────────────────┤
        │ # strategy_type             │
        │ # conversation: Dict        │
        │ # user_context: Dict        │
        │ # credential                │
        │ # project_client            │
        ├─────────────────────────────┤
        │ + initiate_agent_flow()*    │ * = abstract method
        │ # _read_prompt()            │
        └──────────────┬──────────────┘
                       │
                       │ inheritance (IS-A)
         ┌─────────────┼─────────────────────────┐
         │             │                         │
         ▼             ▼                         ▼
┌────────────────┐ ┌──────────────┐  ┌─────────────────┐
│ SingleAgent    │ │  NL2SQL      │  │  McpStrategy    │
│ RAGStrategy    │ │  Strategy    │  │                 │
├────────────────┤ ├──────────────┤  ├─────────────────┤
│ - tools_list   │ │ - nl2sql     │  │ - kernel        │
│ - ai_search    │ │   _plugin    │  │ - agent         │
│ - event_handler│ │ - terminator │  │                 │
├────────────────┤ ├──────────────┤  ├─────────────────┤
│ + initiate_    │ │ + initiate_  │  │ + initiate_     │
│   agent_flow() │ │   agent_flow │  │   agent_flow()  │
└────────────────┘ └──────────────┘  └─────────────────┘
------------------------------------------------------------------
```
</div>

The entry point for the selected Strategy is the method `agentic_strategy.initiate_agent_flow()`.

The strategy object instantiated from the `SingleAgentRAGStrategy` class runs in the container app and controls the sequence of activities behind the AI Foundry wall. It uses the `project_client` object as a local proxy (think of it as a remote TV control) to orchestrate operations. The strategy object doesn't handle grounding or LLM calls directly—these are delegated to the AI Foundry agent where the entire RAG pattern is executed.

The strategy object `SingleAgentRAGStrategy`

- creates a new agent by specifying instructions and a toolbox,

- retrieves the `Thread` object based on the thread_id which was retrieved from the CosmosDB,

- creates a new message from the user's Ask and attaches it to the Thread object,

- finally calls the project_client.agents.runs.stream() which triggers the RAG pipeline inside of the AI Foundry realm.

Note that `Thread` objects keep the entire **history of conversations**. There are two levels of history persistence: one in CosmosDB and another in Thread objects.

`Orchestrator` keeps a history (using CosmosDB) identified by `conversation_id` which arrives in the HTTP Request payload.
One of the attributes stored in the CosmosDB is `thread_id` which points to the `Thread` object which resides inside of the AI Foundry.
AI Foundry maintains its own internal persistency in the Thread objects.

The strategy object triggers the RAG pipeline execution inside of AI Foundry with the proxy `project_client`:
```
project_client.agents.runs.stream(
    thread_id=thread.id,
    agent_id=agent.id,
    ...
)
```
Here is what it does:

- Takes the user's Ask.

- Queries your Azure AI Search index using the `AzureAISearchTool`.

- Retrieves relevant document Chunks.

- Creates the Prompt.

- Previously retrieved Chunks are included into the Prompt to ground the Response.

- Prompt is fed into LLM which generates Response.

- The Response is enhanced by citations and references to the grounding documents.

### Single Agent Strategy Internal Flow

<!-- Offer alternative formats as small inline links/icons above or below -->
[🟦 SVG](./media/orchestrator_single_agent_strategy/orchestrator-single-agent-strategy.drawio.svg) ·
[🟨 PNG](./media/orchestrator_single_agent_strategy/orchestrator-single-agent-strategy.drawio.png) ·
[🟥 JPG](./media/orchestrator_single_agent_strategy/orchestrator-single-agent-strategy.jpg)

![Single Agent RAG Strategy Internal Flow](./media/orchestrator_single_agent_strategy/orchestrator-single-agent-strategy.drawio.png)

The sequence diagram above is intended to illustrate the core concepts and design patterns present in the codebase.
The visualization deliberately simplifies reality through abstraction and by omitting less relevant details.

## Links to the code

| Concept | File | Notes |
|---|---|---|
| Orchestrator entry | [`main.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/main/src/main.py) | FastAPI route + request handling |
| Orchestrator implementation | [`orchestration/orchestrator.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/main/src/orchestration/orchestrator.py) | Maintains Conversation History + runs streaming pipeline |
| Strategy factory | [`strategies/agent_strategy_factory.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/main/src/strategies/agent_strategy_factory.py) | Selects the execution strategy |
| Single-Agent RAG Strategy | [`strategies/single_agent_rag_strategy.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/main/src/strategies/single_agent_rag_strategy.py) | Implements flow to Azure AI Foundry |
