from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from . import models, schemas, database, auth

router = APIRouter(prefix="/notes", tags=["notes"])

@router.post("/", response_model=schemas.NoteResponse)
def create_note(
    note: schemas.NoteCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    db_note = models.Note(
        content=note.content,
        user_id=current_user.id
    )
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    return db_note

@router.get("/", response_model=List[schemas.NoteResponse])
def get_notes(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    notes = db.query(models.Note)\
        .filter(models.Note.user_id == current_user.id)\
        .order_by(models.Note.created_at.desc())\
        .all()
    return notes
