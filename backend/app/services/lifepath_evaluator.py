import json
import logging
from typing import List, Optional
from app.services.llm_service import llm_service as gemini_service
from app.core.prompts import LIFEPATH_EVALUATOR_PROMPT, LIFEPATH_NOTE_SUMMARIZER_PROMPT
from app.models.models import Note

logger = logging.getLogger(__name__)

class LifepathEvaluator:
    """
    Handles LLM-heavy evaluation logic for the Life Path engine.
    Including PII-stripped note summarization and trajectory analysis.
    """

    async def summarize_notes(self, notes: List[Note]) -> str:
        """
        Takes raw notes, strips PII via LLM, and returns a thematic summary.
        """
        if not notes:
            return "No notes captured today."

        raw_text = "\n---\n".join([n.content for n in notes])
        prompt = LIFEPATH_NOTE_SUMMARIZER_PROMPT.format(raw_notes=raw_text)

        try:
            summary = await gemini_service.generate_content(
                prompt=prompt,
                temperature=0.2
            )
            return summary.strip()
        except Exception as e:
            logger.error(f"[LifepathEvaluator] Note summarization failed: {e}")
            return "Error summarizing daily notes."

    async def evaluate_trajectory(
        self,
        baseline_summary: str,
        macro_goal_text: str,
        note_summary: str,
        health_summary: dict,
        music_tones: List[str],
        knowledge_context: str = "No relevant file context found."
    ) -> dict:
        """
        Main analysis call. Maps today's context against baseline and macro goal.
        """
        music_vibe = ", ".join(set(music_tones)) if music_tones else "Neutral"
        
        health_str = (
            f"Readiness: {health_summary.get('latest_readiness', 'Unknown')}. "
            f"Avg Steps: {health_summary.get('avg_steps', 0):.0f}. "
            f"Recent HRV: {health_summary.get('recent_hrv', [])}."
        ) if health_summary else "No health data available."

        prompt = LIFEPATH_EVALUATOR_PROMPT.format(
            baseline_summary=baseline_summary,
            macro_goal_text=macro_goal_text,
            note_summary=note_summary,
            health_summary=health_str,
            music_primary_tone=music_vibe,
            knowledge_context=knowledge_context
        )

        try:
            raw_json = await gemini_service.generate_content(
                prompt=prompt,
                response_mime_type="application/json",
                temperature=0.4
            )
            return json.loads(raw_json)
        except Exception as e:
            logger.error(f"[LifepathEvaluator] Trajectory evaluation failed: {e}")
            return {
                "progress": [],
                "blockers": ["Evaluation system error."],
                "loops": [],
                "short_term_goals": ["Reflect on today manually."]
            }
