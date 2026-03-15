import uuid
import logging
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session
from app.models import models
from app.services.lifepath_harvester import LifepathHarvester
from app.services.lifepath_evaluator import LifepathEvaluator
from app.services import rag_engine

logger = logging.getLogger(__name__)

class LifepathService:
    """
    Orchestrator for the Life Path engine.
    Manages the end-to-end evaluation pipeline and persistence.
    """

    def __init__(self):
        self.harvester = LifepathHarvester()
        self.evaluator = LifepathEvaluator()

    async def initialize_baseline(self, user_id: int, baseline_text: str, macro_goal: str, db: Session):
        """Initializes or updates user's baseline and macro goal."""
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise ValueError("User not found")

        # Handle archiving of old baseline
        baseline_data = user.life_path_baseline or {"current": "", "archive": []}
        if baseline_data.get("current") and baseline_data["current"] != baseline_text:
            baseline_data["archive"].append(baseline_data["current"])
        
        baseline_data["current"] = baseline_text
        user.life_path_baseline = baseline_data
        user.macro_goal = macro_goal
        
        db.commit()
        return user

    async def evaluate_daily_node(self, user_id: int, db: Session, force: bool = False) -> Optional[models.LifePathNode]:
        """Runs the daily evaluation pipeline."""
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            return None

        # 1. Deduplication (max 1/24h)
        if not force and user.last_lifepath_eval:
            if (datetime.utcnow() - user.last_lifepath_eval.replace(tzinfo=None)).total_seconds() < 86400:
                logger.info(f"[LifepathService] Skipping eval for user {user_id}: <24h since last.")
                return None

        # 2. Harvesting
        health_context = self.harvester.harvest_health_context(user_id, db)
        music_tones = self.harvester.harvest_music_context(user_id, db)
        notes = self.harvester.harvest_notes_context(user_id, db)
        files = self.harvester.harvest_files_context(user_id, db)
        
        # 3. Evaluation
        note_summary = await self.evaluator.summarize_notes(notes)
        if files:
            # Append some file context to the summary if available
            note_summary += f"\n\nRecent Reference Documents:\n" + "\n".join(files[:3]) # Limit to first few chunks
        baseline_text = user.life_path_baseline.get("current", "No baseline set.") if user.life_path_baseline else "No baseline set."
        
        trajectory = await self.evaluator.evaluate_trajectory(
            baseline_summary=baseline_text,
            macro_goal_text=user.macro_goal or "No macro goal set.",
            note_summary=note_summary,
            health_summary=health_context,
            music_tones=music_tones,
            knowledge_context="\n".join(files) if files else "No relevant file context found."
        )

        # 4. Persistence & Embedding
        node_uuid = str(uuid.uuid4())
        context_snapshot = {
            "health": health_context,
            "music_tones": music_tones,
            "note_ids": [n.id for n in notes]
        }

        # Helper to ensure trajectory fields are strings for embedding
        def get_traj_str(key):
            val = trajectory.get(key, [])
            if isinstance(val, list):
                 return ", ".join(val)
            return str(val)

        # Generate embedding for the daily node (grounded in summary + goals)
        node_text = (
            f"Daily Life Path Node ({datetime.utcnow().strftime('%Y-%m-%d')})\n"
            f"Themes: {note_summary}\n"
            f"Progress: {get_traj_str('progress')}\n"
            f"Short Term Goals: {get_traj_str('short_term_goals')}"
        )
        embedding_id = f"lifepath_{node_uuid}"
        
        # We use rag_engine to get the embedding model
        emb_model = rag_engine.get_emb_fn()
        vector = emb_model.encode([node_text]).tolist()[0]
        
        new_emb = models.BrainEmbedding(
            id=embedding_id,
            user_id=user_id,
            document=node_text,
            embedding=vector,
            source_type="lifepath_daily_node",
            metadata_={"type": "lifepath_node", "date": datetime.utcnow().isoformat()}
        )
        db.add(new_emb)

        new_node = models.LifePathNode(
            user_id=user_id,
            trajectory=trajectory,
            context_snapshot=context_snapshot,
            embedding_id=embedding_id
        )
        db.add(new_node)
        
        user.last_lifepath_eval = datetime.utcnow()
        db.commit()
        
        return new_node

lifepath_service = LifepathService()
