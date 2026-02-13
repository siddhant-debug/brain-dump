import os
import shutil
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List
from . import models, schemas, database, auth

router = APIRouter(prefix="/files", tags=["files"])

UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

@router.post("/upload", response_model=schemas.FileResponseSchema)
async def upload_file(
    file: UploadFile = File(...),
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    file_content = await file.read()
    file_size = len(file_content)
    file_type = file.content_type
    filename = file.filename
    
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

@router.get("/", response_model=List[schemas.FileResponseSchema])
def list_files(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    return db.query(models.StoredFile).filter(models.StoredFile.user_id == current_user.id).all()

@router.get("/{file_id}")
def get_file(
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
        return FileResponse(stored_file.file_path)
    
    return {"content": stored_file.content_text, "filename": stored_file.filename}
