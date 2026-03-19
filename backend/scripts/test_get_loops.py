import os
import sys
import traceback

# Setup path so app modules can be imported (parent of tests dir)
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models import models
from app.api.routers.analytics import get_loops

db = SessionLocal()
# user ID 5
user = db.query(models.User).filter(models.User.id == 5).first()

from starlette.requests import Request

# Create a mock scope so the fastAPI request object instantiates properly for the rate limiter
scope = {
    "type": "http",
    "client": ("127.0.0.1", 8000),
    "path": "/analytics/loops",
    "method": "GET",
    "headers": [],
}
req = Request(scope)

try:
    result = get_loops(request=req, days=30, db=db, current_user=user)
    print("\n--- LOOPS ENDPOINT RESULT ---")
    import json

    print(json.dumps(result, indent=2))
except Exception as e:
    traceback.print_exc()
