import hashlib
import json
import logging
import os
from datetime import datetime
from sqlalchemy.orm import Session
from google import genai
from google.genai import types

from app.models.models import MusicVibeCache, MusicHistory
from app.schemas.schemas import MusicContextRequest
from app.services.gemini_service import gemini_service
from app.core.prompts import MUSIC_ANALYSIS_PROMPT, MUSIC_ANALYSIS_SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)


class MusicAnalyzerService:
    @staticmethod
    def _generate_cache_key(request: MusicContextRequest) -> str:
        """Generates a stable hash key based on the song list."""
        if request.is_playing_now and request.current_song:
            raw_string = (
                f"Single:{request.current_song.title}{request.current_song.artist}"
            )
        elif not request.is_playing_now and request.recent_songs:
            # Sort to ensure consistent hashing regardless of minor list ordering
            sorted_songs = sorted(
                [f"{s.title}{s.artist}" for s in request.recent_songs]
            )
            raw_string = f"List:{''.join(sorted_songs)}"
        else:
            raw_string = "EmptyMusicContext"

        return hashlib.md5(raw_string.encode("utf-8")).hexdigest()

    @staticmethod
    def _get_cached_vibe(cache_key: str, db: Session) -> dict | None:
        """Checks the DB cache for an existing analysis."""
        cached = (
            db.query(MusicVibeCache)
            .filter(MusicVibeCache.cache_key == cache_key)
            .first()
        )
        if cached:
            return {
                "primary_tone": cached.primary_tone,
                "short_description": cached.short_description,
                "valence": cached.valence if cached.valence is not None else 0.0,
                "arousal": cached.arousal if cached.arousal is not None else 0.0,
                "dominance": cached.dominance if cached.dominance is not None else 0.0,
            }
        return None

    @staticmethod
    def _save_to_cache(cache_key: str, tone_data: dict, db: Session):
        """Saves a new analysis to the DB cache."""
        try:
            logger.info(f"[MusicAnalyzer] Saving new vibe to cache: {tone_data}")
            new_cache = MusicVibeCache(
                cache_key=cache_key,
                primary_tone=tone_data.get("primary_tone", "Neutral"),
                short_description=tone_data.get(
                    "short_description", "No distinct vibe detected."
                ),
                valence=tone_data.get("valence", 0.0),
                arousal=tone_data.get("arousal", 0.0),
                dominance=tone_data.get("dominance", 0.0),
            )
            db.add(new_cache)
            db.commit()
        except Exception as e:
            db.rollback()
            logger.error(f"[MusicAnalyzer] Failed to save to cache: {e}")

    @staticmethod
    def analyze_tone(request: MusicContextRequest, db: Session, user_id: int) -> dict:
        """
        Main entry point. Generates key, checks cache, and falls back to LLM.
        """
        logger.info(
            f"[MusicAnalyzer] Incoming request - user: {user_id}, is_playing: {request.is_playing_now}, current: {request.current_song}, recent count: {len(request.recent_songs) if request.recent_songs else 0}"
        )

        # Validate input
        if request.is_playing_now and not request.current_song:
            logger.warning(
                "[MusicAnalyzer] Invalid request: is_playing_now is True but no current_song provided."
            )
            return {
                "primary_tone": "Unknown",
                "short_description": "Playing, but no song data provided.",
            }

        if not request.is_playing_now and (
            not request.recent_songs or len(request.recent_songs) == 0
        ):
            logger.warning(
                "[MusicAnalyzer] Invalid request: Not playing AND no recent history provided."
            )
            return {
                "primary_tone": "Unknown",
                "short_description": "No music playing and no recent history.",
            }

        cache_key = MusicAnalyzerService._generate_cache_key(request)

        # 1. Check Cache
        cached_vibe = MusicAnalyzerService._get_cached_vibe(cache_key, db)
        if cached_vibe:
            logger.info(f"[MusicAnalyzer] Cache HIT for key {cache_key}: {cached_vibe}")
            # Still persist history even on cache hit if needed, but router handles on-demand
            MusicAnalyzerService._persist_history(user_id, request, db)
            return cached_vibe

        logger.info(
            f"[MusicAnalyzer] Cache MISS for key {cache_key}. Proceeding to Gemini analysis."
        )

        # 2. Build the LLM prompt payload
        if request.is_playing_now and request.current_song:
            song_context = f"Currently Playing: '{request.current_song.title}' by {request.current_song.artist}"

            # Optionally append some history to the current song for a fuller picture
            if request.recent_songs:
                song_list_str = "\n".join(
                    [f"- '{s.title}' by {s.artist}" for s in request.recent_songs[:5]]
                )
                song_context += f"\n\nRecently Played Before This:\n{song_list_str}"

        elif request.recent_songs:
            song_list_str = "\n".join(
                [f"- '{s.title}' by {s.artist}" for s in request.recent_songs]
            )
            song_context = f"Not currently playing, but Recently Played (Last {len(request.recent_songs)} tracks):\n{song_list_str}"
        else:
            return {
                "primary_tone": "Neutral",
                "short_description": "No valid music context.",
            }

        logger.info(
            f"[MusicAnalyzer] Constructed Song Context for Gemini:\n{song_context}"
        )

        # H-8: Persist music history for Life Path Engine
        MusicAnalyzerService._persist_history(user_id, request, db)

        prompt = MUSIC_ANALYSIS_PROMPT.format(song_context=song_context)

        # 3. Call Gemini
        try:
            api_key = os.getenv("GEMINI_API_KEY")
            if not api_key:
                raise ValueError("GEMINI_API_KEY environment variable is not set.")

            client = genai.Client(api_key=api_key)
            response = client.models.generate_content(
                model="gemini-3-flash-preview",
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.2,  # Low temp for categorization consistency
                    response_mime_type="application/json",
                    system_instruction=MUSIC_ANALYSIS_SYSTEM_INSTRUCTION,
                ),
            )

            logger.info(f"[MusicAnalyzer] Gemini raw response: {response.text}")

            # 4. Parse response
            result = json.loads(response.text)

            # Format enforcement
            tone_data = {
                "primary_tone": result.get("primary_tone", "Unknown"),
                "short_description": result.get("short_description", "Unknown mindset"),
                "valence": float(result.get("valence", 0.0)),
                "arousal": float(result.get("arousal", 0.0)),
                "dominance": float(result.get("dominance", 0.0)),
            }

            # 5. Save to Cache
            MusicAnalyzerService._save_to_cache(cache_key, tone_data, db)
            return tone_data

        except Exception as e:
            logger.error(f"[MusicAnalyzer] Gemini analysis failed: {e}")
            return {
                "primary_tone": "Unknown",
                "short_description": "Failed to analyze tone due to an internal error.",
                "valence": 0.0,
                "arousal": 0.0,
                "dominance": 0.0,
            }

    @staticmethod
    def _persist_history(user_id: int, request: MusicContextRequest, db: Session):
        """Saves tracks to music_history table for the current user."""
        try:
            songs_to_save = []
            if request.is_playing_now and request.current_song:
                songs_to_save.append(request.current_song)
            if request.recent_songs:
                songs_to_save.extend(request.recent_songs)
            
            for s in songs_to_save:
                # Check if already exists in last 10 entries to avoid spamming
                exists = db.query(MusicHistory).filter(
                    MusicHistory.user_id == user_id,
                    MusicHistory.title == s.title,
                    MusicHistory.artist == s.artist
                ).order_by(MusicHistory.played_at.desc()).first()
                
                # If seen in last hour, skip to avoid duplicates from frequent polling
                if exists and (datetime.utcnow() - exists.played_at.replace(tzinfo=None)).total_seconds() < 3600:
                    continue

                new_entry = MusicHistory(
                    user_id=user_id,
                    title=s.title,
                    artist=s.artist
                )
                db.add(new_entry)
            
            db.commit()
        except Exception as e:
            db.rollback()
            logger.error(f"[MusicAnalyzer] Failed to persist music history: {e}")
