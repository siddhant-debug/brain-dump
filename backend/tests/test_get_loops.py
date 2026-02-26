import os
import sys

# Setup path so app modules can be imported
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models import models
from app.api.routers.analytics import get_loops

db = SessionLocal()
# user ID 5
user = db.query(models.User).filter(models.User.id == 5).first()

from starlette.requests import Request

# Create a mock scope so the fastAPI request object instantiates
scope = {
    "type": "http",
    "client": ("127.0.0.1", 8000),
}
req = Request(scope)

try:
    result = get_loops(request=req, db=db, current_user=user)
    print("\n--- LOOPS ENDPOINT RESULT ---")
    print(result)
except Exception as e:
    print(e)
