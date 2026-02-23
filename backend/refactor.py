with open("app/services/rag_engine.py", "r") as f:
    code = f.read()

# 1. Imports
code = code.replace("import chromadb\nfrom chromadb.utils import embedding_functions\n", "")
code = code.replace("from sentence_transformers import CrossEncoder\nfrom sentence_transformers import CrossEncoder", "from sentence_transformers import CrossEncoder, SentenceTransformer\nfrom sqlalchemy.orm import Session\nfrom sqlalchemy.dialects.postgresql import insert\nfrom sqlalchemy import and_\nfrom app.models.models import BrainEmbedding\nfrom app.core.database import SessionLocal\nimport json")

# 2. get_emb_fn
code = code.replace(
"""        _emb_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name="BAAI/bge-base-en-v1.5"
        )""",
"""        _emb_fn = SentenceTransformer("BAAI/bge-base-en-v1.5")"""
)

# 3. get_db_collection
code = code.replace(
"""def get_db_collection():
    \"\"\"Connects to the Brain (Vector DB)\"\"\"
    client = chromadb.PersistentClient(path=DB_PATH)
    # [Upgrade] Switching to BGE-Base (Leaderboard SOTA for size)
    emb_fn = get_emb_fn()
    return client.get_or_create_collection(
        name=COLLECTION_NAME, embedding_function=emb_fn
    )""",
""
)

# 4. index_text
code = code.replace(
"""def index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    \"\"\"Memorizes a file (Chunks -> Vectors) for a specific user\"\"\"
    collection = get_db_collection()""",
"""def index_text(filename: str, text: str, user_id: int, db: Session, location_context: dict = None):
    \"\"\"Memorizes a file (Chunks -> Vectors) for a specific user\"\"\""""
)

old_index_insert = """    print(f"DEBUG: Attempting to add {len(chunks)} chunks to collection {COLLECTION_NAME} for user {user_id}")
    collection.add(ids=ids, documents=chunks, metadatas=metadatas)
    print(f"DEBUG: Indexed {len(chunks)} chunks for user {user_id} in collection {COLLECTION_NAME}")"""

new_index_insert = """    print(f"DEBUG: Attempting to add {len(chunks)} chunks to Postgres for user {user_id}")
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
        stmt = stmt.on_conflict_do_update(
            index_elements=['id'],
            set_=dict(
                document=stmt.excluded.document,
                embedding=stmt.excluded.embedding,
                metadata_=stmt.excluded.metadata_
            )
        )
        db.execute(stmt)
        db.commit()
    print(f"DEBUG: Indexed {len(chunks)} chunks for user {user_id} in Postgres")"""

code = code.replace(old_index_insert, new_index_insert)

# 5. delete_document
old_delete = """def delete_document(filename: str, user_id: int):
    \"\"\"Removes a document from the Brain (Vector DB) for a specific user\"\"\"
    collection = get_db_collection()
    
    # Delete based on metadata
    # ChromaDB supports deleting by 'where' clause
    print(f"DEBUG: Deleting document '{filename}' for user {user_id}")
    collection.delete(where={"$and": [{"source": filename}, {"user_id": user_id}]})"""

new_delete = """def delete_document(filename: str, user_id: int, db: Session):
    \"\"\"Removes a document from the Brain (Vector DB) for a specific user\"\"\"
    print(f"DEBUG: Deleting document '{filename}' for user {user_id}")
    db.query(BrainEmbedding).filter(
        and_(
            BrainEmbedding.metadata_.op('->>')('source') == filename,
            BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id)
        )
    ).delete(synchronize_session=False)
    db.commit()"""

code = code.replace(old_delete, new_delete)

# 6. get_bm25
old_bm25 = """def get_bm25(user_id: int):
    \"\"\"Lazy-load a per-user BM25 index — only indexes that user's documents\"\"\"
    global _bm25_models, _bm25_doc_registry, _bm25_doc_content, _bm25_doc_metadata

    if user_id not in _bm25_models:
        print(f"[INFO] Building BM25 index for user {user_id}...")
        collection = get_db_collection()

        # Fetch ONLY this user's documents
        user_docs = collection.get(where={"user_id": user_id})

        tokenized_corpus = []
        _bm25_doc_registry[user_id] = {}
        _bm25_doc_content[user_id] = {}
        _bm25_doc_metadata[user_id] = {}

        if user_docs['ids']:
            for idx, (doc_id, content, metadata) in enumerate(
                zip(user_docs['ids'], user_docs['documents'], user_docs['metadatas'])
            ):
                _bm25_doc_registry[user_id][idx] = doc_id
                _bm25_doc_content[user_id][doc_id] = content
                _bm25_doc_metadata[user_id][doc_id] = metadata
                tokenized_corpus.append(_tokenize(content))

            _bm25_models[user_id] = BM25Okapi(tokenized_corpus)
            print(f"[INFO] BM25 index built for user {user_id} with {len(tokenized_corpus)} documents")
        else:
            print(f"[WARN] No documents for user {user_id}, skipping BM25 build")
            _bm25_models[user_id] = None  # Cache the miss to avoid repeated DB calls

    return _bm25_models.get(user_id)"""

new_bm25 = """def get_bm25(user_id: int, db: Session):
    \"\"\"Lazy-load a per-user BM25 index — only indexes that user's documents\"\"\"
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

    return _bm25_models.get(user_id)"""

code = code.replace(old_bm25, new_bm25)


# 7. find_associative_memories
old_assoc = """def find_associative_memories(query: str, user_id: int, primary_context: str):
    \"\"\"Find memories that aren't directly related but resonate thematically\"\"\"
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
            associative_results.extend(results['documents'][0])"""

new_assoc = """def find_associative_memories(query: str, user_id: int, primary_context: str, db: Session):
    \"\"\"Find memories that aren't directly related but resonate thematically\"\"\"
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
        query_embedding = emb_model.encode([theme_query]).tolist()
        
        try:
            results = db.query(BrainEmbedding)\\
                .filter(BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id))\\
                .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))\\
                .limit(2).all()
                
            if results:
                for r in results:
                    associative_results.append(r.document)
        except Exception as e:
            print(e)"""

code = code.replace(old_assoc, new_assoc)

# 8. retrieve_context
old_retrieve = """def retrieve_context(query: str, user_id: int, current_location: dict = None):
    \"\"\"Retrieves relevant context using Hybrid Search (Vector + BM25) + RRF Fusion\"\"\"
    t_total_start = time.time()
    print(f"DEBUG: Entering retrieve_context for user {user_id} with query: '{query}'")
    collection = get_db_collection()
    
    # 1. VECTOR SEARCH (Dense)
    t_vec_start = time.time()
    n_results = 20 # Fetch more for fusion
    print(f"DEBUG: [Vector] Querying ChromaDB...")
    vector_results = collection.query(
        query_texts=[query], 
        n_results=n_results, 
        where={"user_id": user_id}
    )
    
    vector_candidates = [] # List of (doc_id, score)
    if vector_results['ids'] and vector_results['ids'][0]:
        vector_candidates = vector_results['ids'][0]
    print(f"DEBUG: [Timing] ChromaDB Vector Search: {(time.time() - t_vec_start)*1000:.2f} ms")
    
    # 2. KEYWORD SEARCH (Sparse - BM25)
    t_bm25_start = time.time()
    print(f"DEBUG: [BM25] Querying BM25 for user {user_id}...")
    bm25 = get_bm25(user_id)  # Per-user index — no cross-user data"""

new_retrieve = """def retrieve_context(query: str, user_id: int, db: Session, current_location: dict = None):
    \"\"\"Retrieves relevant context using Hybrid Search (Vector + BM25) + RRF Fusion\"\"\"
    t_total_start = time.time()
    print(f"DEBUG: Entering retrieve_context for user {user_id} with query: '{query}'")
    
    # 1. VECTOR SEARCH (Dense)
    t_vec_start = time.time()
    n_results = 20 # Fetch more for fusion
    print(f"DEBUG: [Vector] Querying Postgres pgvector...")
    emb_model = get_emb_fn()
    query_embedding = emb_model.encode([query]).tolist()
    
    vector_results = db.query(BrainEmbedding)\\
        .filter(BrainEmbedding.metadata_.op('->>')('user_id') == str(user_id))\\
        .order_by(BrainEmbedding.embedding.l2_distance(query_embedding))\\
        .limit(n_results).all()
        
    vector_candidates = [r.id for r in vector_results]
    print(f"DEBUG: [Timing] Postgres Vector Search: {(time.time() - t_vec_start)*1000:.2f} ms")
    
    # 2. KEYWORD SEARCH (Sparse - BM25)
    t_bm25_start = time.time()
    print(f"DEBUG: [BM25] Querying BM25 for user {user_id}...")
    bm25 = get_bm25(user_id, db)  # Per-user index — no cross-user data"""

code = code.replace(old_retrieve, new_retrieve)

old_retrieve_mid = """    if user_content:
        for doc_id in top_n_candidates:
            if doc_id in user_content:
                docs.append(user_content[doc_id])
                metadatas.append(user_meta.get(doc_id, {}))
    else:
        # Fallback if BM25 failed (shouldn't happen if we reached here with candidates)
         # Re-fetch from collection by IDs
         final_fetch = collection.get(ids=top_n_candidates)
         # Map back to sort order
         doc_map = {d_id: (doc, meta) for d_id, doc, meta in zip(final_fetch['ids'], final_fetch['documents'], final_fetch['metadatas'])}
         for doc_id in top_n_candidates:
             if doc_id in doc_map:
                 docs.append(doc_map[doc_id][0])
                 metadatas.append(doc_map[doc_id][1])"""

new_retrieve_mid = """    if user_content:
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
                 metadatas.append(doc_map[doc_id][1])"""

code = code.replace(old_retrieve_mid, new_retrieve_mid)

old_retrieve_end = """    # [Layer 3] Associative Memory
    associations = find_associative_memories(query, user_id, context_text)"""

new_retrieve_end = """    # [Layer 3] Associative Memory
    associations = find_associative_memories(query, user_id, context_text, db)"""

code = code.replace(old_retrieve_end, new_retrieve_end)

# 9. search_brain
old_search = """def search_brain(query: str, user_id: int):
    \"\"\"Retrieves context + Generates Answer (Sync)\"\"\"
    context_text, sources = retrieve_context(query, user_id)"""

new_search = """def search_brain(query: str, user_id: int, db: Session):
    \"\"\"Retrieves context + Generates Answer (Sync)\"\"\"
    context_text, sources = retrieve_context(query, user_id, db)"""

code = code.replace(old_search, new_search)

# 10. Async Wrappers
old_async = """async def async_retrieve_context(query: str, user_id: int, current_location: dict = None):
    \"\"\"Run retrieve_context in a separate thread\"\"\"
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, retrieve_context, query, user_id, current_location)

async def async_search_brain(query: str, user_id: int):
    \"\"\"Run search_brain in a separate thread\"\"\"
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, search_brain, query, user_id)

async def async_index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    \"\"\"Run index_text in a separate thread\"\"\"
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, index_text, filename, text, user_id, location_context)"""

new_async = """async def async_retrieve_context(query: str, user_id: int, current_location: dict = None):
    \"\"\"Run retrieve_context in a separate thread\"\"\"
    def _run():
        db = SessionLocal()
        try:
            return retrieve_context(query, user_id, db, current_location)
        finally:
            db.close()
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)

async def async_search_brain(query: str, user_id: int):
    \"\"\"Run search_brain in a separate thread\"\"\"
    def _run():
        db = SessionLocal()
        try:
            return search_brain(query, user_id, db)
        finally:
            db.close()
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)

async def async_index_text(filename: str, text: str, user_id: int, location_context: dict = None):
    \"\"\"Run index_text in a separate thread\"\"\"
    def _run():
        db = SessionLocal()
        try:
            return index_text(filename, text, user_id, db, location_context)
        finally:
            db.close()
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, _run)"""

code = code.replace(old_async, new_async)

with open("app/services/rag_engine_refactored.py", "w") as f:
    f.write(code)
