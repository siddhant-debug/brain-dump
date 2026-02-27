from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, BackgroundTasks, Request
import shutil
import os
from pathlib import Path
from PyPDF2 import PdfReader
from sqlalchemy.orm import Session
from typing import List
from app.models import models
from app.schemas import schemas
from app.core import database
from app.services import rag_engine
from app.core.limiter import limiter
from . import auth

router = APIRouter(prefix="/chat", tags=["chat"])

import mimetypes

# 10 MB limit for beta
MAX_UPLOAD_BYTES = 10 * 1024 * 1024

ALLOWED_MIMETYPES = {
    'application/pdf', 
    'text/plain', 
    'text/markdown', 
    'text/csv', 
    'application/json'
}

# --- RAG ENDPOINT 1: UPLOAD (The Eyes) ---
@router.post("/upload-to-brain")
@limiter.limit("20/hour")
async def upload_to_brain(
    request: Request,
    file: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
    background_tasks: BackgroundTasks = None
):
    print(f"\n{'='*60}")
    print(f"[DEBUG] NOTE UPLOAD STARTED (BACKGROUND MODE)")
    print(f"[DEBUG] User: {current_user.email} (ID: {current_user.id})")
    print(f"[DEBUG] Filename: {file.filename}")
    print(f"[DEBUG] Content Type: {file.content_type}")
    print(f"{'='*60}\n")
    
    # 1. Enforce upload size limit (10MB) before saving to disk
    file_content = await file.read()
    file_size = len(file_content)
    if file_size > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File too large. Maximum allowed size is 10 MB.")

    # 2. Validate MIME type
    content_type = file.content_type
    if not content_type or content_type not in ALLOWED_MIMETYPES:
        guessed_type, _ = mimetypes.guess_type(file.filename)
        if not guessed_type or guessed_type not in ALLOWED_MIMETYPES:
            raise HTTPException(status_code=415, detail=f"Unsupported file type. Allowed: PDF, TXT, MD, CSV, JSON.")
        content_type = guessed_type

    # 3. Binary check for text files
    if content_type.startswith('text/') or content_type == 'application/json':
        if b'\x00' in file_content:
            raise HTTPException(status_code=400, detail="Corrupted or invalid text file.")
        
    # 4. Save temp file to disk — sanitize filename to prevent path traversal
    safe_filename = Path(file.filename).name
    temp_path = f"temp_{current_user.id}_{safe_filename}"
    print(f"[DEBUG] Milestone 1: Saving to temp path: {temp_path}")
    with open(temp_path, "wb") as buffer:
        buffer.write(file_content)
    print(f"[DEBUG] Milestone 1 Complete: File saved to disk")

    # 2. Process file — temp file is ALWAYS cleaned up in finally block
    try:
        text = ""
        filename_lower = safe_filename.lower()

        if filename_lower.endswith(".pdf"):
            print(f"[DEBUG] Milestone 2: Extracting text from PDF...")
            reader = PdfReader(temp_path)
            for page in reader.pages:
                text += page.extract_text() or ""
            print(f"[DEBUG] Milestone 2 Complete: Extracted {len(text)} characters")

        elif filename_lower.endswith((".txt", ".md", ".json", ".py", ".dart", ".yaml", ".csv")):
            print(f"[DEBUG] Milestone 2: Extracting text from text file...")
            with open(temp_path, "r", encoding="utf-8") as f:
                text = f.read()
            print(f"[DEBUG] Milestone 2 Complete: Extracted {len(text)} characters")

        else:
            print(f"[DEBUG] File type not supported: {safe_filename}")
            raise HTTPException(status_code=400, detail="File type not supported")

        if not text.strip():
            print(f"[DEBUG] File was empty")
            raise HTTPException(status_code=400, detail="File was empty")

        print(f"[DEBUG] Milestone 3: Indexing text into RAG engine...")
        num_chunks = rag_engine.index_text(safe_filename, text, current_user.id, db)
        print(f"[DEBUG] Milestone 3 Complete: Indexed {num_chunks} chunks")

        file_path = None
        content_to_store = None

        UPLOAD_DIR = "backend/uploads"
        if not os.path.exists(UPLOAD_DIR):
            os.makedirs(UPLOAD_DIR)

        if filename_lower.endswith((".txt", ".md", ".json", ".py", ".dart", ".yaml", ".csv")):
            content_to_store = text
            # Temp file will be cleaned up in finally block
        else:
            # Binary/PDF: Move temp to permanent storage
            final_filename = f"{current_user.id}_{safe_filename}"
            final_path = os.path.join(UPLOAD_DIR, final_filename)
            shutil.move(temp_path, final_path)
            temp_path = None  # Already moved — don't delete in finally
            file_path = final_path
            content_to_store = text[:5000]

        print(f"[DEBUG] Milestone 4: Storing file record in database...")
        new_file = models.StoredFile(
            user_id=current_user.id,
            filename=safe_filename,
            file_type=file.content_type or "unknown",
            file_size=file.size if hasattr(file, 'size') else 0,
            content_text=content_to_store,
            file_path=file_path
        )
        db.add(new_file)
        db.commit()
        db.refresh(new_file)
        print(f"[DEBUG] Milestone 4 Complete: File record saved (ID: {new_file.id})")

        print(f"[DEBUG] NOTE UPLOAD COMPLETE — {num_chunks} chunks, {len(text)} chars")

        return {
            "status": "completed",
            "message": f"Successfully memorized {safe_filename}",
            "file_id": new_file.id,
            "type": file.content_type
        }

    except HTTPException:
        raise  # Re-raise HTTP exceptions as-is (don't wrap in 500)
    except Exception as e:
        print(f"[DEBUG] ERROR during processing: {type(e).__name__}")
        raise HTTPException(status_code=500, detail="An internal error occurred.")
    finally:
        # Guaranteed cleanup — runs even on crashes, kills, and exceptions
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

# --- RAG ENDPOINT 2: CHAT (The Mouth) ---
@router.post("/chat")
@limiter.limit("60/hour")
async def chat_endpoint(
    request: Request,
    request_body: schemas.ChatRequest,
    current_user: models.User = Depends(auth.get_current_user)
):
    """Streaming chat endpoint - returns Server-Sent Events (SSE)"""
    import time
    t_chat_start = time.time()
    print(f"\n{'='*60}")
    print(f"[DEBUG] CHAT QUERY STARTED (STREAMING)")
    print(f"[DEBUG] User ID: {current_user.id}")            # email omitted (PII)
    print(f"[DEBUG] Query length: {len(request_body.query)} chars")  # content omitted (PII)
    print(f"{'='*60}\n")
    
    # 1. Save User Message to History using a short-lived session
    try:
        db = database.SessionLocal()
        user_msg = models.ChatMessage(
            user_id=current_user.id,
            content=request_body.query,
            sender='user'
        )
        db.add(user_msg)
        db.commit()
    except Exception as e:
        print(f"[ERROR] Failed to save user message: {e}")
    finally:
        if 'db' in locals():
            db.close()
    
    async def event_generator():
        """Generator that yields SSE-formatted chunks"""
        try:
            # 0. Immediate Keep-Alive Ping for Android Client Timeouts
            print(f"[DEBUG] Sending immediate keep-alive ping to client...")
            import json
            yield f"data: {json.dumps({'chunk': '', 'done': False, 'status': 'processing'})}\n\n"

            # 1. Search for context (Async & Non-Blocking)
            print(f"[DEBUG] Searching brain for relevant context...")
            
            # Extract location if present
            location_dict = request_body.location.dict() if request_body.location else None
            
            context_text, sources = await rag_engine.async_retrieve_context(request_body.query, current_user.id, current_location=location_dict)
            
            if not context_text:
                print(f"[DEBUG] No documents found for query")
                import json
                fallback = "I don't have any notes on that yet."
                yield f"data: {json.dumps({'chunk': fallback, 'done': True, 'sources': []})}\n\n"
                return
            
            print(f"[DEBUG] Found relevant context. Length: {len(context_text)} chars")
            
            # 3. Stream AI response
            full_response = ""
            async for chunk in rag_engine.ask_gemini_stream_async(context_text, request_body.query, location_context=location_dict):
                if chunk is None:
                    # Error occurred
                    fallback = f"**AI Offline.**\n\nHere are the relevant notes:\n\n{context_text}"
                    yield f"data: {{'chunk': '{fallback}', 'done': true}}\n\n"
                    return
                
                full_response += chunk
                # Send chunk as SSE
                import json
                yield f"data: {json.dumps({'chunk': chunk, 'done': False})}\n\n"
            
            # 4. Send final message with sources
            import json
            yield f"data: {json.dumps({'chunk': '', 'done': True, 'sources': sources})}\n\n"
            
            print(f"[DEBUG] Streaming complete. Total length: {len(full_response)} chars")
            print(f"[DEBUG] [Timing] Total chat_endpoint duration: {(time.time() - t_chat_start)*1000:.2f} ms")
            print(f"{'='*60}\n")
            
            # 5. Save AI Response to History
            try:
                # Use new session for async generator context
                db_session = database.SessionLocal()
                ai_msg = models.ChatMessage(
                    user_id=current_user.id,
                    content=full_response,
                    sender='ai',
                    context_sources=json.dumps(sources) if sources else None
                )
                db_session.add(ai_msg)
                db_session.commit()
                db_session.close()
                print(f"[DEBUG] Saved AI response to history")
            except Exception as e:
                print(f"[ERROR] Failed to save AI message: {e}")
            
        except Exception as e:
            print(f"[DEBUG] Streaming error: {type(e).__name__} - {str(e)}")
            import json
            yield f"data: {json.dumps({'error': f'An internal error occurred: {str(e)}', 'done': True})}\n\n"
    
    from fastapi.responses import StreamingResponse
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


# --- NEW ENDPOINT: LIST FILES ---
@router.get("/files", response_model=List[schemas.StoredFileResponse])
async def list_files(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    files = db.query(models.StoredFile).filter(models.StoredFile.user_id == current_user.id).all()
    return files

@router.get("/history", response_model=List[schemas.ChatMessageResponse])
def get_chat_history(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
    limit: int = 50,
    offset: int = 0
):
    """Retrieve chat history for the current user"""
    limit = min(limit, 100)  # MED-3: hard cap — client cannot exceed 100
    messages = db.query(models.ChatMessage).filter(
        models.ChatMessage.user_id == current_user.id
    ).order_by(models.ChatMessage.timestamp.desc()).offset(offset).limit(limit).all()

    # Return in chronological order
    return messages[::-1]

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
    rag_engine.delete_document(file_record.filename, current_user.id, db)

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