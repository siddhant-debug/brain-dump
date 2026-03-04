from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import logging

from app.schemas.schemas import MusicContextRequest, MusicContextResponse, UserResponse
from app.core.database import get_db
from app.api.routers.auth import get_current_user
from app.services.music_analyzer import MusicAnalyzerService

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/context", response_model=MusicContextResponse)
def analyze_music_context(
    request_data: MusicContextRequest,
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Receives current or recent music from the frontend.
    Returns the analyzed emotional tone (cached or newly generated via LLM).
    """
    try:
        if not request_data.is_playing_now and (
            not request_data.recent_songs or len(request_data.recent_songs) == 0
        ):
            return MusicContextResponse(
                primary_tone="Neutral",
                short_description="No music currently playing and no recent history provided.",
            )

        tone_data = MusicAnalyzerService.analyze_tone(request_data, db)

        return MusicContextResponse(
            primary_tone=tone_data.get("primary_tone", "Unknown"),
            short_description=tone_data.get("short_description", "Unknown mindset"),
        )

    except Exception as e:
        logger.error(f"[MusicRouter] Error analyzing music context: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process music context.",
        )
