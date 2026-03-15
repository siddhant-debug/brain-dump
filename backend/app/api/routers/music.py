import os
import logging
import requests as http_requests

from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy.orm import Session

from app.schemas.schemas import MusicContextRequest, MusicContextResponse, UserResponse
from app.core.database import get_db
from app.api.routers.auth import get_current_user
from app.services.music_analyzer import MusicAnalyzerService

router = APIRouter()
logger = logging.getLogger(__name__)

APPLE_MUSIC_API_BASE = "https://api.music.apple.com/v1"


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/music/recent/played
#   Fetches the user's 10 most recently played tracks from Apple Music API.
#   Requires the `Music-User-Token` header from the frontend (obtained via MusicKit).
#   Server uses its own APPLE_MUSIC_JWT (dev token) from .env.
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/recent/played")
def get_recent_played(
    music_user_token: str = Header(..., alias="Music-User-Token"),
    current_user: UserResponse = Depends(get_current_user),
):
    """
    Calls Apple Music GET /v1/me/recent/played?limit=10 on behalf of the user.
    Returns a list of {title, artist} dicts the frontend can feed into /context.
    """
    developer_token = os.getenv("APPLE_MUSIC_JWT")
    if not developer_token:
        logger.error("[MusicRouter] APPLE_MUSIC_JWT not set in environment.")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server misconfiguration: Apple Music Developer Token missing.",
        )

    try:
        response = http_requests.get(
            f"{APPLE_MUSIC_API_BASE}/me/recent/played",
            params={"limit": 10},
            headers={
                "Authorization": f"Bearer {developer_token}",
                "Music-User-Token": music_user_token,
            },
            timeout=10,
        )

        logger.info(f"[MusicRouter] Apple Music API status: {response.status_code}")

        if response.status_code == 401:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired Music-User-Token. Re-authorize Apple Music.",
            )
        if response.status_code == 403:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Apple Music Developer Token expired or invalid. Check APPLE_MUSIC_JWT in .env.",
            )
        if not response.ok:
            logger.error(f"[MusicRouter] Apple Music API error: {response.text}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Apple Music API returned {response.status_code}.",
            )

        data = response.json()
        items = data.get("data", [])

        tracks = []
        for item in items:
            attrs = item.get("attributes", {})
            title = attrs.get("name", "Unknown")
            artist = attrs.get("artistName", "Unknown")
            tracks.append({"title": title, "artist": artist})

        logger.info(
            f"[MusicRouter] Fetched {len(tracks)} recent tracks for user {current_user.id}"
        )
        return {"recent_songs": tracks}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[MusicRouter] Failed to fetch recent played: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recent songs from Apple Music.",
        )


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/music/context
#   Receives current/recent song data from the frontend.
#   Returns analyzed emotional tone + VAD Mood Vector (valence, arousal, dominance).
# ─────────────────────────────────────────────────────────────────────────────
@router.post("/context", response_model=MusicContextResponse)
def analyze_music_context(
    request_data: MusicContextRequest,
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Receives current or recent music from the frontend.
    Returns the analyzed emotional tone + VAD Mood Vector (cached or newly generated).
    """
    try:
        if not request_data.is_playing_now and (
            not request_data.recent_songs or len(request_data.recent_songs) == 0
        ):
            return MusicContextResponse(
                primary_tone="Neutral",
                short_description="No music currently playing and no recent history provided.",
                valence=0.0,
                arousal=0.0,
                dominance=0.0,
            )

        tone_data = MusicAnalyzerService.analyze_tone(request_data, db, current_user.id)

        return MusicContextResponse(
            primary_tone=tone_data.get("primary_tone", "Unknown"),
            short_description=tone_data.get("short_description", "Unknown mindset"),
            valence=tone_data.get("valence", 0.0),
            arousal=tone_data.get("arousal", 0.0),
            dominance=tone_data.get("dominance", 0.0),
        )

    except Exception as e:
        logger.error(f"[MusicRouter] Error analyzing music context: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process music context.",
        )
