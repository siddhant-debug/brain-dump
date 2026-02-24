import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.getcwd())))
from app.core.database import SessionLocal
from app.models.models import ChatMessage

db = SessionLocal()
print("--- Check User IDs for flutter msgs (169-176) ---")
for id in [176, 198]:
    m = db.query(ChatMessage).filter(ChatMessage.id == id).first()
    if m:
        print(f"ID {m.id} timestamp: {m.timestamp} (tzinfo: {m.timestamp.tzinfo})")
