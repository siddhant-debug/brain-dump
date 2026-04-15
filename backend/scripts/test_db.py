import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.getcwd())))
from app.core.database import SessionLocal
from app.models.models import ChatMessage

db = SessionLocal()
msg_174 = db.query(ChatMessage).filter(ChatMessage.id == 174).first()
if msg_174:
    print(f"ID 174: Content: '{msg_174.content[:30]}...', Sender: {msg_174.sender}, Timestamp: {msg_174.timestamp}")
else:
    print("ID 174 not found")
