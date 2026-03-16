import logging
import json
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.models.models import ChatMessage, EpisodicMemory
from app.services.gemini_service import gemini_service
from app.services.rag_engine import _rag_service as rag_engine
from app.core.prompts import REFLECTION_SYSTEM_PROMPT

logger = logging.getLogger(__name__)

# Constants for reflection logic
REFLECTION_MIN_MESSAGES = 5
REFLECTION_MIN_DURATION_MINUTES = 10
INACTIVITY_THRESHOLD_MINUTES = 30


class ReflectionEngine:
    def __init__(self, db: Session):
        self.db = db
        self.gemini = gemini_service
        self.rag = rag_engine

    async def reflect_on_session(
        self, user_id: int, force: bool = False
    ) -> Optional[EpisodicMemory]:
        """
        Analyzes recent chat messages and generates an EpisodicMemory reflection.
        """
        try:
            logger.info(f"Refinement triggered for user {user_id} (force={force})")

            # 1. Fetch un-reflected messages (The "Short-term Loop")
            recent_messages = (
                self.db.query(ChatMessage)
                .filter(ChatMessage.user_id == user_id)
                .order_by(desc(ChatMessage.timestamp))
                .limit(REFLECTION_MIN_MESSAGES * 3)
                .all()
            )

            if not recent_messages:
                logger.info(
                    f"[Reflection] User {user_id} has no message history. Skipping."
                )
                return None

            recent_messages.reverse()  # Sort chronologically

            # 2. Check thresholds
            if not force:
                message_count = len(recent_messages)
                duration = recent_messages[-1].timestamp - recent_messages[0].timestamp

                if message_count < REFLECTION_MIN_MESSAGES and duration < timedelta(
                    minutes=REFLECTION_MIN_DURATION_MINUTES
                ):
                    logger.info(
                        f"Session too brief for reflection: {message_count} msgs, {duration.seconds // 60} mins."
                    )
                    return None

            # 3. Format history for Gemini
            history_text = "\n".join(
                [f"{m.sender.upper()}: {m.content}" for m in recent_messages]
            )

            # 4. Generate reflection via Gemini
            logger.info(f"Generating reflection for user {user_id}...")
            reflection_raw = await self.gemini.generate_content(
                prompt=f"CONVERSATION HISTORY:\n{history_text}\n\nTask: Reflect on this conversation.",
                system_instruction=REFLECTION_SYSTEM_PROMPT,
            )

            # Parse JSON
            try:
                # Clean potential markdown backticks from response
                clean_json = (
                    reflection_raw.replace("```json", "").replace("```", "").strip()
                )
                reflection_data = json.loads(clean_json)
            except Exception as e:
                logger.error(
                    f"Failed to parse reflection JSON: {e}. Raw: {reflection_raw}"
                )
                return None

            # 5. Generate embedding for the reflection summary
            # We use the text-based summary for the vector search baseline
            summary_text = reflection_data.get("summary", "")
            if not summary_text:
                logger.warning(
                    f"No summary found in reflection data for user {user_id}"
                )
                return None

            embedding = self.rag.get_embedding(summary_text)

            # 6. Save to database
            new_memory = EpisodicMemory(
                user_id=user_id, summary_json=reflection_data, embedding=embedding
            )

            self.db.add(new_memory)
            self.db.commit()
            self.db.refresh(new_memory)

            logger.info(
                f"Successfully saved EpisodicMemory {new_memory.id} for user {user_id}"
            )
            return new_memory

        except Exception as e:
            logger.exception(f"Error during reflection process for user {user_id}: {e}")
            self.db.rollback()
            return None

    def trigger_inactivity_reflection(self, user_id: int):
        """
        Check if the last message was > 30 mins ago, then trigger reflection.
        """
        last_msg = (
            self.db.query(ChatMessage)
            .filter(ChatMessage.user_id == user_id)
            .order_by(desc(ChatMessage.timestamp))
            .first()
        )

        if last_msg:
            time_since_last = (
                datetime.now(last_msg.timestamp.tzinfo) - last_msg.timestamp
            )
            if time_since_last > timedelta(minutes=INACTIVITY_THRESHOLD_MINUTES):
                logger.info(
                    f"Inactivity trigger fired for user {user_id} ({time_since_last.seconds // 60} mins since last msg)"
                )
                return True
        return False
