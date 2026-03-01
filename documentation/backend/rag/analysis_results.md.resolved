# RAG Engine Context Flow & Chat History Analysis

Based on a thorough review of the backend services and routes, here are the answers to your questions regarding the RAG engine and message context flow.

## 1. Message Context Flow

When a user sends a message through the `/chat` endpoint ([app/api/routers/rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py)):
1. **Persistence:** The user's query is immediately saved to the [ChatMessage](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#42-52) table in Postgres via the [_save_message](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#46-69) helper.
2. **Context Retrieval:** `rag_engine.async_retrieve_context` receives the query. It performs a **Hybrid Search**:
    - Queries the [BrainEmbedding](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#58-66) table via pgvector (Dense Search).
    - Queries a local [BM25Store](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py#54-120) cache (Sparse Search).
    - Merges the two using Reciprocal Rank Fusion (RRF).
    - Re-ranks the top 15 candidates down to the top 5 using a Cross-Encoder (`ms-marco-MiniLM-L-6-v2`).
3. **Context Enrichment:** The engine then adds "Associative Memories" (based on themes like "anxiety" or "ambition") and "Location Patterns" to the context text.
4. **Prompt Assembly:** The assembled context string and the user query are passed to [gemini_service.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/gemini_service.py), which determines dynamic variables like [temporal_context](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py#178-199), `emotional_state`, and `tone_layer` based on time of day and sentiment.
5. **Streaming:** The `gemini-3-flash-preview` model streams its response via Server-Sent Events (SSE).
6. **Final Persistence:** The final AI response—along with cited sources—is saved back to the [ChatMessage](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#42-52) table.

## 2. Chat History Query & Retrieval per Turn (Surprising Finding)

**The Postgres Schema:**
The [ChatMessage](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#42-52) model in [app/models/models.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py) contains:
- `user_id`, [content](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py#109-112), `sender` ('user' or 'ai'), `timestamp`, and `context_sources`.

**The Retrieval per Turn:**
Surprisingly, **0 previous messages** are retrieved and sent to the LLM per turn. 
While [app/api/routers/rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py) has a `/history` endpoint to fetch messages **for the UI**, the actual [chat_endpoint](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#210-317) and `gemini_service.async_stream` do **not** fetch or pass any conversation thread context to the AI. Every request is treated as highly independent. The engine solely relies on the chunks it fetches from [BrainEmbedding](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#58-66) as its "memory".

## 3. Prompt Template / Context Assembly

**Context Assembly ([app/services/rag_engine.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py) around line 800):**
The retrieved text blocks, associative memories, and location notes are concatenated into a single string (`context_text`). 

**Prompt Formatting ([app/services/gemini_service.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/gemini_service.py) under [_build_prompt](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/gemini_service.py#139-155) and [_build_system_instruction](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/gemini_service.py#156-172)):**
The variables are assembled safely to prevent injection using XML tag delimiters. The final LLM input looks like this:
```xml
<user_context>
[Retrieved chunks, associations, and location data]
</user_context>

<user_question>
[User's raw query]
</user_question>

DIRECT ANSWER (Max 3 sentences):
```
The system instructions (rules about being a "subconscious", temporal awareness, tone) are passed separately to the model configuration ([system_instruction](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/gemini_service.py#156-172)).

## 4. Token Limit Allocation (Gemini 3 Flash Preview)

The engine handles token constraints dynamically using the `max_output_tokens` param ([app/services/rag_engine.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py) line 549). While Gemini 1.5/3 Flash has a massive input context window (up to 1M-2M tokens), output generation restricts the response:
- **Chat History:** 0 tokens (since it is not included in the prompt).
- **System Instructions:** ~300-400 tokens (system instructions + dynamically formatted tone data).
- **Retrieved Chunks:** The rest of the input tokens. Typically, 5 chunks of ~500 chars, plus 2 associative chunks, amount to roughly 1,000–2,000 tokens of input text.
- **Output Token Limits:** Allocated dynamically based on query length/complexity: 1024 (short queries), 2048 (medium), or 4096 (deep analysis).

## 5. Sliding Window for Chat of 100 Messages

**For the AI Thread Context:**
There is no sliding window sent to the AI because the thread is completely isolated per turn.

**For the UI History Fetching:**
If a chat grows long, the backend caps how many messages the frontend can fetch at once using a strict limit.
- **File:** [backend/app/api/routers/rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py)
- **Line:** `341: limit = min(limit, 100)`
This line defines a hard cap where the API will never return more than 100 messages to the UI in a single `/history` query, regardless of what the client requests. Pagination must be used to view older messages.
