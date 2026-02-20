import sys
import os
from sqlalchemy import text, create_engine
from sqlalchemy.orm import sessionmaker

# --- SETUP PATHS ---
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from app.core.database import SQL_DB_URL
from app.services.rag_engine import index_text, delete_document

def sync_all_data():
    print("🔄 Connecting to Database...")
    engine = create_engine(SQL_DB_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    total_indexed = 0
    
    try:
        # ==========================================
        # 1. SYNC NOTES (Quick Thoughts)
        # ==========================================
        print("\n📖 [1/2] Fetching from 'notes' table...")
        # Note: If you added the 'folder' column, add it to this SELECT
        notes_query = text("SELECT id, content, user_id FROM notes") 
        notes = db.execute(notes_query).fetchall()
        
        print(f"   Found {len(notes)} notes.")
        
        for row in notes:
            # Create a virtual filename so the vector DB can track it
            virtual_filename = f"note_{row.id}.md"
            
            # Inject context tags for better retrieval
            # (You can update "Quick Note" to row.folder if you have it)
            enriched_content = f"# Context: Quick Note\n\n{row.content}"
            
            # Clean old version & Re-index
            delete_document(virtual_filename, row.user_id)
            chunks = index_text(virtual_filename, enriched_content, row.user_id)
            if chunks > 0: total_indexed += 1

        # ==========================================
        # 2. SYNC STORED FILES (PDFs/Docs)
        # ==========================================
        print("\nopen_file_folder [2/2] Fetching from 'stored_files' table...")
        files_query = text("SELECT id, filename, content_text, user_id FROM stored_files")
        files = db.execute(files_query).fetchall()
        
        print(f"   Found {len(files)} files.")
        
        for row in files:
            # Safety check: Skip files that haven't been processed (no text)
            if not row.content_text:
                print(f"   ⚠️ Skipping {row.filename} (No text content found)")
                continue
                
            # Use the actual filename
            clean_filename = row.filename
            
            # Index the raw content text
            # We assume your upload logic already extracted text from the PDF/Image
            delete_document(clean_filename, row.user_id)
            chunks = index_text(clean_filename, row.content_text, row.user_id)
            
            if chunks > 0:
                print(f"   ✅ Indexed File: {clean_filename}")
                total_indexed += 1

        print(f"\n🎉 Sync Complete! Total {total_indexed} items (Notes + Files) are now in your Brain.")
        
    except Exception as e:
        print(f"❌ Database Sync Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    sync_all_data()