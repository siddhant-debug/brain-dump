import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.append(os.path.abspath(os.path.join(os.getcwd())))

from app.models.models import ChatMessage

# 1. Setup Source Connection (Old Mac Local DB)
print("Connecting to Source DB (Port 5432)...")
SOURCE_DB_URL = "postgresql+psycopg://postgres:password123@127.0.0.1:5432/postgres"
engine_source = create_engine(SOURCE_DB_URL)
SessionSource = sessionmaker(autocommit=False, autoflush=False, bind=engine_source)
db_source = SessionSource()

# 2. Setup Destination Connection (New Docker DB)
print("Connecting to Destination DB (Port 5433)...")
DEST_DB_URL = "postgresql+psycopg://postgres:password123@198.168.1.58:5433/postgres"
engine_dest = create_engine(DEST_DB_URL)
SessionDest = sessionmaker(autocommit=False, autoflush=False, bind=engine_dest)
db_dest = SessionDest()

try:
    # 3. Read old messages
    print("Fetching messages from Old DB...")
    old_messages = db_source.query(ChatMessage).all()
    print(f"Found {len(old_messages)} messages to migrate.")

    if not old_messages:
        print("Nothing to migrate!")
        sys.exit(0)

    # 4. Insert into new DB
    migrated_count = 0
    skipped_count = 0
    
    # We will try to preserve the original IDs if possible, but if there's a conflict
    # it's usually safer to just let Postgres assign new IDs unless the ID matters for 
    # relational integrity (which it doesn't currently for ChatMessage)
    
    for old_msg in old_messages:
        # Check if already exists in new DB (by exact content and timestamp)
        # to prevent duplicates if script runs twice
        exists = db_dest.query(ChatMessage).filter(
            ChatMessage.user_id == old_msg.user_id,
            ChatMessage.timestamp == old_msg.timestamp,
            ChatMessage.content == old_msg.content
        ).first()

        if exists:
            skipped_count += 1
            continue

        # Create new message object
        new_msg = ChatMessage(
            user_id=old_msg.user_id,
            content=old_msg.content,
            sender=old_msg.sender,
            timestamp=old_msg.timestamp,
            context_sources=old_msg.context_sources
        )
        db_dest.add(new_msg)
        migrated_count += 1

    # 5. Commit changes
    print("Committing changes to New DB...")
    db_dest.commit()
    print(f"Migration Complete: {migrated_count} migrated, {skipped_count} skipped (duplicates).")

except Exception as e:
    print(f"Migration Failed: {e}")
    db_dest.rollback()
finally:
    db_source.close()
    db_dest.close()
