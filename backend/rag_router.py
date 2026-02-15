from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
import shutil
import os
from PyPDF2 import PdfReader
from sqlalchemy.orm import Session
from typing import List
from . import models, schemas, database, auth, rag_engine

router = APIRouter(prefix="/chat", tags=["chat"])

# --- RAG ENDPOINT 1: UPLOAD (The Eyes) ---
@router.post("/upload-to-brain")
async def upload_to_brain(
    file: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # 1. Save temp file to disk
    temp_path = f"temp_{current_user.id}_{file.filename}"
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    text = ""
    try:
        # 2. INTELLIGENT EXTRACTION
        filename_lower = file.filename.lower()

        if filename_lower.endswith(".pdf"):
            # Handle PDF
            reader = PdfReader(temp_path)
            for page in reader.pages: 
                text += page.extract_text() or ""
                
        elif filename_lower.endswith((".txt", ".md", ".json", ".py", ".dart", ".yaml", ".csv")):
            # Handle Text & Code Files
            with open(temp_path, "r", encoding="utf-8") as f: 
                text = f.read()
        
        else:
            # Cleanup and reject
            os.remove(temp_path)
            return {"status": "error", "message": f"File type not supported: {file.filename}"}

        # 3. Index it! (Using the engine we built)
        if not text.strip():
             os.remove(temp_path)
             return {"status": "error", "message": "File was empty or text could not be extracted."}

        # Pass user_id to engine
        num_chunks = rag_engine.index_text(file.filename, text, current_user.id)
        
        # 4. Decide Storage (Text vs Binary)
        file_path = None
        content_to_store = None
        
        UPLOAD_DIR = "backend/uploads"
        if not os.path.exists(UPLOAD_DIR):
            os.makedirs(UPLOAD_DIR)

        if filename_lower.endswith((".txt", ".md", ".json", ".py", ".dart", ".yaml", ".csv")):
            # Text File: Store content in DB, delete temp
            content_to_store = text
            if os.path.exists(temp_path):
                os.remove(temp_path)
        else:
            # Binary/PDF: Move temp to permanent storage
            final_filename = f"{current_user.id}_{file.filename}"
            final_path = os.path.join(UPLOAD_DIR, final_filename)
            shutil.move(temp_path, final_path)
            file_path = final_path
            # Text content is extracted but file is binary, so we don't store full text in DB content_text column 
            # (or we could store preview). Let's store preview.
            content_to_store = text[:5000] 

        # 5. Store File Record in DB
        new_file = models.StoredFile(
            user_id=current_user.id,
            filename=file.filename,
            file_type=file.content_type or "unknown",
            file_size=file.size if hasattr(file, 'size') else 0, # upload_file might not have size prop directly
            content_text=content_to_store,
            file_path=file_path
        )
        db.add(new_file)
        db.commit()
        db.refresh(new_file)
        
        return {
            "status": "success", 
            "message": f"Memorized {num_chunks} chunks from {file.filename}",
            "type": file.content_type,
            "file_id": new_file.id
        }
        
    except Exception as e:
        # Always cleanup temp file on error
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return {"status": "error", "message": str(e)}

# --- RAG ENDPOINT 2: CHAT (The Mouth) ---
@router.post("/chat", response_model=schemas.ChatResponse)
async def chat_endpoint(
    request: schemas.ChatRequest,
    current_user: models.User = Depends(auth.get_current_user)
):
    # Pass user_id to engine
    return rag_engine.search_brain(request.query, current_user.id)

# --- NEW ENDPOINT: LIST FILES ---
@router.get("/files", response_model=List[schemas.StoredFileResponse])
async def list_files(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    files = db.query(models.StoredFile).filter(models.StoredFile.user_id == current_user.id).all()
    return files

@router.delete("/files/{file_id}", status_code=204)
def delete_file(
    file_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    # 1. Get File Record
    file_record = db.query(models.StoredFile).filter(
        models.StoredFile.id == file_id,
        models.StoredFile.user_id == current_user.id
    ).first()

    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")

    # 2. Delete from Vector DB (The Brain)
    # We use filename as source metadata
    rag_engine.delete_document(file_record.filename, current_user.id)

    # 3. Delete from Disk (if applicable)
    if file_record.file_path and os.path.exists(file_record.file_path):
        try:
            os.remove(file_record.file_path)
        except Exception as e:
            print(f"Error deleting file from disk: {e}")

    # 4. Delete from SQL DB (The Vault)
    db.delete(file_record)
    db.commit()
    
    return None