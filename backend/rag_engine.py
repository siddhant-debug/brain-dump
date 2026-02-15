import os
import chromadb
from chromadb.utils import embedding_functions
from chromadb.utils import embedding_functions
from langchain_text_splitters import RecursiveCharacterTextSplitter, Language
import google.generativeai as genai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# --- CONFIG ---
# 1. SETUP PATHS
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Gets 'backend' folder
DB_PATH = os.path.join(BASE_DIR, "brain_storage")
COLLECTION_NAME = "my_second_brain"

# 2. LOAD SENSITIVE KEYS
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# --- CORE FUNCTIONS ---

def get_db_collection():
    """Connects to the Brain (Vector DB)"""
    client = chromadb.PersistentClient(path=DB_PATH)
    emb_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name="all-MiniLM-L6-v2"
    )
    return client.get_or_create_collection(
        name=COLLECTION_NAME, embedding_function=emb_fn
    )

def index_text(filename: str, text: str, user_id: int):
    """Memorizes a file (Chunks -> Vectors) for a specific user"""
    collection = get_db_collection()
    
    # 2. CHUNK TEXT based on file extension
    if filename.lower().endswith(".md"):
        splitter = RecursiveCharacterTextSplitter.from_language(
            language=Language.MARKDOWN, chunk_size=500, chunk_overlap=50
        )
    else:
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=500, chunk_overlap=50, separators=["\n\n", "\n", ".", " "]
        )
        
    chunks = splitter.split_text(text)
    
    # Create unique IDs (filename + chunk index + user_id)
    ids = [f"{user_id}_{filename}_{i}" for i in range(len(chunks))]
    
    # Metadata includes file type info
    metadatas = [{"source": filename, "user_id": user_id, "type": "markdown" if filename.lower().endswith(".md") else "text"} for _ in chunks]
    
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
    """Sends prompt to Gemini 2.0 with improved RAG grounding"""
    print(f"DEBUG: Entering ask_gemini with query: '{query}'")
    genai.configure(api_key=GEMINI_API_KEY)
    
    # Using stable Gemini 2.0 Flash model
    model = genai.GenerativeModel(
        'gemini-3-flash-preview',  # Fixed: was using invalid 'gemini-3-flash-preview'
        generation_config={
            "temperature": 0.3,  # Slightly higher for more natural responses
            "max_output_tokens": 1024,
        },
        system_instruction="You are an intelligent AI assistant with access to the user's personal knowledge base. Answer questions by synthesizing information from the provided context. Be conversational and helpful. If the context doesn't contain the answer, politely say you don't have that information in the knowledge base yet."
    ) 
    
    try:
        prompt = f"""
        Use the following pieces of context to answer the question at the end.
        If you don't know the answer, just say that you don't know, don't try to make up an answer.
        
        Context:
        {context}
        
        Question: {query}
        
        Answer carefully based on the notes above:"""
        
        print(f"DEBUG: Sending prompt to Gemini. Context length: {len(context)} chars.")
        response = model.generate_content(prompt)
        print(f"DEBUG: Received response from Gemini. Length: {len(response.text)} chars.")
        return response.text
    except Exception as e:
        print(f"AI Error: {e}")
        return None # Return None to trigger fallback

def search_brain(query: str, user_id: int):
    """Retrieves relevant notes for the specific user + Generates Answer"""
    print(f"DEBUG: Entering search_brain for user {user_id} with query: '{query}'")
    collection = get_db_collection()
    
    # Filter by user_id
    print(f"DEBUG: Querying ChromaDB for user {user_id} with query: '{query}'")
    results = collection.query(
        query_texts=[query], 
        n_results=3, 
        where={"user_id": user_id}
    )
    
    # 1. Check if we found anything
    if not results['documents'] or not results['documents'][0]:
        print(f"DEBUG: No documents found for query: '{query}' and user_id: {user_id}")
        return {"answer": "I don't have any notes on that yet.", "sources": []}
    
    print(f"DEBUG: Found {len(results['documents'][0])} documents for query: '{query}'")
    
    context_text = "\n\n".join(results['documents'][0])
    sources = list(set([m['source'] for m in results['metadatas'][0]]))
    
    print(f"DEBUG: Extracted context from {len(results['documents'][0])} documents. Context length: {len(context_text)} chars.")
    print(f"DEBUG: Identified sources: {sources}")
    
    # 2. Ask AI
    ai_answer = ask_gemini(context_text, query)
    
    if ai_answer:
        return {"answer": ai_answer, "sources": sources}
    else:
        # Fallback (Quota Exceeded)
        fallback = f"**AI Offline (Quota).**\nHere are the relevant notes:\n\n{context_text}"
        return {"answer": fallback, "sources": sources}