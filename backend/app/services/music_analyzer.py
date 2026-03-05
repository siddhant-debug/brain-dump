import hashlib
import json
import logging
import os
from sqlalchemy.orm import Session
from google import genai
from google.genai import types

from app.models.models import MusicVibeCache
from app.schemas.schemas import MusicContextRequest
from app.services.gemini_service import gemini_service

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
    def analyze_tone(request: MusicContextRequest, db: Session) -> dict:
        """
        Main entry point. Generates key, checks cache, and falls back to LLM.
        """
        logger.info(
            f"[MusicAnalyzer] Incoming request - is_playing: {request.is_playing_now}, current: {request.current_song}, recent count: {len(request.recent_songs) if request.recent_songs else 0}"
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

        prompt = f"""
        Analyze the following song(s): 
        {song_context}
        
        What is the emotional tone, nature, and likely mindset of the listener? 
        Determine their current mood using a 3-dimensional vector (Valence, Arousal, Dominance) 
        where each is a float between -1.0 and 1.0.
        Choose a 'primary_tone' from categories such as: Happy, Sad, Romance, Work/Focus, Gym/High-Energy, Chill/Relaxed. 
        Write a 'short_description' (1 short sentence) characterizing the vibe.
        
        Return a valid JSON object with EXACTLY these keys: 
        "primary_tone" (string), "short_description" (string), "valence" (float), "arousal" (float), "dominance" (float).
        """

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
                    system_instruction="You are a music analysis engine classifying emotional tone and listener mindset based purely on song titles and artists.",
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
