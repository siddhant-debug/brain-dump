from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    File,
    UploadFile,
    BackgroundTasks,
    Request,
)
import asyncio
import shutil
import os
import uuid
import logging
from pathlib import Path
from sqlalchemy.orm import Session
from typing import List
from app.models import models
from app.schemas import schemas
from app.core import database
from app.services import rag_engine, reflection_engine
from app.core.limiter import limiter
from . import auth

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/chat", tags=["chat"])

import mimetypes

# 10 MB limit for beta
MAX_UPLOAD_BYTES = 10 * 1024 * 1024

ALLOWED_MIMETYPES = {
    "application/pdf",
    "text/plain",
    "text/markdown",
    "text/csv",
    "application/json",
}


# ---------------------------------------------------------------------------
# M-1 FIX: Session helper — always releases the connection via context manager
# ---------------------------------------------------------------------------
def _save_message(
    user_id: int, content: str, sender: str, sources: list | None = None
) -> None:
    """Persists a chat message. Opens and closes its own session safely."""
    import json

    db = database.SessionLocal()
    try:
        msg = models.ChatMessage(
            user_id=user_id,
            content=content,
            sender=sender,
            context_sources=json.dumps(sources) if sources else None,
        )
        db.add(msg)
        db.commit()
    except Exception as exc:
        logger.error(
            "[_save_message] Failed to persist message: %s", exc, exc_info=True
        )
        db.rollback()
    finally:
        db.close()  # ALWAYS runs — prevents connection leak


# ---------------------------------------------------------------------------
# BACKGROUND PROCESSING HELPER
# ---------------------------------------------------------------------------
def _process_file_background(user_id: int, file_id: int, safe_filename: str, temp_path: str, is_pdf: bool, final_path: str):
    """Background task to extract text and index document to vector DB."""
    from app.core.database import SessionLocal
    from PyPDF2 import PdfReader
    import logging
    import asyncio
    
    bg_logger = logging.getLogger(__name__)
    db = SessionLocal()
    try:
        text = ""
        # The file is currently at temp_path
        if is_pdf:
            bg_logger.debug("[BG] Extracting text from PDF: %s", temp_path)
            reader = PdfReader(temp_path)
            for page in reader.pages:
                text += page.extract_text() or ""
        else:
            bg_logger.debug("[BG] Extracting text from file: %s", temp_path)
            with open(temp_path, "r", encoding="utf-8") as f:
                text = f.read()

        if not text.strip():
            bg_logger.debug("[BG] File was empty after extraction")
            return

        bg_logger.debug("[BG] Indexing text into RAG engine...")
        # Create a new event loop for async rag engine tasks if running in thread
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            num_chunks = loop.run_until_complete(
                rag_engine.async_index_text(safe_filename, text, user_id, source_type="file")
            )
            bg_logger.debug("[BG] Indexed %d chunks", num_chunks)
        finally:
            loop.close()

        # Update the stored file with actual content
        file_record = db.query(models.StoredFile).filter(models.StoredFile.id == file_id).first()
        if file_record:
            if is_pdf:
                # Move temp to final path
                shutil.move(temp_path, final_path)
                file_record.file_path = final_path
                file_record.content_text = text[:5000]
            else:
                file_record.content_text = text
                # We can remove temp_path for text since we store content in DB
                os.remove(temp_path)
            db.commit()

        bg_logger.info("[BG] File upload complete — %d chunks, %d chars", num_chunks, len(text))

    except Exception as e:
        bg_logger.error("[BG] Error processing file: %s", e, exc_info=True)
        db.rollback()
        # Clean up if failed
        if os.path.exists(temp_path):
            os.remove(temp_path)
    finally:
        db.close()


# --- RAG ENDPOINT 1: UPLOAD (The Eyes) ---
@router.post("/upload-to-brain")
@limiter.limit("20/hour")
async def upload_to_brain(
    request: Request,
    file: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
    background_tasks: BackgroundTasks = None,
):
    logger.info("[upload] Started for user %d — file=%s type=%s", current_user.id, file.filename, file.content_type)

    # 1. Enforce upload size limit (10MB) via streaming size check
    # We do not read the whole file into memory. We chunk it.
    file_size = 0
    safe_filename = Path(file.filename).name
    temp_path = f"temp_{current_user.id}_{safe_filename}"
    
    logger.debug("[upload] Streaming file to temp path: %s", temp_path)
    
    with open(temp_path, "wb") as buffer:
        while True:
            chunk = await file.read(1024 * 1024)  # 1MB chunks
            if not chunk:
                break
            file_size += len(chunk)
            if file_size > MAX_UPLOAD_BYTES:
                buffer.close()
                os.remove(temp_path)
                raise HTTPException(
                    status_code=413, detail="File too large. Maximum allowed size is 10 MB."
                )
            buffer.write(chunk)
            
    logger.debug("[upload] File streamed to disk — size=%d bytes", file_size)

    # 2. Validate MIME type
    content_type = file.content_type
    if not content_type or content_type not in ALLOWED_MIMETYPES:
        guessed_type, _ = mimetypes.guess_type(file.filename)
        if not guessed_type or guessed_type not in ALLOWED_MIMETYPES:
            os.remove(temp_path)
            raise HTTPException(
                status_code=415,
                detail="Unsupported file type. Allowed: PDF, TXT, MD, CSV, JSON.",
            )
        content_type = guessed_type

    filename_lower = safe_filename.lower()
    is_pdf = filename_lower.endswith(".pdf")
    
    UPLOAD_DIR = "uploads"
    if not os.path.exists(UPLOAD_DIR):
        os.makedirs(UPLOAD_DIR)
        
    final_path = os.path.join(UPLOAD_DIR, f"{current_user.id}_{safe_filename}")

    # 3. Save initial record to DB (sync)
    logger.debug("[upload] Storing initial file record in DB...")
    def _db_ops():
        new_file = models.StoredFile(
            user_id=current_user.id,
            filename=safe_filename,
            file_type=content_type,
            file_size=file_size,
            content_text="Processing...", # Placeholder until background task completes
            file_path=None,
        )
        db.add(new_file)
        db.commit()
        db.refresh(new_file)
        return new_file.id

    loop = asyncio.get_event_loop()
    new_file_id = await loop.run_in_executor(None, _db_ops)
    logger.debug("[upload] File record saved — id=%s", new_file_id)

    # 4. Dispatch Background Task
    background_tasks.add_task(
        _process_file_background,
        user_id=current_user.id,
        file_id=new_file_id,
        safe_filename=safe_filename,
        temp_path=temp_path,
        is_pdf=is_pdf,
        final_path=final_path
    )
    
    logger.debug("[upload] Offloaded extraction and indexing to BackgroundTasks")

    return {
        "status": "processing",
        "message": f"Successfully started analyzing {safe_filename}",
        "file_id": new_file_id,
        "type": content_type,
    }


def extract_and_save_identity(user_id: int, message_content: str):
    """Background task to extract user facts or behavioral directives."""
    import json
    import os
    from google import genai
    from google.genai import types
    from datetime import datetime
    import uuid

    # Use the top-level rag_engine import to ensure singleton consistency
    get_emb_fn = rag_engine.get_emb_fn
    _rag_service = rag_engine._rag_service

    db = database.SessionLocal()
    try:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return

        client = genai.Client(api_key=api_key)

        prompt = f"Message: {message_content}"
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,
                response_mime_type="application/json",
                system_instruction="""Analyze the user's message and determine if it contains a persistent Fact (e.g. "My name is Sid") or a Behavioral Directive (e.g. "Ask me about the gym every day").
            Return JSON: {"type": "fact" | "directive" | "none", "content": "Extracted fact/directive or empty"}""",
            ),
        )
        result = json.loads(response.text)

        if result.get("type") == "fact" and result.get("content"):
            content = result["content"]
            emb_model = get_emb_fn()
            embedding = emb_model.encode([content]).tolist()[0]

            fact_id = f"{user_id}_fact_{uuid.uuid4().hex[:8]}"
            meta = {
                "source": "user_identity",
                "user_id": user_id,
                "type": "user_identity",
                "timestamp": datetime.now().isoformat(),
            }
            new_fact = models.BrainEmbedding(
                id=fact_id,
                user_id=user_id,
                document=content,
                embedding=embedding,
                metadata_=meta,
                source_type="user_identity",
            )
            db.add(new_fact)
            db.commit()

            # Invalidate BM25 cache
            _rag_service.bm25_store.invalidate(user_id)
            logger.info(f"[Identity] Saved new fact: {content}")

        elif result.get("type") == "directive" and result.get("content"):
            content = result["content"]
            new_directive = models.UserDirective(
                user_id=user_id, directive_content=content, is_active=True
            )
            db.add(new_directive)
            db.commit()
            logger.info(f"[Identity] Saved new directive: {content}")

    except Exception as e:
        logger.error(f"[extract_and_save_identity] Error: {e}")
        db.rollback()
    finally:
        db.close()


# --- RAG ENDPOINT 2: CHAT (The Mouth) ---
@router.post("/chat")
@limiter.limit("60/hour")
async def chat_endpoint(
    request: Request,
    request_body: schemas.ChatRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Streaming chat endpoint - returns Server-Sent Events (SSE)"""

    logger.info("[chat] Query started — user_id=%d query_len=%d chars", current_user.id, len(request_body.query))

    # 1. Save User Message to History using the _save_message helper (M-1 fix)
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(
        None, _save_message, current_user.id, request_body.query, "user"
    )

    # 2. Extract facts/directives in the background
    background_tasks.add_task(
        extract_and_save_identity, current_user.id, request_body.query
    )

    # 3. Retrieve short-term memory (last 8-10 messages)
    def _fetch_history_and_directives():
        _history = (
            db.query(models.ChatMessage)
            .filter(
                models.ChatMessage.user_id == current_user.id,
                # Exclude the message we just saved to avoid duplication in prompt context
                models.ChatMessage.content != request_body.query,
            )
            .order_by(models.ChatMessage.timestamp.desc())
            .limit(10)
            .all()
        )
        _directives = (
            db.query(models.UserDirective)
            .filter(
                models.UserDirective.user_id == current_user.id,
                models.UserDirective.is_active == True,
            )
            .all()
        )
        return _history, _directives

    history_messages, active_directives = await loop.run_in_executor(
        None, _fetch_history_and_directives
    )

    # Exclude the message we just saved (already filtered at DB level via the query below)
    # history already comes back oldest→newest from the DB (ASC order)
    history_messages = history_messages[::-1]  # flip DESC→ASC for chronological display
    chat_history_list = [
        {"sender": msg.sender, "content": msg.content} for msg in history_messages
    ]

    directives_list = [d.directive_content for d in active_directives]

    async def event_generator():
        """Generator that yields SSE-formatted chunks"""
        try:
            # 0. Immediate Keep-Alive Ping for Android Client Timeouts
            logger.debug("[chat] Sending keep-alive ping")
            import json

            yield f"data: {json.dumps({'chunk': '', 'done': False, 'status': 'processing'})}\n\n"

            # 1. Search for context (Async & Non-Blocking)
            logger.debug("[chat] Searching brain for relevant context")

            # Extract location if present
            location_dict = (
                request_body.location.dict() if request_body.location else None
            )

            context_text, sources = await rag_engine.async_retrieve_context(
                request_body.query, current_user.id, current_location=location_dict
            )

            if not context_text:
                logger.debug("[chat] No documents found for query")

                fallback = "I don't have any notes on that yet."
                yield f"data: {json.dumps({'chunk': fallback, 'done': True, 'sources': []})}\n\n"
                return

            logger.debug("[chat] Found relevant context — %d chars", len(context_text))

            # Extract music layer if present and enrich with VAD Mood Vector
            music_layer = ""
            if request_body.music_context:
                mc = request_body.music_context
                primary_tone = mc.get("primary_tone", "Unknown")
                short_desc = mc.get("short_description", "")
                valence = float(mc.get("valence") or 0.0)
                arousal = float(mc.get("arousal") or 0.0)
                dominance = float(mc.get("dominance") or 0.0)

                # Translate VAD numbers to human-readable mood signals
                def _vad_label(value: float, pos: str, neg: str) -> str:
                    if value > 0.4:
                        return f"very {pos}"
                    elif value > 0.1:
                        return pos
                    elif value < -0.4:
                        return f"very {neg}"
                    elif value < -0.1:
                        return neg
                    return "neutral"

                val_label = _vad_label(
                    valence, "positive/joyful", "negative/melancholic"
                )
                aro_label = _vad_label(arousal, "energized/intense", "calm/low-energy")
                dom_label = _vad_label(
                    dominance, "confident/in-control", "reflective/vulnerable"
                )

                vad_summary = f"Emotional state: {val_label} mood, {aro_label}, feeling {dom_label}."

                if mc.get("is_playing_now") and mc.get("current_song"):
                    song_name = mc["current_song"].get("title", "")
                    music_layer = (
                        f"MUSIC CONTEXT: Currently playing '{song_name}'. "
                        f"Tone: {primary_tone} — {short_desc}. "
                        f"{vad_summary} "
                        f"Adjust your tone and retrieval weighting accordingly."
                    )
                elif primary_tone and primary_tone != "Unknown":
                    music_layer = (
                        f"MUSIC CONTEXT: Recently played tracks have a '{primary_tone}' vibe — {short_desc}. "
                        f"{vad_summary} "
                        f"Let this color how you surface and frame their memories."
                    )

            # 2b. Add Health Layer
            health_layer = ""
            health_snapshot = None
            if request_body.health_context:
                health_snapshot = request_body.health_context
            else:
                # Pull latest from DB
                db_snapshot = (
                    db.query(models.HealthSnapshot)
                    .filter(models.HealthSnapshot.user_id == current_user.id)
                    .order_by(models.HealthSnapshot.fetched_at.desc())
                    .first()
                )
                if db_snapshot:
                    health_snapshot = {
                        "readiness": db_snapshot.readiness,
                        "steps_today": db_snapshot.steps_today,
                        "active_energy_kcal": db_snapshot.active_energy_kcal,
                        "hr_resting": (
                            db_snapshot.heart_rate.get("resting")
                            if db_snapshot.heart_rate
                            else None
                        ),
                        "hrv_curr": (
                            db_snapshot.hrv.get("current") if db_snapshot.hrv else None
                        ),
                    }

            if health_snapshot:
                readiness = health_snapshot.get("readiness", "Unknown")
                steps = health_snapshot.get("steps_today", 0)
                kcal = health_snapshot.get("active_energy_kcal", 0.0)
                hr_resting = health_snapshot.get("hr_resting")
                hrv = health_snapshot.get("hrv_curr")

                health_layer = f"HEALTH CONTEXT: User's readiness is {readiness}. Steps today: {steps}. Active energy: {kcal} kcal."
                if hr_resting:
                    health_layer += f" Resting HR: {hr_resting} bpm."
                if hrv:
                    health_layer += f" Current HRV: {hrv} ms."
                health_layer += " Use this biometric data to ground your responses in their physical reality."

            # 3. Stream AI response
            full_response = ""
            async for chunk in rag_engine.ask_gemini_stream_async(
                context_text,
                request_body.query,
                current_user.id,
                location_context=location_dict,
                music_layer=music_layer,
                health_layer=health_layer,
                chat_history=chat_history_list,
                directives=directives_list,
            ):
                if chunk is None:
                    # Error occurred
                    fallback = f"**AI Offline.**\n\nHere are the relevant notes:\n\n{context_text}"
                    yield f"data: {{'chunk': '{fallback}', 'done': true}}\n\n"
                    return

                full_response += chunk
                # Send chunk as SSE

                yield f"data: {json.dumps({'chunk': chunk, 'done': False})}\n\n"

            # 4. Send final message with sources

            yield f"data: {json.dumps({'chunk': '', 'done': True, 'sources': sources})}\n\n"

            logger.info(
                "[chat] Streaming complete. Total length: %d chars",
                len(full_response),
            )

            # 5. Save AI Response to History (M-1 fix — uses _save_message helper)
            _save_message(current_user.id, full_response, "ai", sources)

        except Exception as e:
            # H-7 FIX: Never send raw exception details to the client.
            # Log the full traceback server-side with a reference code instead.
            err_ref = uuid.uuid4().hex[:8]
            logger.error(
                "[chat] SSE stream error [ref:%s]: %s",
                err_ref,
                e,
                exc_info=True,
            )

            yield f"data: {json.dumps({'error': f'Something went wrong. If this persists, restart the app. [ref: {err_ref}]', 'done': True})}\n\n"

    from fastapi.responses import StreamingResponse

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


# --- NEW ENDPOINT: LIST FILES ---
@router.get("/files", response_model=List[schemas.StoredFileResponse])
def list_files(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    # Issue 5 fix: always return newest-first so the client sees a stable, deterministic order
    files = (
        db.query(models.StoredFile)
        .filter(models.StoredFile.user_id == current_user.id)
        .order_by(models.StoredFile.id.desc())
        .all()
    )
    return files


@router.get("/history", response_model=List[schemas.ChatMessageResponse])
def get_chat_history(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
    limit: int = 50,
    offset: int = 0,
):
    """Retrieve chat history for the current user in chronological (oldest-first) order."""
    limit = min(limit, 100)  # MED-3: hard cap — client cannot exceed 100
    # Issue 1 fix: ORDER BY ASC at the DB level — no Python reversal needed
    messages = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.user_id == current_user.id)
        .order_by(models.ChatMessage.timestamp.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return messages


@router.delete("/files/{file_id}", status_code=204)
def delete_file(
    file_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    # 1. Get File Record
    file_record = (
        db.query(models.StoredFile)
        .filter(
            models.StoredFile.id == file_id,
            models.StoredFile.user_id == current_user.id,
        )
        .first()
    )

    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")

    # 2. Delete from Vector DB (The Brain)
    # We use filename as source metadata
    rag_engine.delete_document(file_record.filename, current_user.id, db)

    # 3. Delete from Disk (if applicable)
    if file_record.file_path:
        resolved_path = file_record.file_path
        if resolved_path.startswith("backend/uploads/"):
            resolved_path = resolved_path.replace("backend/uploads/", "uploads/", 1)
            
        if os.path.exists(resolved_path):
            try:
                os.remove(resolved_path)
            except Exception as e:
                logger.error("[files] Error deleting file from disk: %s", e)

    # 4. Delete from SQL DB (The Vault)
    db.delete(file_record)
    db.commit()

    return None


@router.post("/end-session")
async def end_chat_session(
    background_tasks: BackgroundTasks,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    """
    Called when a user leaves the chat screen or manually ends a session.
    Triggers the Reflection Engine to synthesize episodic memory.
    """
    logger.info(f"End session signal received for user {current_user.id}")

    async def _run_reflection():
        from app.core.database import SessionLocal

        bg_db = SessionLocal()
        try:
            engine = reflection_engine.ReflectionEngine(bg_db)
            await engine.reflect_on_session(current_user.id)
        finally:
            bg_db.close()

    background_tasks.add_task(_run_reflection)

    return {"status": "accepted", "message": "Reflection triggered"}
