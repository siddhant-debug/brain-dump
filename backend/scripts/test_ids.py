import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.getcwd())))
from app.core.database import SessionLocal
from app.models.models import ChatMessage

db = SessionLocal()
print("--- Check User IDs for flutter msgs (169-176) ---")
for id in [169, 176]:
    m = db.query(ChatMessage).filter(ChatMessage.id == id).first()
    if m:
        print(f"ID {m.id} belongs to User ID {m.user_id}")
    else:
        print(f"ID {id} not found")

print("--- Check User IDs for latest db msgs (197-198) ---")
for id in [197, 198]:
    m = db.query(ChatMessage).filter(ChatMessage.id == id).first()
    if m:
        print(f"ID {m.id} belongs to User ID {m.user_id}")
    else:
        print(f"ID {id} not found")
