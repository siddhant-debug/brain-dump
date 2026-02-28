import os
import sys

# Setup path so app modules can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models import models
from sqlalchemy import func

db = SessionLocal()

# Count notes per user
counts = (
    db.query(models.Note.user_id, func.count(models.Note.id))
    .group_by(models.Note.user_id)
    .all()
)

print("User Note Counts:")
for user_id, count in counts:
    print(f"User ID: {user_id}, Notes: {count}")
