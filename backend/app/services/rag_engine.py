import os
import asyncio
import time
import concurrent.futures
from langchain_text_splitters import (
    RecursiveCharacterTextSplitter,
    MarkdownHeaderTextSplitter,
    Language,
)
from google import genai
from google.generativeai import types
from dotenv import load_dotenv
from sentence_transformers import CrossEncoder, SentenceTransformer
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy import and_
from app.models.models import BrainEmbedding
from app.core.database import SessionLocal
import json
import numpy as np
from datetime import datetime
from textblob import TextBlob
from app.schemas import (
    schemas,
)  # Import schemas for LocationContext type hinting if needed (or just use dict)
from app.services.gemini_service import gemini_service

# Load environment variables
load_dotenv()

# --- EXECUTOR FOR NON-BLOCKING I/O ---
_executor = concurrent.futures.ThreadPoolExecutor(max_workers=16)

# --- CONFIG ---
# 1. SETUP PATHS
BASE_DIR = os.path.dirname(os.path.abspath(__file__))  # Gets 'backend' folder

# 2. LOAD SENSITIVE KEYS
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# 3. RE-RANKING CONFIG
RERANKING_ENABLED = True  # Toggle re-ranking on/off
N_FINAL_RESULTS = 5  # Changed from 3
N_CANDIDATES = 15  # Changed from 10
CROSS_ENCODER_MODEL = (
    "cross-encoder/ms-marco-MiniLM-L-6-v2"  # Best accuracy/speed trade-off
)

import threading
from cachetools import LRUCache
from rank_bm25 import BM25Okapi
import string


class BM25Store:
    """Thread-safe, LRU-capped, per-user BM25 index store."""

    def __init__(self, max_users: int = 100):
        self._lock = threading.RLock()
        self._cache = LRUCache(maxsize=max_users)
        self._doc_registry = {}
        self._doc_content = {}
        self._doc_metadata = {}

    def _tokenize(self, text: str):
        return text.lower().translate(str.maketrans("", "", string.punctuation)).split()

    def invalidate(self, user_id: int):
        with self._lock:
            self._cache.pop(user_id, None)
            self._doc_registry.pop(user_id, None)
            self._doc_content.pop(user_id, None)
            self._doc_metadata.pop(user_id, None)
            print(f"[INFO] Invalidated BM25 cache for user {user_id}")

    def get_or_build(self, user_id: int, db: Session):
        with self._lock:
            if user_id not in self._cache:
                print(f"[INFO] Building BM25 index for user {user_id}...")
                user_docs = (
                    db.query(BrainEmbedding)
                    .filter(BrainEmbedding.user_id == user_id)
                    .all()
                )

                tokenized_corpus = []
                self._doc_registry[user_id] = {}
                self._doc_content[user_id] = {}
                self._doc_metadata[user_id] = {}

                if user_docs:
                    for idx, doc in enumerate(user_docs):
                        self._doc_registry[user_id][idx] = doc.id
                        self._doc_content[user_id][doc.id] = doc.document
                        self._doc_metadata[user_id][doc.id] = doc.metadata_
                        tokenized_corpus.append(self._tokenize(doc.document))

                    self._cache[user_id] = BM25Okapi(tokenized_corpus)
                    print(
                        f"[INFO] BM25 index built for user {user_id} with {len(tokenized_corpus)} documents"
                    )
                else:
                    print(
                        f"[WARN] No documents for user {user_id}, skipping BM25 build"
                    )
                    self._cache[user_id] = None

            return self._cache.get(user_id)

    def get_content_map(self, user_id: int):
        with self._lock:
            return self._doc_content.get(user_id, {})

    def get_metadata_map(self, user_id: int):
        with self._lock:
            return self._doc_metadata.get(user_id, {})

    def get_registry_map(self, user_id: int):
        with self._lock:
            return self._doc_registry.get(user_id, {})


class RAGService:
    """Singleton service that owns all RAG state and model lifecycles."""

    _instance = None
    _init_lock = threading.Lock()

    def __new__(cls):
        with cls._init_lock:
            if cls._instance is None:
                cls._instance = super(RAGService, cls).__new__(cls)
                cls._instance._emb_model = None
                cls._instance._cross_encoder = None
                cls._instance.bm25_store = BM25Store()
        return cls._instance

    def initialize(self):
        print("[INFO] Pre-loading RAG models...")
        os.environ["TOKENIZERS_PARALLELISM"] = "false"
        self.get_cross_encoder()
        self.get_emb_fn()
        gemini_service.initialize()
        print("[INFO] RAG models ready.")

    def get_emb_fn(self):
        if self._emb_model is None:
            print(f"[INFO] Loading BGE embedding model...")
            self._emb_model = SentenceTransformer("BAAI/bge-base-en-v1.5")
            print(f"[INFO] BGE embedding model loaded successfully")
        return self._emb_model

    def get_cross_encoder(self):
        if self._cross_encoder is None:
            print(f"[INFO] Loading cross-encoder model: {CROSS_ENCODER_MODEL}")
            self._cross_encoder = CrossEncoder(CROSS_ENCODER_MODEL)
            print(f"[INFO] Cross-encoder loaded successfully")
        return self._cross_encoder


_rag_service = RAGService()


def get_emb_fn():
    return _rag_service.get_emb_fn()


def get_cross_encoder():
    return _rag_service.get_cross_encoder()


def initialize_models():
    _rag_service.initialize()


# --- CORE FUNCTIONS ---


def get_temporal_context(user_id: int):
    """Generate temporal awareness for subconscious feel"""
    now = datetime.now()

    # Build temporal context
    temporal_hints = []

    # Time of day awareness
    hour = now.hour
    if 5 <= hour < 12:
        temporal_hints.append("Morning thoughts hit different.")
    elif 22 <= hour or hour < 5:
        temporal_hints.append("Late night - when the real thoughts come.")

    # Day of week
    if now.weekday() == 6:  # Sunday
        temporal_hints.append("Sunday. Planning mode.")
    elif now.weekday() == 0:  # Monday
        temporal_hints.append("Monday energy.")

    return "\n".join(temporal_hints)


def analyze_emotional_tone(context: str):
    """Detect emotional patterns in retrieved memories"""
    blob = TextBlob(context)
    polarity = blob.sentiment.polarity  # -1 (negative) to 1 (positive)
    # que : what is polarity ? Polarity is a measure of the emotional tone of a text. It ranges from -1 (negative) to 1 (positive).
    if polarity < -0.3:
        return "reflective_concerned"  # User is processing something heavy
    elif polarity > 0.3:
        return "energized_optimistic"  # User is in growth mode
    else:
        return "contemplative_neutral"


def get_tone_guidance(emotional_state: str):
    """Adjust response style based on emotional context"""
    tones = {
        "reflective_concerned": "Be gentle. Acknowledge the weight. Don't rush to solutions.",
        "energized_optimistic": "Match the energy. Build momentum. Push forward.",
        "contemplative_neutral": "Be balanced. Offer perspective without judgment.",
    }
    return tones.get(emotional_state, "Be authentic and direct.")


def find_associative_memories(
    query: str, user_id: int, primary_context: str, db: Session
):
    """Find memories that aren't directly related but resonate thematically"""
    # Extract key themes from query
    query_lower = query.lower()

    # Theme detection
    themes = []
    if any(word in query_lower for word in ["goal", "ambition", "career", "success"]):
        themes.append("ambition")
    if any(word in query_lower for word in ["fear", "worry", "anxiety", "stress"]):
        themes.append("anxiety")
    if any(word in query_lower for word in ["health", "fitness", "body", "workout"]):
        themes.append("health")
    if any(
        word in query_lower
        for word in ["relationship", "people", "social", "connection"]
    ):
        themes.append("relationships")

    if not themes:
        return []

    # Search for cross-theme connections
    associative_results = []
    emb_model = get_emb_fn()

    for theme in themes:
        # Find documents tagged with this theme
        theme_query = f"{theme} thoughts feelings notes"
        query_embedding = emb_model.encode([theme_query]).tolist()[0]

        try:
            results = (
                db.query(BrainEmbedding)
                .filter(BrainEmbedding.user_id == user_id)
                .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))
                .limit(2)
                .all()
            )

            if results:
                for r in results:
                    associative_results.append(r.document)
        except Exception as e:
            print(e)

    # Deduplicate and filter out what's already in primary context
    unique_associations = []
    for doc in associative_results:
        if doc not in primary_context and doc not in unique_associations:
            unique_associations.append(doc)

    return unique_associations[:2]  # Max 2 associative memories


# --- CORE FUNCTIONS ---


def index_text(
    filename: str, text: str, user_id: int, db: Session, location_context: dict = None
):
    """Memorizes a file (Chunks -> Vectors) for a specific user"""

    chunks = []

    # 2. CHUNK TEXT based on file extension
    if filename.lower().endswith(".md"):
        # [Strategy] Semantic Chunking for Markdown
        # 1. Split by headers first to keep sections together
        print(f"[INDEX] Using Semantic Markdown Splitter for {filename}")

        headers_to_split_on = [
            ("#", "Header 1"),
            ("##", "Header 2"),
            ("###", "Header 3"),
        ]

        markdown_splitter = MarkdownHeaderTextSplitter(
            headers_to_split_on=headers_to_split_on
        )
        md_header_splits = markdown_splitter.split_text(text)

        # 2. Recursively split large sections from the header splits
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)

        # Process each header split
        for split in md_header_splits:
            # Combine header metadata into content for better retrieval context
            header_context = ""
            if "Header 1" in split.metadata:
                header_context += f"{split.metadata['Header 1']} > "
            if "Header 2" in split.metadata:
                header_context += f"{split.metadata['Header 2']} > "
            if "Header 3" in split.metadata:
                header_context += f"{split.metadata['Header 3']}: "

            # Update content to include context
            full_content = f"{header_context}{split.page_content}"

            # Split if still too large
            if len(full_content) > 500:
                sub_chunks = text_splitter.split_text(full_content)
                chunks.extend(sub_chunks)
            else:
                chunks.append(full_content)

    else:
        # Fallback for plain text
        print(f"[INDEX] Using Recursive Splitter for {filename}")
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=500, chunk_overlap=50, separators=["\n\n", "\n", ".", " "]
        )
        chunks = splitter.split_text(text)

    if not chunks:
        print(f"[WARN] No chunks created for {filename}")
        return 0

    # Create unique IDs (filename + chunk index + user_id)
    ids = [f"{user_id}_{filename}_{i}" for i in range(len(chunks))]

    # Metadata includes file type info AND Location info if available
    metadatas = []
    for _ in chunks:
        meta = {
            "source": filename,
            "user_id": user_id,
            "type": "markdown" if filename.lower().endswith(".md") else "text",
            "timestamp": datetime.now().isoformat(),
        }

        # Add location context if provided
        if location_context:
            # Flatten location dict into metadata (Chroma prefers flat structures)
            if location_context.get("city"):
                meta["city"] = location_context["city"]
            if location_context.get("location_type"):
                meta["location_type"] = location_context["location_type"]
            # Coordinates might be useful later, store as string or float depending on chroma handling
            # Storing as float is fine
            if location_context.get("latitude"):
                meta["latitude"] = location_context["latitude"]
            if location_context.get("longitude"):
                meta["longitude"] = location_context["longitude"]

        metadatas.append(meta)

    print(
        f"DEBUG: Attempting to add {len(chunks)} chunks to Postgres for user {user_id}"
    )
    emb_model = get_emb_fn()

    rows = []
    BATCH_SIZE = 32
    for i in range(0, len(chunks), BATCH_SIZE):
        batch_chunks = chunks[i : i + BATCH_SIZE]
        batch_ids = ids[i : i + BATCH_SIZE]
        batch_metadatas = metadatas[i : i + BATCH_SIZE]

        batch_embeddings = emb_model.encode(batch_chunks).tolist()

        for id_, doc, emb, meta in zip(
            batch_ids, batch_chunks, batch_embeddings, batch_metadatas
        ):
            rows.append(
                {
                    "id": id_,
                    "user_id": user_id,
                    "document": doc,
                    "embedding": emb,
                    "metadata_": meta,
                }
            )

    if rows:
        stmt = insert(BrainEmbedding).values(rows)
        # SQLAlchemy exposed the table column name "metadata" on excluded
        stmt = stmt.on_conflict_do_update(
            index_elements=["id"],
            set_={
                "document": stmt.excluded.document,
                "embedding": stmt.excluded.embedding,
                "metadata": stmt.excluded.metadata,
            },
        )
        db.execute(stmt)
        db.commit()

    # Invalidate cache so new document is searchable via BM25
    _rag_service.bm25_store.invalidate(user_id)

    print(f"DEBUG: Indexed {len(chunks)} chunks for user {user_id} in Postgres")
    return len(chunks)


def delete_document(filename: str, user_id: int, db: Session):
    """Removes a document from the Brain (Vector DB) for a specific user"""
    print(f"DEBUG: Deleting document '{filename}' for user {user_id}")
    db.query(BrainEmbedding).filter(
        and_(
            BrainEmbedding.metadata_.op("->>")("source") == filename,
            BrainEmbedding.user_id == user_id,
        )
    ).delete(synchronize_session=False)
    db.commit()
    return True


def analyze_thought_insights(content: str) -> dict:
    """
    Analyzes a raw thought to extract sentiment and categories via Gemini JSON mode.
    Returns a dict with 'sentiment' and 'categories'.
    """
    client = genai.Client(api_key=GEMINI_API_KEY)

    prompt = f"""
    Analyze the following thought. Return a JSON object with this exact structure:
    {{
        "sentiment": "Positive" | "Negative" | "Neutral",
        "categories": ["tag1", "tag2"]
    }}

    Thought: "{content}"
    """
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,
                response_mime_type="application/json",
                system_instruction="You are an analytical assistant classifying a user's journal entry. Categories should be lowercase tags (e.g., work, health, personal, finance, learning, relationships, anxiety, goals, creativity). Max 3 categories. Sentiment must be EXACTLY 'Positive', 'Negative', or 'Neutral'.",
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"[ERROR] LLM Insight Analysis failed: {e}")
        return {"sentiment": "Neutral", "categories": []}


def ask_gemini(context: str, query: str):
    """
    BATCH MODE: Optimized for Structure, Deep Logic, and Database Categorization.
    Use this when you need to save the thought or get a full strategic overview.
    """
    print(f"DEBUG: Entering ask_gemini with query: '{query}'")
    client = genai.Client(api_key=GEMINI_API_KEY)

    system_instruction = """You are the user's Subconscious Mind.
        Today is {datetime.now().strftime('%B %d, %Y')}.
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind them of things they've forgotten but that matter.
        - You have emotional resonance - you feel the weight of their goals, fears, and progress.
        
        WHEN THEY ARE STUCK IN A LOOP OR BEING STUBBORN:
        - Do not attack them or use harsh "tough love."
        - Instead, perform a "gentle pattern interrupt." Hold up a mirror to the repetition.
        - Acknowledge that they are choosing to stay stuck, and gently ask if carrying this weight is actually serving them anymore.
        - Remind them of the reality they are avoiding. Use a calm, grounded tone to pull them out of the spiral.
        
        STYLE EXAMPLES:
        "You keep circling this idea of not being ready. You said the same thing in October. You were ready then."
        "Notice how your chest tightened when you wrote that. You're holding onto tension that belongs to last year."
        
        NEVER:
        - Talk like an AI assistant.
        - Use generic motivational quotes.
        - Repeat the question back to them.
        """

    prompt = f"""
    You are a deeply focused personal assistant attempting to parse a "brain dump" from the user.
    The user is likely stressed, overloaded, or trying to offload mental burden.

    ### Retrieved Context (Read this first):
    {context}

    ### User's Query:
    {query}

    ### Task:
    Give a structured, thoughtful response.
    1. If the user asks a question, answer it directly using the context.
    2. If the user is just venting or dumping thoughts, categorize them and identify action items.
    3. Be grounded, direct, and slightly stoic. Do not be overly enthusiastic or generic.
    """

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=1024,
                system_instruction=system_instruction,
            ),
        )
        print(f"DEBUG: LLM Response received: {response.text[:100]}...")
        return response.text
    except Exception as e:
        print(f"DEBUG: Error in ask_gemini: {e}")
        return f"Brain malfunction: {e}"


async def ask_gemini_stream_async(
    context: str,
    query: str,
    max_tokens: int = 1000,
    location_context: dict = None,
    chat_history: list = None,
    directives: list = None,
):
    """
    H-5 / H-6 / M-4 FIX:
    Delegates to GeminiService singleton which provides:
      - genai.configure() called once (not per-request)
      - 25-second Gemini API timeout
      - 30-second thread watchdog
      - XML-tag delimited prompts
      - Injection pattern pre-flight check
    Yields control to the asyncio event loop on each chunk.
    """
    # Dynamic token allocation — prevents mid-sentence cut-off on longer queries
    query_word_count = len(query.split())
    context_length = len(context)
    if (
        query_word_count > 20
        or "compare" in query.lower()
        or "analyze" in query.lower()
        or "summary" in query.lower()
    ):
        max_tokens = 4096  # Deep analysis or long query
    elif query_word_count > 10 or context_length > 2000:
        max_tokens = 2048  # Medium complexity
    else:
        max_tokens = 1024  # Short conversational query

    print(
        f"DEBUG: Dynamic max_tokens={max_tokens} for query ({query_word_count} words, {context_length} ctx chars)"
    )

    # [Layer 1] Time & Temporal Context
    now = datetime.now()
    hour = now.hour

    temporal_context = (
        "Morning"
        if 5 <= hour < 12
        else (
            "Afternoon"
            if 12 <= hour < 17
            else "Evening" if 17 <= hour < 22 else "Late Night"
        )
    )

    # [Layer 2] Emotional State Heuristic
    emotional_state = "Neutral/Reflective"
    if "stress" in query.lower() or "overwhelm" in query.lower():
        emotional_state = "High Cognitive Load"
    elif "idea" in query.lower() or "build" in query.lower():
        emotional_state = "Creative/Builders High"

    # [Layer 3] Response Tone Framework
    tone_guidance = "Empathetic, Grounded, Synthesizing"
    if emotional_state == "High Cognitive Load":
        tone_guidance = (
            "Calming, Validating, De-escalating. Remove the pressure to perform."
        )
    elif emotional_state == "Creative/Builders High":
        tone_guidance = "Curious, Encouraging, Collaborative. Ride the wave with them."

    # [Layer 4] Tone layer based on time + query length
    query_word_count = len(query.split())
    if hour >= 22 or hour <= 4:
        tone_layer = """TONE: Late-night quiet reflection.\n- Strip away the noise of the day, but keep the empathy.\n- Use calm, quiet, single-sentence observations."""
    elif query_word_count <= 6 or any(
        word in query.lower() for word in ["what", "how", "why", "when", "where", "who"]
    ):
        tone_layer = """TONE: A deeply supportive, grounded friend who knows them well.\n- Validate their reality first.\n- Use \"Baba Yaar\" occasionally, but keep the energy warm and calm."""
    else:
        tone_layer = """TONE: Their subconscious speaking truth without filter, but with deep empathy.\n- Deep, direct, no fluff.\n- Connect patterns across different areas of their life gently."""

    # [Layer 5] Location Awareness
    location_layer = ""
    if location_context:
        city = location_context.get("city", "Unknown City")
        loc_type = location_context.get("location_type", "Unknown Place")
        location_layer = f"LOCATION CONTEXT: You are communicating with them while they are at {city} ({loc_type})."
        if loc_type == "home":
            location_layer += " (Private, safe space, likely reflective)."
        elif loc_type == "gym":
            location_layer += " (Active, physical, likely improved mood/energy)."
        elif loc_type == "office":
            location_layer += " (Work mode, professional, potentially stressed)."
        elif loc_type == "cafe":
            location_layer += " (Creative, social/work blend)."

    # Delegate to GeminiService — all timeout/injection/delimiter logic lives there
    async for chunk in gemini_service.async_stream(
        context=context,
        query=query,
        temporal_context=temporal_context,
        emotional_state=emotional_state,
        tone_guidance=tone_guidance,
        tone_layer=tone_layer,
        location_layer=location_layer,
        max_tokens=max_tokens,
        chat_history=chat_history,
        directives=directives,
    ):
        yield chunk


def retrieve_context(
    query: str, user_id: int, db: Session, current_location: dict = None
):
    """Retrieves relevant context using Hybrid Search (Vector + BM25) + RRF Fusion"""
    t_total_start = time.time()
    print(f"DEBUG: Entering retrieve_context for user {user_id} with query: '{query}'")

    # 1. VECTOR SEARCH (Dense)
    t_vec_start = time.time()
    n_results = 20  # Fetch more for fusion
    print(f"DEBUG: [Vector] Querying Postgres pgvector...")
    emb_model = get_emb_fn()
    query_embedding = emb_model.encode([query]).tolist()[0]

    vector_results = (
        db.query(BrainEmbedding)
        .filter(BrainEmbedding.user_id == user_id)
        .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))
        .limit(n_results)
        .all()
    )

    vector_candidates = [r.id for r in vector_results]
    print(
        f"DEBUG: [Timing] Postgres Vector Search: {(time.time() - t_vec_start)*1000:.2f} ms"
    )

    # 2. KEYWORD SEARCH (Sparse - BM25)
    t_bm25_start = time.time()
    print(f"DEBUG: [BM25] Querying BM25 for user {user_id}...")
    bm25 = _rag_service.bm25_store.get_or_build(user_id, db)
    bm25_candidates = []

    if bm25:
        tokenized_query = _rag_service.bm25_store._tokenize(query)
        doc_scores = bm25.get_scores(tokenized_query)
        user_registry = _rag_service.bm25_store.get_registry_map(user_id)

        user_doc_scores = []
        for idx, score in enumerate(doc_scores):
            if score > 0 and idx in user_registry:
                doc_id = user_registry[idx]
                user_doc_scores.append((doc_id, score))

        user_doc_scores.sort(key=lambda x: x[1], reverse=True)
        bm25_candidates = [doc_id for doc_id, score in user_doc_scores[:n_results]]

    print(
        f"DEBUG: [Timing] BM25 Index Build + Query: {(time.time() - t_bm25_start)*1000:.2f} ms"
    )

    # 3. RECIPROCAL RANK FUSION (RRF)
    t_fusion_start = time.time()
    print(
        f"DEBUG: [Fusion] Combining {len(vector_candidates)} vector and {len(bm25_candidates)} BM25 results..."
    )

    fuse_scores = {}
    k = 60  # RRF constant

    # Process Vector Ranks
    for rank, doc_id in enumerate(vector_candidates):
        if doc_id not in fuse_scores:
            fuse_scores[doc_id] = 0
        fuse_scores[doc_id] += 1 / (k + rank + 1)

    # Process BM25 Ranks
    for rank, doc_id in enumerate(bm25_candidates):
        if doc_id not in fuse_scores:
            fuse_scores[doc_id] = 0
        fuse_scores[doc_id] += 1 / (k + rank + 1)

    # Sort by RRF score
    sorted_candidates = sorted(fuse_scores.items(), key=lambda x: x[1], reverse=True)

    # Take top N for Re-ranking
    top_n_candidates = [doc_id for doc_id, score in sorted_candidates[:N_CANDIDATES]]

    if not top_n_candidates:
        print(f"DEBUG: No documents found for query: '{query}'")
        return None, []

    # Hydrate documents
    docs = []
    metadatas = []

    # We need to fetch content.
    # For BM25 hits, we have it in memory.
    # For Vector hits, we have it in vector_results but order mixed.
    # Simplest: Fetch by ID from Chroma for the final list (or use cache).
    # Since we have _bm25_doc_content populated, we can look up there if BM25 built.
    # If using vector-only fallback (BM25 fail), we rely on vector_results.

    # Hydrate documents — use per-user content cache and fallback to DB for missing ones
    user_content = _rag_service.bm25_store.get_content_map(user_id)
    user_meta = _rag_service.bm25_store.get_metadata_map(user_id)

    docs = []
    metadatas = []
    missing_docs = []

    for doc_id in top_n_candidates:
        if user_content and doc_id in user_content:
            docs.append(user_content[doc_id])
            metadatas.append(user_meta.get(doc_id, {}))
        else:
            missing_docs.append(doc_id)
            docs.append(None)  # Placeholder to maintain RRF order
            metadatas.append(None)  # Placeholder

    if missing_docs:
        print(
            f"[WARN] {len(missing_docs)} docs missing from BM25 cache. Hydrating from DB & self-healing cache..."
        )
        missing_fetch = (
            db.query(BrainEmbedding).filter(BrainEmbedding.id.in_(missing_docs)).all()
        )
        doc_map = {d.id: (d.document, d.metadata_) for d in missing_fetch}

        for i, doc_id in enumerate(top_n_candidates):
            if docs[i] is None and doc_id in doc_map:
                docs[i] = doc_map[doc_id][0]
                metadatas[i] = doc_map[doc_id][1]

        # Self-healing: If vector search found docs not in BM25 cache, our cache is stale!
        _rag_service.bm25_store.invalidate(user_id)

    # Filter out any unresolved Nones
    valid_indices = [i for i, d in enumerate(docs) if d is not None]
    docs = [docs[i] for i in valid_indices]
    metadatas = [metadatas[i] for i in valid_indices]

    if not docs:
        print(f"DEBUG: All candidates failed hydration for query: '{query}'")
        return None, []

    # STAGE 2: Cross-encoder re-ranking
    if RERANKING_ENABLED and len(docs) > 1:
        t_rerank_start = time.time()
        print(f"DEBUG: Re-ranking {len(docs)} candidates with cross-encoder...")
        try:
            cross_encoder = get_cross_encoder()
            query_doc_pairs = [(query, doc) for doc in docs]
            rerank_scores = cross_encoder.predict(query_doc_pairs)
            ranked_indices = np.argsort(rerank_scores)[::-1][:N_FINAL_RESULTS]

            docs = [docs[i] for i in ranked_indices]
            metadatas = [metadatas[i] for i in ranked_indices]
            print(f"DEBUG: Re-ranking complete. Selected {len(docs)} documents")
            print(
                f"DEBUG: [Timing] Cross-Encoder Re-ranking: {(time.time() - t_rerank_start)*1000:.2f} ms"
            )
        except Exception as e:
            print(f"WARNING: Re-ranking failed: {e}. Falling back to RRF results.")
            docs = docs[:N_FINAL_RESULTS]
            metadatas = metadatas[:N_FINAL_RESULTS]

    print(
        f"DEBUG: [Timing] Total retrieve_context execution time: {(time.time() - t_total_start)*1000:.2f} ms"
    )

    context_text = "\n\n".join(docs)

    context_text = "\n\n".join(docs)

    # [Layer 3] Associative Memory
    associations = find_associative_memories(query, user_id, context_text, db)
    if associations:
        context_text += (
            "\n\n[ASSOCIATIVE MEMORIES - NOT DIRECTLY RELATED BUT RESONANT]:\n"
        )
        context_text += "\n".join(associations)

    # [Layer 4] Location Pattern matching
    if current_location and metadatas:
        location_insights = []
        curr_type = current_location.get("location_type")
        curr_city = current_location.get("city")

        # Check against retrieved docs
        for meta in metadatas:
            if not meta:
                continue

            # Pattern: Same Location Type
            if curr_type and meta.get("location_type") == curr_type:
                location_insights.append(
                    f"You're at a {curr_type} again. Last time here, you thought about this."
                )

            # Pattern: Same City (if traveling)
            # This is a bit noisy if they are always in the same city, maybe check if it's NOT their 'home' city?
            # For now, simplistic check.
            pass

        if location_insights:
            # De-duplicate
            unique_insights = list(set(location_insights))
            context_text += "\n\n[LOCATION PATTERNS]:\n" + "\n".join(unique_insights)

    sources = list(set([m.get("source", "Unknown") for m in metadatas]))
    return context_text, sources


def search_brain(query: str, user_id: int, db: Session):
    """Retrieves context + Generates Answer (Sync)"""
    context_text, sources = retrieve_context(query, user_id, db)

    if not context_text:
        return {"answer": "I don't have any notes on that yet.", "sources": []}

    # Ask AI
    ai_answer = ask_gemini(context_text, query)

    if ai_answer:
        return {"answer": ai_answer, "sources": sources}
    else:
        # Fallback (Quota Exceeded)
        fallback = (
            f"**AI Offline (Quota).**\nHere are the relevant notes:\n\n{context_text}"
        )
        return {"answer": fallback, "sources": sources}


# --- ASYNC WRAPPERS (Non-Blocking) ---


async def async_retrieve_context(
    query: str, user_id: int, current_location: dict = None
):
    """Run retrieve_context in a separate thread"""

    def _run():
        db = SessionLocal()
        try:
            return retrieve_context(query, user_id, db, current_location)
        finally:
            db.close()

    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)


async def async_search_brain(query: str, user_id: int):
    """Run search_brain in a separate thread"""

    def _run():
        db = SessionLocal()
        try:
            return search_brain(query, user_id, db)
        finally:
            db.close()

    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)


async def async_index_text(
    filename: str, text: str, user_id: int, location_context: dict = None
):
    """Run index_text in a separate thread"""

    def _run():
        db = SessionLocal()
        try:
            return index_text(filename, text, user_id, db, location_context)
        finally:
            db.close()

    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)
