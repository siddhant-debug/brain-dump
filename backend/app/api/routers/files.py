import os
import logging
import shutil
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status, Request
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List
from app.models import models
from app.schemas import schemas
from app.core import database
from app.core.limiter import limiter
from . import auth

router = APIRouter(prefix="/files", tags=["files"])
logger = logging.getLogger(__name__)

UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

# 50 MB hard cap — consistent with rag.py
MAX_UPLOAD_BYTES = 50 * 1024 * 1024

@router.post("/upload", response_model=schemas.FileResponseSchema)
@limiter.limit("20/hour")
async def upload_file(
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    try:
        file_content = await file.read()
        file_size = len(file_content)

        # HIGH-1: Enforce upload size limit
        if file_size > MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="File too large. Maximum allowed size is 50 MB.")

        file_type = file.content_type
        # HIGH-2: Strip path traversal characters from user-supplied filename
        filename = Path(file.filename).name

        content_text = None
        file_path = None

        # Logic for text-based files
        if filename.endswith(('.md', '.txt')):
            try:
                content_text = file_content.decode("utf-8")
            except UnicodeDecodeError:
                raise HTTPException(status_code=400, detail="Text file must be UTF-8 encoded")
        else:
            # Logic for binary files (e.g., PDF)
            file_path = os.path.join(UPLOAD_DIR, f"{current_user.id}_{filename}")
            with open(file_path, "wb") as buffer:
                buffer.write(file_content)

        new_file = models.StoredFile(
            user_id=current_user.id,
            filename=filename,
            file_type=file_type,
            file_size=file_size,
            content_text=content_text,
            file_path=file_path
        )
        db.add(new_file)
        db.commit()
        db.refresh(new_file)

        return new_file

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error uploading file")
        raise HTTPException(status_code=500, detail="Failed to upload file.")

@router.get("/", response_model=List[schemas.FileResponseSchema])
@limiter.limit("60/minute")
def list_files(
    request: Request,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    try:
        return db.query(models.StoredFile).filter(models.StoredFile.user_id == current_user.id).all()
    except Exception as e:
        logger.exception("Error listing files")
        raise HTTPException(status_code=500, detail="Failed to list files.")

@router.get("/{file_id}")
@limiter.limit("60/minute")
def get_file(
    request: Request,
    file_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    stored_file = db.query(models.StoredFile).filter(
        models.StoredFile.id == file_id,
        models.StoredFile.user_id == current_user.id
    ).first()

    if not stored_file:
        raise HTTPException(status_code=404, detail="File not found")

    if stored_file.file_path:
        # Validate file still exists on disk before serving
        if not os.path.exists(stored_file.file_path):
            logger.warning("File record %d points to missing path: %s", file_id, stored_file.file_path)
            raise HTTPException(status_code=404, detail="File no longer available on disk")
        return FileResponse(stored_file.file_path)

    return {"content": stored_file.content_text, "filename": stored_file.filename}
