import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routers import auth


# Mock auth
def override_get_current_user():
    from app.core.database import SessionLocal
    from app.models import models

    db = SessionLocal()
    user = db.query(models.User).filter(models.User.id == 5).first()
    db.close()
    return user


app.dependency_overrides[auth.get_current_user] = override_get_current_user

client = TestClient(app)

notes_to_create = [
    "I really need to figure out how to scale the Postgres database. It's getting too slow and we need connection pooling. Maybe PgBouncer?",
    "Database scaling is becoming an urgent issue. Postgres connections are maxing out during peak hours. Need to implement PgBouncer soon.",
    "Postgres connection limits hit again today. We absolutely must set up PgBouncer and optimize our DB scaling strategy this weekend.",
]

print("Adding test notes...")
for content in notes_to_create:
    response = client.post("/notes/", json={"content": content})
    if response.status_code == 200:
        print(f"Created note ID: {response.json().get('id')}")
    else:
        print(f"Failed: {response.text}")

print("Done. Now test_get_loops.py should find a loop.")
