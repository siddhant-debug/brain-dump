from app.core.database import SessionLocal
from app.models.models import ChatMessage
import sys

db = SessionLocal()
try:
    user_id = 1
    count = db.query(ChatMessage).filter(ChatMessage.user_id == user_id).count()
    print(f"User {user_id} has {count} messages.")
finally:
    db.close()

