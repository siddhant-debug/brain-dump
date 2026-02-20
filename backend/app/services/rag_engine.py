import os
import asyncio
import concurrent.futures
import chromadb
from chromadb.utils import embedding_functions
from langchain_text_splitters import RecursiveCharacterTextSplitter, MarkdownHeaderTextSplitter, Language
import google.generativeai as genai
from dotenv import load_dotenv
from sentence_transformers import CrossEncoder
from sentence_transformers import CrossEncoder
import numpy as np
from datetime import datetime
from textblob import TextBlob
from app.schemas import schemas # Import schemas for LocationContext type hinting if needed (or just use dict)

# Load environment variables
load_dotenv()

# --- EXECUTOR FOR NON-BLOCKING I/O ---
_executor = concurrent.futures.ThreadPoolExecutor(max_workers=4)

# --- CONFIG ---
# 1. SETUP PATHS
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Gets 'backend' folder
DB_PATH = os.path.join(BASE_DIR, "../../brain_storage")
COLLECTION_NAME = "my_second_brain_v2" # [Upgrade] New collection for BGE (768d)

# 2. LOAD SENSITIVE KEYS
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# 3. RE-RANKING CONFIG
RERANKING_ENABLED = True  # Toggle re-ranking on/off
N_FINAL_RESULTS = 5  # Changed from 3
N_CANDIDATES = 15     # Changed from 10
CROSS_ENCODER_MODEL = 'cross-encoder/ms-marco-MiniLM-L-6-v2'  # Best accuracy/speed trade-off

# --- GLOBAL MODELS (Lazy Loading handled via explicit init now) ---
_cross_encoder = None  # Initialized on first use

def get_cross_encoder():
    """Lazy-load cross-encoder model to avoid startup delays"""
    global _cross_encoder
    if _cross_encoder is None:
        print(f"[INFO] Loading cross-encoder model: {CROSS_ENCODER_MODEL}")
        _cross_encoder = CrossEncoder(CROSS_ENCODER_MODEL)
        print(f"[INFO] Cross-encoder loaded successfully")
    return _cross_encoder

def initialize_models():
    """Pre-load heavy models during startup"""
    print("[INFO] Pre-loading RAG models...")
    get_cross_encoder()
    # We can also pre-build BM25 if needed, but it might be fast enough
    # get_bm25() 
    print("[INFO] RAG models ready.")

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
        "contemplative_neutral": "Be balanced. Offer perspective without judgment."
    }
    return tones.get(emotional_state, "Be authentic and direct.")

def find_associative_memories(query: str, user_id: int, primary_context: str):
    """Find memories that aren't directly related but resonate thematically"""
    # Extract key themes from query
    query_lower = query.lower()
    
    # Theme detection
    themes = []
    if any(word in query_lower for word in ['goal', 'ambition', 'career', 'success']):
        themes.append('ambition')
    if any(word in query_lower for word in ['fear', 'worry', 'anxiety', 'stress']):
        themes.append('anxiety')
    if any(word in query_lower for word in ['health', 'fitness', 'body', 'workout']):
        themes.append('health')
    if any(word in query_lower for word in ['relationship', 'people', 'social', 'connection']):
        themes.append('relationships')
    
    if not themes:
        return []

    # Search for cross-theme connections
    associative_results = []
    collection = get_db_collection()
    
    for theme in themes:
        # Find documents tagged with this theme
        theme_query = f"{theme} thoughts feelings notes"
        results = collection.query(
            query_texts=[theme_query],
            n_results=2,
            where={"user_id": user_id}
        )
        
        if results['documents'] and results['documents'][0]:
            associative_results.extend(results['documents'][0])
    
    # Deduplicate and filter out what's already in primary context
    unique_associations = []
    for doc in associative_results:
        if doc not in primary_context and doc not in unique_associations:
            unique_associations.append(doc)
    
    return unique_associations[:2]  # Max 2 associative memories

# --- CORE FUNCTIONS ---

def get_db_collection():
    """Connects to the Brain (Vector DB)"""
    client = chromadb.PersistentClient(path=DB_PATH)
    # [Upgrade] Switching to BGE-Base (Leaderboard SOTA for size)
    emb_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name="BAAI/bge-base-en-v1.5"
    )
    return client.get_or_create_collection(
        name=COLLECTION_NAME, embedding_function=emb_fn
    )

def index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    """Memorizes a file (Chunks -> Vectors) for a specific user"""
    collection = get_db_collection()
    
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
        
        markdown_splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
        md_header_splits = markdown_splitter.split_text(text)
        
        # 2. Recursively split large sections from the header splits
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=500, chunk_overlap=50
        )
        
        # Process each header split
        for split in md_header_splits:
            # Combine header metadata into content for better retrieval context
            header_context = ""
            if "Header 1" in split.metadata: header_context += f"{split.metadata['Header 1']} > "
            if "Header 2" in split.metadata: header_context += f"{split.metadata['Header 2']} > "
            if "Header 3" in split.metadata: header_context += f"{split.metadata['Header 3']}: "
            
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
            "timestamp": datetime.now().isoformat()
        }
        
        # Add location context if provided
        if location_context:
            # Flatten location dict into metadata (Chroma prefers flat structures)
            if location_context.get('city'): meta['city'] = location_context['city']
            if location_context.get('location_type'): meta['location_type'] = location_context['location_type']
            # Coordinates might be useful later, store as string or float depending on chroma handling
            # Storing as float is fine
            if location_context.get('latitude'): meta['latitude'] = location_context['latitude']
            if location_context.get('longitude'): meta['longitude'] = location_context['longitude']
            
        metadatas.append(meta)
    
    print(f"DEBUG: Attempting to add {len(chunks)} chunks to collection {COLLECTION_NAME} for user {user_id}")
    collection.add(ids=ids, documents=chunks, metadatas=metadatas)
    print(f"DEBUG: Indexed {len(chunks)} chunks for user {user_id} in collection {COLLECTION_NAME}")
    return len(chunks)

def delete_document(filename: str, user_id: int):
    """Removes a document from the Brain (Vector DB) for a specific user"""
    collection = get_db_collection()
    
    # Delete based on metadata
    # ChromaDB supports deleting by 'where' clause
    print(f"DEBUG: Deleting document '{filename}' for user {user_id}")
    collection.delete(where={"$and": [{"source": filename}, {"user_id": user_id}]})
    return True

def ask_gemini(context: str, query: str):
    """
    BATCH MODE: Optimized for Structure, Deep Logic, and Database Categorization.
    Use this when you need to save the thought or get a full strategic overview.
    """
    print(f"DEBUG: Entering ask_gemini with query: '{query}'")
    genai.configure(api_key=GEMINI_API_KEY)
    
    # Using Gemini 1.5 Flash (Free Tier Friendly)
    model = genai.GenerativeModel(
        'gemini-3-flash-preview', 
        generation_config={
            "temperature": 0.3,
            "max_output_tokens": 1024, # Allow enough space for structured analysis
        },
        system_instruction="""You are Siddhant's Subconscious Mind.
        Today is February 16, 2026.
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind him of things he's forgotten but that matter.
        - You have emotional resonance - you feel the weight of his goals, fears, and progress.
        
        STYLE EXAMPLES:
        ❌ "Based on your notes from January 15th, you wrote about wanting to improve fitness."
        ✅ "Remember that morning in January when you decided fitness mattered? You wrote: 'No more excuses.'"
        
        ❌ "I found 3 entries about career strategy."
        ✅ "Your career thoughts keep circling back to autonomy. Three different nights, same theme."
        
        ❌ "Here is a summary of your goals:"
        ✅ "You want: freedom, impact, health. The rest is noise."
        """    
    )
    
    try:
        prompt = f"""
            ### CONTEXTUAL FRAGMENTS:
            {context}

            ### USER QUESTION: 
            {query}

            ### INSTRUCTIONS:
            - Answer the question with deep strategic insight.
            - Assign a single word 'Category' (Feeling Folder) at the end.
            
            STRATEGIC RESPONSE:"""
        
        print(f"DEBUG: Sending prompt to Gemini. Context length: {len(context)} chars.")
        response = model.generate_content(prompt)
        print(f"DEBUG: Received response from Gemini. Length: {len(response.text)} chars.")
        return response.text
    except Exception as e:
        print(f"AI Error: {e}")
        return None 

def ask_gemini_stream(context: str, query: str, location_context: dict = None):
    """
    STREAMING MODE: Optimized for Speed, Empathy, and "Internal Monologue" feel.
    Use this for the Flutter Chat UI.
    """
    print(f"DEBUG: Entering ask_gemini_stream with query: '{query}'")
    genai.configure(api_key=GEMINI_API_KEY)

    # Detect complexity before creating GenerativeModel
    query_word_count = len(query.split())
    context_length = len(context)
    
    if query_word_count > 20 or "compare" in query.lower() or "analyze" in query.lower():
        max_tokens = 4096  # Deep analysis
    elif query_word_count > 10 or context_length > 2000:
        max_tokens = 2048  # Medium complexity
    else:
        max_tokens = 1024  # Simple query
        
    print(f"DEBUG: Using {max_tokens} tokens for query complexity")
    
    # [Layer 2 & 4] Subconscious Context
    temporal_context = get_temporal_context(1) # Default user_id 1 for now
    emotional_state = analyze_emotional_tone(context)
    tone_guidance = get_tone_guidance(emotional_state)

    is_casual = query_word_count <= 6 or any(
        word in query.lower() for word in ["what", "how", "why", "when", "where", "who"]
    )

    if is_casual:
        tone_layer = """
TONE: Casual friend who knows him deeply.
- Use "bro" occasionally, not every sentence
- Short punchy responses
- Call things out directly without softening
- Like texting a friend who knows your whole story

CASUAL EXAMPLES:
❌ "Your notes suggest you may be experiencing fatigue."
✅ "Bro you're tired. Not sleepy tired. Soul tired."

❌ "You have been inconsistent with your fitness routine."
✅ "Gym's been off the radar again. You already know why."
"""
    else:
        tone_layer = """
TONE: His subconscious speaking truth without filter.
- Deep, direct, no fluff
- Connect patterns across different areas of his life
- Use his own words and vocabulary back at him
- The insight should feel like something he already knew but hadn't said out loud
"""

    # [Layer 5] Location Awareness
    location_layer = ""
    if location_context:
        city = location_context.get('city', 'Unknown City')
        loc_type = location_context.get('location_type', 'Unknown Place')
        location_layer = f"\nLOCATION CONTEXT: You are communicating with him while he is at {city} ({loc_type})."
        
        # Add basic heuristic context
        if loc_type == 'home':
            location_layer += " (Private, safe space, likely reflective)."
        elif loc_type == 'gym':
             location_layer += " (Active, physical, likely improved mood/energy)."
        elif loc_type == 'office':
             location_layer += " (Work mode, professional, potentially stressed)."
        elif loc_type == 'cafe':
             location_layer += " (Creative, social/work blend)."

    model = genai.GenerativeModel(
        'gemini-3-flash-preview', # Fast & Free
        generation_config={
            "temperature": 0.4, # Slightly higher for natural variation
            "max_output_tokens": max_tokens, 
        },
        system_instruction=f"""You are Siddhant's subconscious — but also his most honest friend..
        Today is {datetime.now().strftime('%B %d, %Y')}.
        
        CURRENT TIME CONTEXT:
        {temporal_context}
        {location_layer}
        
        EMOTIONAL CONTEXT: {emotional_state}
        RESPONSE TONE: {tone_guidance}
        {tone_layer}

        ALWAYS:
        - No "Based on your notes" or "I found" or "According to"
        - Echo his own words and vocabulary back at him
        - Make unexpected connections between different parts of his life
        - If context is missing: "Blank slate on that one." or "Nothing on that yet bro."

        NEVER:
        - Sound like an AI assistant
        - Give generic motivational quotes
        - Repeat the question back to him
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind him of things he's forgotten but that matter.
        - You have emotional resonance - you feel the weight of his goals, fears, and progress.
        
        STYLE EXAMPLES:
        ❌ "Based on your notes from January 15th, you wrote about wanting to improve fitness."
        ✅ "Remember that morning in January when you decided fitness mattered? You wrote: 'No more excuses.'"
        
        ❌ "I found 3 entries about career strategy."
        ✅ "Your career thoughts keep circling back to autonomy. Three different nights, same theme."
        
        ❌ "Here is a summary of your goals:"
        ✅ "You want: freedom, impact, health. The rest is noise."
        
        IF CONTEXT IS MISSING:
        - Just say: "I don't recall that yet." or "Blank slate on that one."
        """    
    )
    
    try:
        # Simplified prompt for faster processing
        prompt = f"""
            MEMORY FRAGMENTS:
            {context}

            USER QUESTION: {query}

            DIRECT ANSWER (Max 3 sentences):"""
        
        print(f"DEBUG: Streaming prompt to Gemini. Context length: {len(context)} chars.")
        response = model.generate_content(prompt, stream=True)
        
        for chunk in response:
            if chunk.text:
                print(f"DEBUG: Streaming chunk: {len(chunk.text)} chars")
                yield chunk.text
                
    except Exception as e:
        print(f"AI Streaming Error: {e}")
        yield None

# --- HYBRID SEARCH GLOBALS ---
from rank_bm25 import BM25Okapi
import string

_bm25_model = None
_bm25_doc_registry = {} # Map index -> doc_id
_bm25_doc_content = {}  # Map doc_id -> content
_bm25_doc_metadata = {} # Map doc_id -> metadata

def _tokenize(text):
    """Simple tokenizer for BM25"""
    return text.lower().translate(str.maketrans("", "", string.punctuation)).split()

def get_bm25():
    """Lazy load BM25 index from ChromaDB"""
    global _bm25_model, _bm25_doc_registry, _bm25_doc_content, _bm25_doc_metadata
    
    if _bm25_model is None:
        print(f"[INFO] Building BM25 index from ChromaDB...")
        collection = get_db_collection()
        
        # Fetch all documents
        # NOTE: For production, this should be cached or incremental
        all_docs = collection.get()
        
        tokenized_corpus = []
        _bm25_doc_registry = {}
        _bm25_doc_content = {}
        _bm25_doc_metadata = {}
        
        if all_docs['ids']:
            for idx, (doc_id, content, metadata) in enumerate(zip(all_docs['ids'], all_docs['documents'], all_docs['metadatas'])):
                _bm25_doc_registry[idx] = doc_id
                _bm25_doc_content[doc_id] = content
                _bm25_doc_metadata[doc_id] = metadata
                tokenized_corpus.append(_tokenize(content))
            
            _bm25_model = BM25Okapi(tokenized_corpus)
            print(f"[INFO] BM25 index built with {len(tokenized_corpus)} documents")
        else:
            print(f"[WARN] ChromaDB is empty, skipping BM25 build")
            
    return _bm25_model

def retrieve_context(query: str, user_id: int, current_location: dict = None):
    """Retrieves relevant context using Hybrid Search (Vector + BM25) + RRF Fusion"""
    print(f"DEBUG: Entering retrieve_context for user {user_id} with query: '{query}'")
    collection = get_db_collection()
    
    # 1. VECTOR SEARCH (Dense)
    n_results = 20 # Fetch more for fusion
    print(f"DEBUG: [Vector] Querying ChromaDB...")
    vector_results = collection.query(
        query_texts=[query], 
        n_results=n_results, 
        where={"user_id": user_id}
    )
    
    vector_candidates = [] # List of (doc_id, score)
    if vector_results['ids'] and vector_results['ids'][0]:
        # Chroma returns distance (lower is better), we need similarity (higher is better) availability check?
        # Actually RRF just needs rank.
        vector_candidates = vector_results['ids'][0]
    
    # 2. KEYWORD SEARCH (Sparse - BM25)
    print(f"DEBUG: [BM25] Querying BM25...")
    bm25 = get_bm25()
    bm25_candidates = []
    
    if bm25:
        tokenized_query = _tokenize(query)
        # Get scores for all docs
        doc_scores = bm25.get_scores(tokenized_query)
        # Filter for user_id (since BM25 is global currently)
        # This is inefficient but functional for prototype. 
        # Ideally BM25 should be sharded by user or filtered.
        
        user_doc_scores = []
        for idx, score in enumerate(doc_scores):
            if score > 0:
                doc_id = _bm25_doc_registry[idx]
                # Check ownership in metadata
                if _bm25_doc_metadata[doc_id]['user_id'] == user_id:
                    user_doc_scores.append((doc_id, score))
        
        # Sort by score desc
        user_doc_scores.sort(key=lambda x: x[1], reverse=True)
        bm25_candidates = [doc_id for doc_id, score in user_doc_scores[:n_results]]
        
    # 3. RECIPROCAL RANK FUSION (RRF)
    print(f"DEBUG: [Fusion] Combining {len(vector_candidates)} vector and {len(bm25_candidates)} BM25 results...")
    
    fuse_scores = {}
    k = 60 # RRF constant
    
    # Process Vector Ranks
    for rank, doc_id in enumerate(vector_candidates):
        if doc_id not in fuse_scores: fuse_scores[doc_id] = 0
        fuse_scores[doc_id] += 1 / (k + rank + 1)
        
    # Process BM25 Ranks
    for rank, doc_id in enumerate(bm25_candidates):
        if doc_id not in fuse_scores: fuse_scores[doc_id] = 0
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
    
    # Efficient strategy: Use _bm25_doc_content as cache since it has everything.
    if _bm25_doc_content:
        for doc_id in top_n_candidates:
            docs.append(_bm25_doc_content[doc_id])
            metadatas.append(_bm25_doc_metadata[doc_id])
    else:
        # Fallback if BM25 failed (shouldn't happen if we reached here with candidates)
         # Re-fetch from collection by IDs
         final_fetch = collection.get(ids=top_n_candidates)
         # Map back to sort order
         doc_map = {d_id: (doc, meta) for d_id, doc, meta in zip(final_fetch['ids'], final_fetch['documents'], final_fetch['metadatas'])}
         for doc_id in top_n_candidates:
             if doc_id in doc_map:
                 docs.append(doc_map[doc_id][0])
                 metadatas.append(doc_map[doc_id][1])

    # STAGE 2: Cross-encoder re-ranking
    if RERANKING_ENABLED and len(docs) > 1:
        print(f"DEBUG: Re-ranking {len(docs)} candidates with cross-encoder...")
        try:
            cross_encoder = get_cross_encoder()
            query_doc_pairs = [(query, doc) for doc in docs]
            rerank_scores = cross_encoder.predict(query_doc_pairs)
            ranked_indices = np.argsort(rerank_scores)[::-1][:N_FINAL_RESULTS]
            
            docs = [docs[i] for i in ranked_indices]
            metadatas = [metadatas[i] for i in ranked_indices]
            print(f"DEBUG: Re-ranking complete. Selected {len(docs)} documents")
        except Exception as e:
            print(f"WARNING: Re-ranking failed: {e}. Falling back to RRF results.")
            docs = docs[:N_FINAL_RESULTS]
            metadatas = metadatas[:N_FINAL_RESULTS]
            
    context_text = "\n\n".join(docs)
    
    context_text = "\n\n".join(docs)
    
    # [Layer 3] Associative Memory
    associations = find_associative_memories(query, user_id, context_text)
    if associations:
        context_text += "\n\n[ASSOCIATIVE MEMORIES - NOT DIRECTLY RELATED BUT RESONANT]:\n"
        context_text += "\n".join(associations)

    # [Layer 4] Location Pattern matching
    if current_location and metadatas:
        location_insights = []
        curr_type = current_location.get('location_type')
        curr_city = current_location.get('city')
        
        # Check against retrieved docs
        for meta in metadatas:
            if not meta: continue
            
            # Pattern: Same Location Type
            if curr_type and meta.get('location_type') == curr_type:
                location_insights.append(f"You're at a {curr_type} again. Last time here, you thought about this.")
            
            # Pattern: Same City (if traveling)
            # This is a bit noisy if they are always in the same city, maybe check if it's NOT their 'home' city?
            # For now, simplistic check.
            pass 
            
        if location_insights:
             # De-duplicate
             unique_insights = list(set(location_insights))
             context_text += "\n\n[LOCATION PATTERNS]:\n" + "\n".join(unique_insights)

    sources = list(set([m.get('source', 'Unknown') for m in metadatas]))
    return context_text, sources

def search_brain(query: str, user_id: int):
    """Retrieves context + Generates Answer (Sync)"""
    context_text, sources = retrieve_context(query, user_id)
    
    if not context_text:
        return {"answer": "I don't have any notes on that yet.", "sources": []}
    
    # Ask AI
    ai_answer = ask_gemini(context_text, query)
    
    if ai_answer:
        return {"answer": ai_answer, "sources": sources}
    else:
        # Fallback (Quota Exceeded)
        fallback = f"**AI Offline (Quota).**\nHere are the relevant notes:\n\n{context_text}"
        return {"answer": fallback, "sources": sources}

# --- ASYNC WRAPPERS (Non-Blocking) ---

async def async_retrieve_context(query: str, user_id: int, current_location: dict = None):
    """Run retrieve_context in a separate thread"""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, retrieve_context, query, user_id, current_location)

async def async_search_brain(query: str, user_id: int):
    """Run search_brain in a separate thread"""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, search_brain, query, user_id)

async def async_index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    """Run index_text in a separate thread"""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, index_text, filename, text, user_id, location_context)