import os
import sys

# Add backend directory to Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.models import Note, StoredFile, BrainEmbedding
from app.services import rag_engine

def reindex_all_data():
    db = SessionLocal()
    try:
        print("Starting Re-index of all Notes and Stored Files into pgvector...")
        
        # 1. Reindex Notes
        notes = db.query(Note).all()
        print(f"Found {len(notes)} notes.")
        for count, note in enumerate(notes, 1):
            filename = f"note_{note.id}"
            
            # Check if already indexed (optional, but good for idempotency)
            exists = db.query(BrainEmbedding).filter(
                BrainEmbedding.metadata_.op('->>')('source') == filename,
                BrainEmbedding.metadata_.op('->>')('user_id') == str(note.user_id)
            ).first()
            
            if not exists:
                print(f"Indexing Note {count}/{len(notes)} (ID: {note.id}) for User {note.user_id}...")
                rag_engine.index_text(
                    filename=filename,
                    text=note.content,
                    user_id=note.user_id,
                    db=db
                )
            else:
                print(f"Skipping Note {count}/{len(notes)} (Already indexed)")

        # 2. Reindex Stored Files
        files = db.query(StoredFile).all()
        print(f"\nFound {len(files)} stored files.")
        for count, file in enumerate(files, 1):
            exists = db.query(BrainEmbedding).filter(
                BrainEmbedding.metadata_.op('->>')('source') == file.filename,
                BrainEmbedding.metadata_.op('->>')('user_id') == str(file.user_id)
            ).first()
            
            if not exists and file.content_text:
                print(f"Indexing File {count}/{len(files)} ({file.filename}) for User {file.user_id}...")
                rag_engine.index_text(
                    filename=file.filename,
                    text=file.content_text,
                    user_id=file.user_id,
                    db=db
                )
            else:
                reason = "Already indexed" if exists else "No textual content extracted"
                print(f"Skipping File {count}/{len(files)} ({file.filename}) - {reason}")
                
        print("\nRe-indexing Complete!")
        
    except Exception as e:
        print(f"Error during re-indexing: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    reindex_all_data()
