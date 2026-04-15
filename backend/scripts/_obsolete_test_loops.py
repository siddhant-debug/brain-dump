import os
import sys

# Setup path so app modules can be imported
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import models
from app.services import rag_engine

from app.core.database import SessionLocal

db = SessionLocal()

# Find users with notes
users = db.query(models.User).all()
found_user = None
for u in users:
    note_count = db.query(models.Note).filter(models.Note.user_id == u.id).count()
    if note_count >= 10:
        found_user = u
        print(f"Found active User: {u.email} (ID: {u.id}) with {note_count} total notes.")
        break
        
if not found_user:
    print("No user found with >= 10 notes.")
    sys.exit()

user = found_user

notes = db.query(models.Note).filter(models.Note.user_id == user.id).all()
print(f"Total Notes: {len(notes)}")

valid_notes = [n for n in notes if n.content and len(n.content.strip()) >= 40]
print(f"Notes >= 40 chars (valid for loops): {len(valid_notes)}")

if not valid_notes:
    print("Not enough valid notes.")
    sys.exit()

rag_engine.initialize_models()
collection = rag_engine.get_db_collection()

query_texts = [n.content for n in valid_notes]
results = collection.query(
    query_texts=query_texts,
    n_results=min(5, len(valid_notes)),
    where={"user_id": user.id},
    include=["metadatas", "distances", "documents"],
)

print("\n--- DISTANCE ANALYSIS ---")
for i, note in enumerate(valid_notes):
    print(f"\nQuery Note [{note.id}]: {note.content[:50].replace(chr(10), ' ')}...")
    distances = results["distances"][i]
    docs = results["documents"][i]
    metas = results["metadatas"][i] if "metadatas" in results and results["metadatas"] else []
    for j, dist in enumerate(distances):
        neighbor_id = metas[j].get('note_id', 'unknown') if metas and j < len(metas) else 'unknown'
        if str(neighbor_id) != str(note.id):
            print(f"  -> Dist: {dist:.4f} | Note {neighbor_id}: {docs[j][:50].replace(chr(10), ' ')}...")

