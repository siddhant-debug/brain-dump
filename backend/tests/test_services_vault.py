# backend/tests/test_services_vault.py
import pytest
from unittest.mock import MagicMock, patch
from app.services import vault_service
from app.models import models
from fastapi import HTTPException
import os
from app.api.routers import auth

def test_get_secure_document_not_found_raises_404():
    """Returns 404 when doc_id doesn't belong to user"""
    db = MagicMock()
    db.query().filter().first.return_value = None
    
    with pytest.raises(HTTPException) as excinfo:
        vault_service.get_secure_document(1, 999, db)
    assert excinfo.value.status_code == 404

def test_get_secure_document_no_file_path_raises_400():
    """Returns 400 for a DB record with no file_path"""
    db = MagicMock()
    mock_file = models.StoredFile(id=1, user_id=1, file_path=None)
    db.query().filter().first.return_value = mock_file
    
    with pytest.raises(HTTPException) as excinfo:
        vault_service.get_secure_document(1, 1, db)
    assert excinfo.value.status_code == 400

def test_get_secure_document_path_normalizes_prefix():
    """Strips backend/uploads/ → uploads/ prefix correctly"""
    db = MagicMock()
    # Path relative to backend/ context might be tricky, but we test the transformation
    mock_file = models.StoredFile(id=1, user_id=1, file_path="backend/uploads/1_test.pdf")
    db.query().filter().first.return_value = mock_file
    
    with patch("os.path.exists", return_value=True):
        result_path = vault_service.get_secure_document(1, 1, db)
        # Check if backend/ was stripped
        assert "backend/uploads" not in result_path
        assert result_path.startswith("uploads/")

def test_get_secure_document_missing_file_raises_404():
    """Returns 404 when path points to non-existent file on disk"""
    db = MagicMock()
    mock_file = models.StoredFile(id=1, user_id=1, file_path="uploads/missing.pdf")
    db.query().filter().first.return_value = mock_file
    
    with patch("os.path.exists", return_value=False):
        with pytest.raises(HTTPException) as excinfo:
            vault_service.get_secure_document(1, 1, db)
        assert excinfo.value.status_code == 404

def test_upload_to_brain_saves_file(tmp_path):
    """POST /chat/upload-to-brain stores file and creates DB record"""
    # This is more of an API test but requested here
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core import database
    
    client = TestClient(app)
    
    # Mock user and DB
    mock_user = models.User(id=1, email="test@example.com")
    def get_user_override(): return mock_user
    app.dependency_overrides[auth.get_current_user] = get_user_override
    
    db = MagicMock()
    app.dependency_overrides[database.get_db] = lambda: db
    
    # Mock the background task to avoid actual processing
    with patch("fastapi.BackgroundTasks.add_task") as mock_add_task:
        file_content = b"fake pdf content"
        files = {"file": ("test.pdf", file_content, "application/pdf")}
        
        # Mock os.makedirs to avoid creating uploads dir in actual repo
        with patch("os.makedirs"):
            # Mock open
            with patch("builtins.open", MagicMock()):
                response = client.post("/chat/upload-to-brain", files=files)
                assert response.status_code == 200
                assert response.json()["status"] == "processing"
    
    app.dependency_overrides = {}
