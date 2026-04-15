import os
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List
from app.models import models
from app.schemas import schemas
from app.core import database
from app.core.limiter import limiter
from app.services import vault_service
from . import auth

router = APIRouter(prefix="/files", tags=["files"])
logger = logging.getLogger(__name__)


@router.get("/", response_model=List[schemas.FileResponseSchema])
@limiter.limit("60/minute")
def list_files(
    request: Request,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    try:
        return (
            db.query(models.StoredFile)
            .filter(models.StoredFile.user_id == current_user.id)
            .all()
        )
    except Exception as e:
        logger.exception("Error listing files")
        raise HTTPException(status_code=500, detail="Failed to list files.")


@router.get("/{file_id}")
@limiter.limit("60/minute")
def get_file(
    request: Request,
    file_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    stored_file = (
        db.query(models.StoredFile)
        .filter(
            models.StoredFile.id == file_id,
            models.StoredFile.user_id == current_user.id,
        )
        .first()
    )

    if not stored_file:
        raise HTTPException(status_code=404, detail="File not found")

    if stored_file.file_path:
        resolved_path = stored_file.file_path
        if resolved_path.startswith("backend/uploads/"):
            resolved_path = resolved_path.replace("backend/uploads/", "uploads/", 1)

        # Validate file still exists on disk before serving
        if not os.path.exists(resolved_path):
            logger.warning(
                "File record %d points to missing path: %s",
                file_id,
                resolved_path,
            )
            raise HTTPException(
                status_code=404, detail="File no longer available on disk"
            )
        return FileResponse(resolved_path)

    return {"content": stored_file.content_text, "filename": stored_file.filename}


@router.get("/vault/documents/{doc_id}")
@limiter.limit("60/minute")
def get_secure_document(
    request: Request,
    doc_id: int,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    try:
        file_path = vault_service.get_secure_document(
            doc_id=doc_id, user_id=current_user.id, db=db
        )
        return FileResponse(file_path)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error serving document {doc_id}")
        raise HTTPException(status_code=500, detail="Failed to serve document.")
