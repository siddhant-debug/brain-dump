import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.getcwd())))

from app.core.database import SessionLocal
from app.models.models import ChatMessage

db = SessionLocal()
msgs = db.query(ChatMessage).order_by(ChatMessage.timestamp.desc()).limit(20).all()
print("--- LATEST 20 CHAT MESSAGES IN DB ---")
for m in msgs:
    print(f"ID: {m.id}, User ID: {m.user_id}, Content: '{m.content[:30]}...', Sender: {m.sender}, Timestamp: {m.timestamp}")
db.close()
