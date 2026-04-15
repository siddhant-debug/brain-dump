from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Request
from sqlalchemy.orm import Session
from typing import List
import logging
from app.models import models
from app.schemas import schemas
from app.core import database
from app.core.limiter import limiter
from app.services import rag_engine
from . import auth

router = APIRouter(prefix="/notes", tags=["notes"])
logger = logging.getLogger(__name__)


def process_note_background(
    note_id: int, content: str, user_id: int, location_context: dict = None
):
    from app.core.database import SessionLocal
    from app.models import models

    bg_db = SessionLocal()
    try:
        # 2a. Run LLM Analysis for Insights
        insights = rag_engine.analyze_thought_insights(content)

        # Update the SQL note record with insights
        note_record = bg_db.query(models.Note).filter(models.Note.id == note_id).first()
        if note_record:
            note_record.sentiment = insights.get("sentiment", "Neutral")
            note_record.categories = insights.get("categories", [])
            bg_db.commit()
            logger.info("[notes] Analyzed note %d: %s", note_id, insights)

        # 2b. Index in Vector DB
        rag_engine.index_text(
            filename=f"note_{note_id}",
            text=content,
            user_id=user_id,
            db=bg_db,
            location_context=location_context,
            source_type="note",
        )
        logger.info("[notes] Indexed note %d for user %d", note_id, user_id)
    except Exception as e:
        logger.error("[notes] Failed to process note %d in background: %s", note_id, e)
        bg_db.rollback()
    finally:
        bg_db.close()


@router.post("/", response_model=schemas.NoteResponse)
@limiter.limit("30/minute")
def create_note(
    request: Request,
    note: schemas.NoteCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    # 1. Store in SQL (The Vault)
    # We try to extract context from headers or other available sources if possible, 
    # but for now we expect them to be sent or inferred.
    # Actually, we should probably pull the latest music/health context for the user.
    
    latest_health = db.query(models.HealthSnapshot).filter(models.HealthSnapshot.user_id == current_user.id).order_by(models.HealthSnapshot.fetched_at.desc()).first()
    latest_music = db.query(models.MusicHistory).filter(models.MusicHistory.user_id == current_user.id).order_by(models.MusicHistory.played_at.desc()).first()
    
    db_note = models.Note(
        content=note.content, 
        user_id=current_user.id,
        location_name=note.location.city if note.location else None,
        music_track=latest_music.title if latest_music else None,
        health_readiness=latest_health.readiness if latest_health else None
    )
    db.add(db_note)
    db.commit()
    db.refresh(db_note)

    # 1.5. Save to Chat History (DISABLED: Thoughts should be isolated from Chat)
    # try:
    #     chat_msg = models.ChatMessage(
    #         user_id=current_user.id,
    #         content=note.content,
    #         sender='user'
    #     )
    #     db.add(chat_msg)
    #     db.commit()
    # except Exception as e:
    #     print(f"[ERROR] Failed to save note to chat history: {e}")

    # 2. Index in Vector DB & Analyze (Background Task)
    # Extract location if present
    location_dict = note.location.dict() if note.location else None

    background_tasks.add_task(
        process_note_background,
        db_note.id,
        db_note.content,
        current_user.id,
        location_dict,
    )

    return db_note


@router.get("/", response_model=List[schemas.NoteResponse])
@limiter.limit("60/minute")
def get_notes(
    request: Request,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    notes = (
        db.query(models.Note)
        .filter(models.Note.user_id == current_user.id)
        .order_by(models.Note.created_at.desc())
        .all()
    )
    return notes


@router.delete("/{note_id}", status_code=204)
@limiter.limit("20/minute")
def delete_note(
    request: Request,
    note_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    note = (
        db.query(models.Note)
        .filter(models.Note.id == note_id, models.Note.user_id == current_user.id)
        .first()
    )

    if not note:
        raise HTTPException(status_code=404, detail="Note not found")

    # 1. Delete from Vector DB (The Brain)
    try:
        rag_engine.delete_document(
            filename=f"note_{note_id}", user_id=current_user.id, db=db
        )
    except Exception as e:
        logger.warning("[notes] Failed to delete note %d from vector DB: %s", note_id, e)

    # 2. Delete from SQL (The Vault)
    db.delete(note)
    db.commit()
    return None
