# backend/tests/test_tasks.py
import pytest
from unittest.mock import MagicMock, patch
from app.api.routers.notes import process_note_background

@patch("app.api.routers.notes.database.SessionLocal")
@patch("app.api.routers.notes.rag_engine")
def test_process_note_background_success(mock_rag, mock_db_session):
    """118: Verifies that background note processing executes the RAG indexing."""
    mock_db = MagicMock()
    mock_db_session.return_value = mock_db
    mock_note = MagicMock()
    mock_db.query().filter().first.return_value = mock_note
    mock_note.content = "Test content"
    mock_note.id = 1
    
    process_note_background(1, "Test content", 1)  # Updated arguments
    
    mock_rag.index_text.assert_called_once()
    mock_db.commit.assert_called()
