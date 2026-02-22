import chromadb
import os
import shutil

DB_PATH = "./test_chroma_db"

if os.path.exists(DB_PATH):
    shutil.rmtree(DB_PATH)

print(f"1. Creating ChromaDB at {DB_PATH}")
client = chromadb.PersistentClient(path=DB_PATH)

print("2. Creating collection")
collection = client.get_or_create_collection(name="test_collection")

print("3. Adding test document")
collection.add(
    ids=["doc1"],
    documents=["This is a test document to verify ChromaDB works."],
    metadatas=[{"source": "test"}]
)

print("4. Querying document")
results = collection.query(
    query_texts=["test document"],
    n_results=1
)

print("5. Results:")
print(results)

print("✅ SUCCESS! ChromaDB is fully functional in this directory.")
