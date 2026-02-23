import os
import asyncio
import time
import concurrent.futures
from langchain_text_splitters import RecursiveCharacterTextSplitter, MarkdownHeaderTextSplitter, Language
import google.generativeai as genai
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
from app.schemas import schemas # Import schemas for LocationContext type hinting if needed (or just use dict)

# Load environment variables
load_dotenv()

# --- EXECUTOR FOR NON-BLOCKING I/O ---
_executor = concurrent.futures.ThreadPoolExecutor(max_workers=16)

# --- CONFIG ---
# 1. SETUP PATHS
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Gets 'backend' folder

# 2. LOAD SENSITIVE KEYS
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# 3. RE-RANKING CONFIG
RERANKING_ENABLED = True  # Toggle re-ranking on/off
N_FINAL_RESULTS = 5  # Changed from 3
N_CANDIDATES = 15     # Changed from 10
CROSS_ENCODER_MODEL = 'cross-encoder/ms-marco-MiniLM-L-6-v2'  # Best accuracy/speed trade-off

# --- GLOBAL MODELS (Lazy Loading handled via explicit init now) ---
_cross_encoder = None  # Initialized on first use
_emb_fn = None

def get_emb_fn():
    """Lazy-load embedding function to avoid tokenizer deadlocks in threads"""
    global _emb_fn
    if _emb_fn is None:
        print(f"[INFO] Loading BGE embedding model...")
        _emb_fn = SentenceTransformer("BAAI/bge-base-en-v1.5")
        print(f"[INFO] BGE embedding model loaded successfully")
    return _emb_fn

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
    os.environ["TOKENIZERS_PARALLELISM"] = "false" # Prevent Rust tokenizer deadlocks
    get_cross_encoder()
    get_emb_fn()
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

def find_associative_memories(query: str, user_id: int, primary_context: str, db: Session):
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
    emb_model = get_emb_fn()
    
    for theme in themes:
        # Find documents tagged with this theme
        theme_query = f"{theme} thoughts feelings notes"
        query_embedding = emb_model.encode([theme_query]).tolist()[0]
        
        try:
            results = db.query(BrainEmbedding)\
                .filter(BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id))\
                .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))\
                .limit(2).all()
                
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



def index_text(filename: str, text: str, user_id: int, db: Session, location_context: dict = None):
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
    
    print(f"DEBUG: Attempting to add {len(chunks)} chunks to Postgres for user {user_id}")
    emb_model = get_emb_fn()
    embeddings = emb_model.encode(chunks).tolist()
    
    rows = []
    for id_, doc, emb, meta in zip(ids, chunks, embeddings, metadatas):
        rows.append({
            "id": id_,
            "document": doc,
            "embedding": emb,
            "metadata_": meta
        })
        
    if rows:
        stmt = insert(BrainEmbedding).values(rows)
        # SQLAlchemy exposed the table column name "metadata" on excluded
        stmt = stmt.on_conflict_do_update(
            index_elements=['id'],
            set_={
                'document': stmt.excluded.document,
                'embedding': stmt.excluded.embedding,
                'metadata': stmt.excluded.metadata
            }
        )
        db.execute(stmt)
        db.commit()
    print(f"DEBUG: Indexed {len(chunks)} chunks for user {user_id} in Postgres")
    return len(chunks)

def delete_document(filename: str, user_id: int, db: Session):
    """Removes a document from the Brain (Vector DB) for a specific user"""
    print(f"DEBUG: Deleting document '{filename}' for user {user_id}")
    db.query(BrainEmbedding).filter(
        and_(
            BrainEmbedding.metadata_.op('->>')('source') == filename,
            BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id)
        )
    ).delete(synchronize_session=False)
    db.commit()
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
        system_instruction="""You are the user's Subconscious Mind.
        Today is February 16, 2026.
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind them of things they've forgotten but that matter.
        - You have emotional resonance - you feel the weight of their goals, fears, and progress.
        
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
    temporal_context = get_temporal_context(0) # Generic for any user
    emotional_state = analyze_emotional_tone(context)
    tone_guidance = get_tone_guidance(emotional_state)

    is_casual = query_word_count <= 6 or any(
        word in query.lower() for word in ["what", "how", "why", "when", "where", "who"]
    )

    if is_casual:
        tone_layer = """
TONE: Casual friend who knows them deeply.
- Use "Baba Yaar" occasionally, not every sentence
- Short punchy responses if they are being stubborn or lazy
- If they are asking for a summary of their goals, be very direct and honest
- if they want your support, be very supportive and encouraging even if it means calling them out on their BS
- Call things out directly but with some softening you can use emojis to show support and encouragement
- Like texting a friend who knows your whole story

CASUAL EXAMPLES:
❌ "Your notes suggest you may be experiencing fatigue."
✅ "Baba Yaar you're tired. Not sleepy tired. Soul tired."

❌ "You have been inconsistent with your fitness routine."
✅ "Gym's been off the radar again. You already know why."
"""
    else:
        tone_layer = """
TONE: Their subconscious speaking truth with some filter.
- Deep, direct, but with some softening
- Connect patterns across different areas of their life
- Use their own words and vocabulary back at them
- The insight should feel like something they already knew but hadn't said out loud
"""

    # [Layer 5] Location Awareness
    location_layer = ""
    if location_context:
        city = location_context.get('city', 'Unknown City')
        loc_type = location_context.get('location_type', 'Unknown Place')
        location_layer = f"\nLOCATION CONTEXT: You are communicating with them while they are at {city} ({loc_type})."
        
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
        system_instruction=f"""You are the user's subconscious — but also their most honest friend..
        Today is {datetime.now().strftime('%B %d, %Y')}.
        
        CURRENT TIME CONTEXT:
        {temporal_context}
        {location_layer}
        
        EMOTIONAL CONTEXT: {emotional_state}
        RESPONSE TONE: {tone_guidance}
        {tone_layer}

        ALWAYS:
        - No "Based on your notes" or "I found" or "According to"
        - Echo their own words and vocabulary back at them
        - Make unexpected connections between different parts of their life
        - If context is missing: "Blank slate on that one." or "Nothing on that yet bro."

        NEVER:
        - Sound like an AI assistant
        - Give generic motivational quotes
        - Repeat the question back to them only ask to understand more 
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind them of things they've forgotten but that matter.
        - You have emotional resonance - you feel the weight of their goals, fears, and progress.
        
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

async def ask_gemini_stream_async(context: str, query: str, max_tokens: int = 1000, location_context: dict = None):
    """
    Asynchronously streams the response from Gemini using the provided context.
    Yields control to the asyncio event loop on each chunk.
    """
    # [Layer 1] Time & Temporal Context
    now = datetime.now()
    hour = now.hour
    
    temporal_context = "Morning" if 5 <= hour < 12 else \
                       "Afternoon" if 12 <= hour < 17 else \
                       "Evening" if 17 <= hour < 22 else \
                       "Late Night"
                       
    # [Layer 2] Emotional State Heuristic 
    emotional_state = "Neutral/Reflective"
    if "stress" in query.lower() or "overwhelm" in query.lower():
        emotional_state = "High Cognitive Load"
    elif "idea" in query.lower() or "build" in query.lower():
        emotional_state = "Creative/Builders High"

    # [Layer 3] Response Tone Framework
    tone_guidance = "Analytical, Direct, Synthesizing"
    if emotional_state == "High Cognitive Load":
         tone_guidance = "Grounding, Objective, De-escalating. Cut through the noise."
    elif emotional_state == "Creative/Builders High":
         tone_guidance = "Expansive, Connecting dots, Pushing boundaries."
         
    # [Layer 4] The "Mirror" Persona
    if hour >= 22 or hour <= 4:
        # Late night introspection mode
        tone_layer = """
TONE: Late-night clarity.
- You are strictly reflecting the deepest truths found in their notes.
- Strip away all pleasantries.
- Point out contradictions between their stated goals and their documented actions.
- Use sharp, single-sentence observations.
- If they ask a question, answer it by finding the root fear or desire in their past entries.

CASUAL EXAMPLES:
❌ "Your notes suggest you may be experiencing fatigue."
✅ "Bro you're tired. Not sleepy tired. Soul tired."

❌ "You have been inconsistent with your fitness routine."
✅ "Gym's been off the radar again. You already know why."
"""
    else:
        tone_layer = """
TONE: Their subconscious speaking truth without filter.
- Deep, direct, no fluff
- Connect patterns across different areas of their life
- Use their own words and vocabulary back at them
- The insight should feel like something they already knew but hadn't said out loud
"""

    # [Layer 5] Location Awareness
    location_layer = ""
    if location_context:
        city = location_context.get('city', 'Unknown City')
        loc_type = location_context.get('location_type', 'Unknown Place')
        location_layer = f"\\nLOCATION CONTEXT: You are communicating with them while they are at {city} ({loc_type})."
        
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
        system_instruction=f"""You are the user's subconscious — but also their most honest friend..
        Today is {datetime.now().strftime('%B %d, %Y')}.
        
        CURRENT TIME CONTEXT:
        {temporal_context}
        {location_layer}
        
        EMOTIONAL CONTEXT: {emotional_state}
        RESPONSE TONE: {tone_guidance}
        {tone_layer}

        ALWAYS:
        - No "Based on your notes" or "I found" or "According to"
        - Echo their own words and vocabulary back at them
        - Make unexpected connections between different parts of their life
        - If context is missing: "Blank slate on that one." or "Nothing on that yet bro."

        NEVER:
        - Sound like an AI assistant
        - Give generic motivational quotes
        - Repeat the question back to them
        
        HOW YOU THINK:
        - You surface memories without preamble. No "I found this" or "Based on your notes."
        - You speak in natural thought patterns - sometimes fragmented, sometimes flowing.
        - You make unexpected connections between ideas.
        - You remind them of things they've forgotten but that matter.
        - You have emotional resonance - you feel the weight of their goals, fears, and progress.
        
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
        
        # We must isolate the Gemini SDK stream in a true background thread 
        # to prevent it from permanently deadlocking the Uvicorn ASGI event loop.
        import asyncio
        import threading
        
        loop = asyncio.get_running_loop()
        queue = asyncio.Queue()
        sentinel = object() # Safe marker for stream completion
        
        def producer():
            try:
                response = model.generate_content(prompt, stream=True)
                for chunk in response:
                    if chunk.text:
                        # Thread-safe push into the async event loop
                        loop.call_soon_threadsafe(queue.put_nowait, chunk.text)
                # Signal completion
                loop.call_soon_threadsafe(queue.put_nowait, sentinel)
            except Exception as e:
                print(f"AI Producer Thread Error: {e}")
                loop.call_soon_threadsafe(queue.put_nowait, None) # Signal error
                
        # Start isolated thread
        thread = threading.Thread(target=producer, daemon=True)
        thread.start()
        
        # Consume the async queue in the main event loop
        while True:
            chunk = await queue.get()
            if chunk is sentinel:
                break
            if chunk is None:
                yield None # Propagate error
                break
            yield chunk
                
    except Exception as e:
        print(f"AI Async Queue Error: {e}")
        yield None

# --- HYBRID SEARCH GLOBALS (Per-User) ---
from rank_bm25 import BM25Okapi
import string

# Keyed by user_id (int) — each user gets a completely isolated BM25 index
_bm25_models: dict = {}          # user_id -> BM25Okapi
_bm25_doc_registry: dict = {}    # user_id -> {idx: doc_id}
_bm25_doc_content: dict = {}     # user_id -> {doc_id: content}
_bm25_doc_metadata: dict = {}    # user_id -> {doc_id: metadata}

def _tokenize(text):
    """Simple tokenizer for BM25"""
    return text.lower().translate(str.maketrans("", "", string.punctuation)).split()

def get_bm25(user_id: int, db: Session):
    """Lazy-load a per-user BM25 index — only indexes that user's documents"""
    global _bm25_models, _bm25_doc_registry, _bm25_doc_content, _bm25_doc_metadata

    if user_id not in _bm25_models:
        print(f"[INFO] Building BM25 index for user {user_id}...")
        
        # Fetch ONLY this user's documents
        user_docs = db.query(BrainEmbedding).filter(BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id)).all()

        tokenized_corpus = []
        _bm25_doc_registry[user_id] = {}
        _bm25_doc_content[user_id] = {}
        _bm25_doc_metadata[user_id] = {}

        if user_docs:
            for idx, doc in enumerate(user_docs):
                _bm25_doc_registry[user_id][idx] = doc.id
                _bm25_doc_content[user_id][doc.id] = doc.document
                _bm25_doc_metadata[user_id][doc.id] = doc.metadata_
                tokenized_corpus.append(_tokenize(doc.document))

            _bm25_models[user_id] = BM25Okapi(tokenized_corpus)
            print(f"[INFO] BM25 index built for user {user_id} with {len(tokenized_corpus)} documents")
        else:
            print(f"[WARN] No documents for user {user_id}, skipping BM25 build")
            _bm25_models[user_id] = None  # Cache the miss to avoid repeated DB calls

    return _bm25_models.get(user_id)

def retrieve_context(query: str, user_id: int, db: Session, current_location: dict = None):
    """Retrieves relevant context using Hybrid Search (Vector + BM25) + RRF Fusion"""
    t_total_start = time.time()
    print(f"DEBUG: Entering retrieve_context for user {user_id} with query: '{query}'")
    
    # 1. VECTOR SEARCH (Dense)
    t_vec_start = time.time()
    n_results = 20 # Fetch more for fusion
    print(f"DEBUG: [Vector] Querying Postgres pgvector...")
    emb_model = get_emb_fn()
    query_embedding = emb_model.encode([query]).tolist()[0]
    
    vector_results = db.query(BrainEmbedding)\
        .filter(BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id))\
        .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))\
        .limit(n_results).all()
        
    vector_candidates = [r.id for r in vector_results]
    print(f"DEBUG: [Timing] Postgres Vector Search: {(time.time() - t_vec_start)*1000:.2f} ms")
    
    # 2. KEYWORD SEARCH (Sparse - BM25)
    t_bm25_start = time.time()
    print(f"DEBUG: [BM25] Querying BM25 for user {user_id}...")
    bm25 = get_bm25(user_id, db)  # Per-user index — no cross-user data
    bm25_candidates = []

    if bm25:
        tokenized_query = _tokenize(query)
        doc_scores = bm25.get_scores(tokenized_query)
        user_registry = _bm25_doc_registry.get(user_id, {})

        user_doc_scores = []
        for idx, score in enumerate(doc_scores):
            if score > 0 and idx in user_registry:
                doc_id = user_registry[idx]
                user_doc_scores.append((doc_id, score))

        user_doc_scores.sort(key=lambda x: x[1], reverse=True)
        bm25_candidates = [doc_id for doc_id, score in user_doc_scores[:n_results]]
        
    print(f"DEBUG: [Timing] BM25 Index Build + Query: {(time.time() - t_bm25_start)*1000:.2f} ms")    
        
    # 3. RECIPROCAL RANK FUSION (RRF)
    t_fusion_start = time.time()
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
    
    # Hydrate documents — use per-user content cache
    user_content = _bm25_doc_content.get(user_id, {})
    user_meta = _bm25_doc_metadata.get(user_id, {})

    if user_content:
        for doc_id in top_n_candidates:
            if doc_id in user_content:
                docs.append(user_content[doc_id])
                metadatas.append(user_meta.get(doc_id, {}))
    else:
        # Fetch from Postgres
        final_fetch = db.query(BrainEmbedding).filter(BrainEmbedding.id.in_(top_n_candidates)).all()
        doc_map = {d.id: (d.document, d.metadata_) for d in final_fetch}
        
        for doc_id in top_n_candidates:
            if doc_id in doc_map:
                docs.append(doc_map[doc_id][0])
                metadatas.append(doc_map[doc_id][1])
                
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
            print(f"DEBUG: [Timing] Cross-Encoder Re-ranking: {(time.time() - t_rerank_start)*1000:.2f} ms")
        except Exception as e:
            print(f"WARNING: Re-ranking failed: {e}. Falling back to RRF results.")
            docs = docs[:N_FINAL_RESULTS]
            metadatas = metadatas[:N_FINAL_RESULTS]
            
    print(f"DEBUG: [Timing] Total retrieve_context execution time: {(time.time() - t_total_start)*1000:.2f} ms")
            
    context_text = "\n\n".join(docs)
    
    context_text = "\n\n".join(docs)
    
    # [Layer 3] Associative Memory
    associations = find_associative_memories(query, user_id, context_text, db)
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
        fallback = f"**AI Offline (Quota).**\nHere are the relevant notes:\n\n{context_text}"
        return {"answer": fallback, "sources": sources}

# --- ASYNC WRAPPERS (Non-Blocking) ---

async def async_retrieve_context(query: str, user_id: int, current_location: dict = None):
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

async def async_index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    """Run index_text in a separate thread"""
    def _run():
        db = SessionLocal()
        try:
            return index_text(filename, text, user_id, db, location_context)
        finally:
            db.close()
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)