# backend/tests/test_tasks.py
import pytest
from unittest.mock import MagicMock, patch
from app.api.routers.notes import process_note_background
from app.api.routers.rag import process_upload_background

@patch("app.api.routers.notes.SessionLocal")
@patch("app.api.routers.notes.rag_engine")
def test_process_note_background_success(mock_rag, mock_db_session):
    """118: Verifies that background note processing executes the RAG indexing."""
    mock_db = MagicMock()
    mock_db_session.return_value = mock_db
    mock_note = MagicMock()
    mock_db.query().filter().first.return_value = mock_note
    mock_note.content = "Test content"
    mock_note.id = 1
    
    process_note_background(1)
    
    mock_rag.index_text.assert_called_once_with("Test content", metadata={"note_id": 1, "source": "note"})
    mock_db.commit.assert_called()

@patch("app.api.routers.rag.SessionLocal")
@patch("app.api.routers.rag.VaultService")
@patch("app.api.routers.rag.rag_engine")
def test_process_upload_background_success(mock_rag, mock_vault, mock_db_session):
    """119: Verifies that background file upload processing extracts text and indexes it."""
    mock_db = MagicMock()
    mock_db_session.return_value = mock_db
    mock_file = MagicMock()
    mock_db.query().filter().first.return_value = mock_file
    mock_file.id = 1
    mock_file.filename = "test.txt"
    
    mock_vault_inst = mock_vault.return_value
    mock_vault_inst.get_file_path.return_value = "/tmp/test.txt"
    
    # Mock text extraction
    with patch("app.api.routers.rag.open", create=True) as mock_open:
        mock_open.return_value.__enter__.return_value.read.return_value = "Extracted content"
        process_upload_background(1)
    
    mock_rag.index_text.assert_called_once()
    mock_db.commit.assert_called()
