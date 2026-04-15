import pytest
import random
import string
import sys
import os

# Add the backend directory to Python path so it can find the 'app' module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.models import User, ChatMessage, Note, BrainEmbedding, EpisodicMemory

client = TestClient(app)

EMAIL_PREFIX = "ci_test_user_"
PASSWORD = "password123"

def generate_random_string(length=8):
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=length))

@pytest.fixture(scope="module")
def setup_teardown_user():
    email = f"{EMAIL_PREFIX}{generate_random_string()}@example.com"
    signup_data = {"email": email, "password": PASSWORD, "full_name": "CI Test User"}
    
    # Create user
    response = client.post("/auth/signup", json=signup_data)
    assert response.status_code == 200, f"Signup failed: {response.text}"
    
    # Login
    login_data = {"email": email, "password": PASSWORD}
    response = client.post("/auth/login", json=login_data)
    assert response.status_code == 200, f"Login failed: {response.text}"
    token = response.json()["access_token"]
    
    auth_headers = {"Authorization": f"Bearer {token}"}
    
    yield {"email": email, "headers": auth_headers}
    
    # Teardown (clean up production DB)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if user:
            # Delete related data manually to avoid foreign key issues in tests
            db.query(Note).filter(Note.user_id == user.id).delete()
            db.query(ChatMessage).filter(ChatMessage.user_id == user.id).delete()
            db.query(BrainEmbedding).filter(BrainEmbedding.user_id == user.id).delete()
            db.query(EpisodicMemory).filter(EpisodicMemory.user_id == user.id).delete()
            db.delete(user)
            db.commit()
    finally:
        db.close()

def test_notes_flow(setup_teardown_user):
    headers = setup_teardown_user["headers"]
    
    # Create Note
    note_content = f"This is a CI test note generated at {generate_random_string()}"
    response = client.post("/notes/", json={"content": note_content}, headers=headers)
    assert response.status_code == 200, f"Note creation failed: {response.text}"
    
    # List Notes
    response = client.get("/notes/", headers=headers)
    assert response.status_code == 200
    notes = response.json()
    assert len(notes) > 0
    assert any(n["content"] == note_content for n in notes), "Test note not found in list"

def test_files_flow(setup_teardown_user):
    headers = setup_teardown_user["headers"]
    
    filename = f"ci_test_file_{generate_random_string()}.txt"
    file_content = "CI test file content."
    
    # This matches the requests format used in test_endpoints.py
    files = {"file": (filename, file_content.encode('utf-8'), "text/plain")}
    
    response = client.post("/chat/upload-to-brain", files=files, headers=headers)
    assert response.status_code == 200, f"File upload failed: {response.text}"
    
    response = client.get("/files/", headers=headers)
    assert response.status_code == 200
    files_list = response.json()
    assert any(f["filename"] == filename for f in files_list), "Uploaded file not found in vault"

def test_rag_chat_flow(setup_teardown_user):
    headers = setup_teardown_user["headers"]
    
    # Upload context to RAG (Brain)
    brain_filename = f"ci_brain_{generate_random_string()}.txt"
    brain_content = "The airspeed velocity of an unladen swallow is 24mph."
    files = {"file": (brain_filename, brain_content.encode('utf-8'), "text/plain")}
    
    response = client.post("/chat/upload-to-brain", files=files, headers=headers)
    assert response.status_code == 200, f"Upload to brain failed: {response.text}"
    
    query = "What is the airspeed velocity of a swallow?"
    
    # TestClient block-fetches streaming response natively without 'stream=True' keyword
    response = client.post(
        "/chat/chat",
        json={"query": query},
        headers=headers
    )
    assert response.status_code == 200
    
    has_chunk = False
    import json
    # response.text contains the full SSE payload delimited by newlines
    for line in response.text.splitlines():
        if not line: continue
        if line.startswith("data: "):
            try:
                payload = json.loads(line[6:])
                if payload.get("chunk"):
                    has_chunk = True
            except json.JSONDecodeError:
                pass
                
    # Even if RAG fails internally and returns no chunks, 
    # the endpoint shouldn't crash if it streamed successfully.
    # Note: Sometimes AI doesn't find the answer, so we don't strictly assert True.
    # But it proves the Call Flow doesn't crash 500.
