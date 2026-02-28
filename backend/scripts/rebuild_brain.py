import os
import sys

# Override .env before database.py loads it
os.environ["DATABASE_URL"] = "postgresql+psycopg://postgres:password123@postgres/postgres"

# Add the parent directory to sys.path so we can import 'app'
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models import models
from app.services import rag_engine

def rebuild_brain():
    print("Starting Brain Rebuild Process...")
    print(f"Using Database: {os.environ['DATABASE_URL']}")
    
    db: Session = SessionLocal()
    try:
        # 1. Fetch Users
        users = db.query(models.User).all()
        if not users:
            print("No users found in the database. Did you restore backup.sql?")
            return
            
        print(f"👥 Found {len(users)} users.")
        
        # 2. Re-index Notes
        notes = db.query(models.Note).all()
        print(f"Found {len(notes)} notes. Re-indexing...")
        for note in notes:
            try:
                rag_engine.index_text(
                    filename=f"note_{note.id}", 
                    text=note.content, 
                    user_id=note.user_id,
                    location_context=None
                )
            except Exception as e:
                print(f"  [ERROR] Failed to index note {note.id}: {e}")
                
        # 3. Re-index Files
        files = db.query(models.StoredFile).all()
        print(f"📁 Found {len(files)} uploaded files. Re-indexing...")
        for file in files:
            try:
                rag_engine.index_text(
                    filename=file.filename, 
                    text=file.content_text, 
                    user_id=file.user_id,
                    location_context=None
                )
            except Exception as e:
                print(f"  [ERROR] Failed to index file {file.id}: {e}")

        print("Brain Rebuild Complete! ChromaDB is fully restored.")
        
    finally:
        db.close()

if __name__ == "__main__":
    rebuild_brain()
