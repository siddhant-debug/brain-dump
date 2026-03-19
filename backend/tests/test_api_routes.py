# backend/tests/test_api_routes.py
import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch, AsyncMock
from app.main import app
from app.core import database
from app.api.routers import auth
from app.models import models
import json
from datetime import datetime

# Fixture for a mock database session
@pytest.fixture
def db_session():
    return MagicMock()

# Fixture to override the get_db dependency
@pytest.fixture(autouse=True)
def override_get_db(db_session):
    def get_db_override():
        try:
            yield db_session
        finally:
            pass
    app.dependency_overrides[database.get_db] = get_db_override
    yield
    app.dependency_overrides.pop(database.get_db, None)

# Fixture for a test user
@pytest.fixture
def test_user():
    return models.User(id=1, email="test@example.com", full_name="Test User", hashed_password="hashed_password", created_at=datetime.utcnow())

# Fixture to override get_current_user
@pytest.fixture
def override_get_current_user(test_user):
    app.dependency_overrides[auth.get_current_user] = lambda: test_user
    yield
    app.dependency_overrides.pop(auth.get_current_user, None)

client = TestClient(app)

def test_root_returns_200():
    """Validates the / endpoint returns 200 with welcome message"""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to Brain Dump API"}

def test_signup_returns_200(db_session):
    """Validates POST /auth/signup creates a user"""
    db_session.query().filter().first.return_value = None  # User doesn't exist
    payload = {"email": "new@example.com", "password": "Password123!", "full_name": "New User"}
    response = client.post("/auth/signup", json=payload)
    assert response.status_code == 200
    assert response.json()["email"] == "new@example.com"

def test_login_returns_token(db_session):
    """Validates POST /auth/login returns access_token"""
    mock_user = models.User(id=1, email="test@example.com", hashed_password="hashed_password")
    db_session.query().filter().first.return_value = mock_user
    
    with patch("app.api.routers.auth.verify_password", return_value=True):
        with patch("app.api.routers.auth.create_access_token", return_value="fake_token"):
            payload = {"email": "test@example.com", "password": "password123"}
            response = client.post("/auth/login", json=payload)
            assert response.status_code == 200
            assert response.json()["access_token"] == "fake_token"

def test_protected_route_without_token_returns_401():
    """Validates that accessing /chat/history without a token returns 401"""
    # Note: We don't use the override_get_current_user fixture here
    response = client.get("/chat/history")
    assert response.status_code == 401

def test_notes_create_and_list(db_session, override_get_current_user, test_user):
    """POST /notes/, then GET /notes/ returns the saved note"""
    # Mock create
    db_session.query().filter().order_by().first.return_value = None # No health/music context
    payload = {"content": "Test note"}
    response = client.post("/notes/", json=payload)
    assert response.status_code == 200
    
    # Mock list
    mock_note = models.Note(id=1, content="Test note", user_id=test_user.id, created_at=datetime.utcnow(), is_favorite=False)
    db_session.query().filter().order_by().all.return_value = [mock_note]
    response = client.get("/notes/")
    assert response.status_code == 200
    assert len(response.json()) > 0
    assert response.json()[0]["content"] == "Test note"

def test_files_list_returns_200(db_session, override_get_current_user):
    """GET /chat/files returns 200 with auth"""
    db_session.query().filter().all.return_value = []
    response = client.get("/chat/files")
    assert response.status_code == 200
    assert response.json() == []

def test_analytics_consistency_returns_200(db_session, override_get_current_user):
    """GET /analytics/consistency returns 200 with auth"""
    # Mock analytics logic
    db_session.query().filter().all.return_value = []
    response = client.get("/analytics/consistency")
    assert response.status_code == 200

@pytest.mark.asyncio
async def test_nlp_parse_reminder_with_mock_gemini(override_get_current_user):
    """POST /api/nlp/parse-reminder returns structured JSON with mocked Gemini"""
    mock_response = json.dumps({
        "action": "Reminder",
        "trigger_time": "2025-03-20T10:00:00",
        "recurrence": {"frequency": "daily", "interval": 1}
    })
    with patch("app.api.endpoints.nlp_router.gemini_service.generate_content", new_callable=AsyncMock) as mock_gen:
        mock_gen.return_value = mock_response
        payload = {
            "text": "Remind me to call Mom tomorrow at 10am",
            "timezone": "UTC",
            "current_time": "2025-03-19T10:00:00"
        }
        response = client.post("/api/nlp/parse-reminder", json=payload)
        assert response.status_code == 200
        assert response.json()["action"] == "Reminder"

def test_nlp_parse_reminder_too_long_returns_400(override_get_current_user):
    """Validates 400 for text > 500 chars"""
    payload = {
        "text": "a" * 501,
        "timezone": "UTC",
        "current_time": "2025-03-19T10:00:00"
    }
    response = client.post("/api/nlp/parse-reminder", json=payload)
    assert response.status_code == 400

def test_health_context_endpoint_returns_200(db_session, override_get_current_user):
    """POST /api/health/context accepts valid payload"""
    payload = {
        "readiness": "HIGH",
        "heart_rate": {"current": 70, "avg_24h": 65, "resting": 60},
        "hrv": {"current": 50, "avg_7d": 45},
        "sleep": {"total_hours": 8, "deep_hours": 2, "rem_hours": 2, "awake_hours": 0.5},
        "steps_today": 10000,
        "active_energy_kcal": 500.0,
        "fetched_at": "2025-03-19T10:00:00Z"
    }
    response = client.post("/api/health/context", json=payload)
    assert response.status_code == 200

def test_music_context_endpoint_returns_200(db_session, override_get_current_user):
    """POST /api/music/context accepts payload"""
    payload = {
        "is_playing_now": True,
        "current_song": {"title": "Song Title", "artist": "Artist Name"},
        "recent_songs": []
    }
    response = client.post("/api/music/context", json=payload)
    assert response.status_code == 200
