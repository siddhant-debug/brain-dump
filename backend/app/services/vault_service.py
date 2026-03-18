import os
import logging
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.models import models

logger = logging.getLogger(__name__)


def get_secure_document(doc_id: int, user_id: int, db: Session) -> str:
    """
    Validates ownership of a document and returns its path securely.
    """
    stored_file = (
        db.query(models.StoredFile)
        .filter(models.StoredFile.id == doc_id, models.StoredFile.user_id == user_id)
        .first()
    )

    if not stored_file:
        raise HTTPException(
            status_code=404, detail="Document not found or access denied"
        )

    if not stored_file.file_path:
        raise HTTPException(
            status_code=400, detail="Document is not a file stored on disk"
        )

    resolved_path = stored_file.file_path
    if resolved_path.startswith("backend/uploads/"):
        resolved_path = resolved_path.replace("backend/uploads/", "uploads/", 1)

    if not os.path.exists(resolved_path):
        logger.warning(
            f"File record {doc_id} points to missing path: {resolved_path}"
        )
        raise HTTPException(status_code=404, detail="File no longer available on disk")

    return resolved_path
