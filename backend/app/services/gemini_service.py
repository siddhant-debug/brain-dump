"""
GeminiService — Singleton LLM client.

Fixes:
  H-6  Prompt Injection: XML-tag delimiters + pre-flight injection check
  M-4  Perf: genai.configure() called exactly once, not per-request
"""

import os
import asyncio
import logging
import threading
import uuid
import re
from datetime import datetime
from typing import AsyncIterator

from google import genai
from google.genai import types

from app.core.prompts import SUBCONSCIOUS_SYSTEM_PROMPT

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Injection detection patterns (H-6)
# ---------------------------------------------------------------------------
_INJECTION_PATTERNS = re.compile(
    r"(ignore\s+(all\s+)?previous\s+instructions|"
    r"you\s+are\s+now|"
    r"disregard\s+(all\s+)?previous|"
    r"new\s+instructions?:|"
    r"system\s+prompt:|"
    r"act\s+as\s+(a\s+)?(?!yourself)|"
    r"forget\s+(everything|all)|"
    r"override\s+(your\s+)?instructions|"
    r"<\s*system\s*>|"
    r"\[INST\]|\[SYS\])",
    re.IGNORECASE,
)


class GeminiService:
    """
    Thread-safe singleton Gemini LLM client.

    - Calls genai.configure() exactly ONCE during __init__.
    - Enforces XML-tag delimiters to separate user data from instructions.
    - Runs an injection pre-flight check before every call.
    - Exposes async_stream() for use in the SSE router.
    """

    _instance: "GeminiService | None" = None
    _lock = threading.Lock()

    # ------------------------------------------------------------------ #
    # Singleton constructor                                                #
    # ------------------------------------------------------------------ #
    def __new__(cls) -> "GeminiService":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    instance = super().__new__(cls)
                    instance._initialized = False
                    cls._instance = instance
        return cls._instance

    def initialize(self):
        """Called once at app startup (inside the executor to avoid blocking the event loop)."""
        if self._initialized:
            return
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY environment variable is not set.")
        import httpx

        # genai.Client's HttpOptions.timeout only accepts int — create client first,
        # then patch the internal httpx client to set granular timeouts:
        # connect=10s (fail fast), read=None (never cut off streaming responses)
        self._client = genai.Client(api_key=api_key)
        _fine_timeout = httpx.Timeout(connect=10.0, read=None, write=30.0, pool=10.0)
        try:
            self._client._api_client._httpx_client.timeout = _fine_timeout
        except AttributeError:
            # Fallback if internal structure changes in a future SDK version
            logger.warning(
                "[GeminiService] Could not patch httpx timeout — using SDK default."
            )
        self._initialized = True
        logger.info("[GeminiService] Configured — genai.Client instantiated once.")

    # ------------------------------------------------------------------ #
    # H-6: Injection guard                                                 #
    # ------------------------------------------------------------------ #
    def _check_injection(self, text: str) -> bool:
        """Returns True if a potential injection pattern is detected."""
        return bool(_INJECTION_PATTERNS.search(text))

    def _sanitize(self, text: str) -> str:
        """
        If injection patterns are found, blank the offending text and log a warning.
        We don't raise an error — we degrade gracefully so the user still gets a response.
        """
        if self._check_injection(text):
            logger.warning(
                "[SECURITY] Potential prompt injection pattern detected and scrubbed."
            )
            sanitized = _INJECTION_PATTERNS.sub("[redacted]", text)
            return sanitized
        return text

    # ------------------------------------------------------------------ #
    # Prompt assembly helpers                                              #
    # ------------------------------------------------------------------ #
    def _build_prompt(self, context: str, query: str, chat_history: list = None) -> str:
        """
        H-6: XML-tag delimiters structurally separate user data from instructions.
        The LLM sees context and query as tagged data, not executable instructions.
        """
        safe_context = self._sanitize(context)
        safe_query = self._sanitize(query)

        prompt_parts = []

        prompt_parts.append("<user_context>\n" + safe_context + "\n</user_context>\n")

        if chat_history:
            prompt_parts.append("<recent_conversation>")
            for msg in chat_history:
                sender_label = "User" if msg["sender"] == "user" else "AI"
                prompt_parts.append(f"{sender_label}: {self._sanitize(msg['content'])}")
            prompt_parts.append("</recent_conversation>\n")

        prompt_parts.append("<user_question>\n" + safe_query + "\n</user_question>\n")
        prompt_parts.append("DIRECT ANSWER (Max 3 sentences):")

        return "\n".join(prompt_parts)

    def _build_system_instruction(
        self,
        temporal_context: str,
        emotional_state: str,
        tone_guidance: str,
        tone_layer: str,
        location_layer: str,
        music_layer: str,
        health_layer: str,
        directives: list = None,
    ) -> str:
        base_prompt = SUBCONSCIOUS_SYSTEM_PROMPT.format(
            date=datetime.now().strftime("%B %d, %Y"),
            temporal_context=temporal_context,
            emotional_state=emotional_state,
            tone_guidance=tone_guidance,
            tone_layer=tone_layer,
            location_layer=location_layer,
            music_layer=music_layer,
            health_layer=health_layer,
        )

        if directives:
            directives_block = "<subconscious_directives>\n"
            for d in directives:
                directives_block += f"- {d}\n"
            directives_block += "</subconscious_directives>\n"
            directives_block += "You MUST strictly follow the behaviors defined in <subconscious_directives> for this specific user.\n"

            # Prepend directives strongly at the very top of system prompt
            base_prompt = directives_block + "\n" + base_prompt

        return base_prompt

    def _get_model(
        self, system_instruction: str, max_tokens: int
    ) -> types.GenerateContentConfig:
        # ⚠️  DO NOT CHANGE THIS MODEL NAME — gemini-3-flash-preview is the
        # agreed production model for BrainDump. It handles the required quota
        # and latency profile for the subconscious streaming UX.
        return types.GenerateContentConfig(
            temperature=0.4,
            max_output_tokens=max_tokens,
            system_instruction=system_instruction,
        )

    # ------------------------------------------------------------------ #
    # Public API                                                           #
    # ------------------------------------------------------------------ #
    async def async_stream(
        self,
        context: str,
        query: str,
        temporal_context: str,
        emotional_state: str,
        tone_guidance: str,
        tone_layer: str,
        location_layer: str,
        music_layer: str = "",
        health_layer: str = "",
        max_tokens: int = 1000,
        chat_history: list = None,
        directives: list = None,
    ) -> AsyncIterator[str]:
        """
        Async streaming wrapper.

        H-5: Producer thread has a hard 25-second timeout via request_options.
             A 30-second thread.join watchdog pushes a sentinel if the thread hangs.
        H-6: Prompt assembled with XML delimiters + injection check.
        """
        if not self._initialized:
            raise RuntimeError(
                "GeminiService.initialize() must be called before streaming."
            )

        prompt = self._build_prompt(context, query, chat_history)
        system_instruction = self._build_system_instruction(
            temporal_context,
            emotional_state,
            tone_guidance,
            tone_layer,
            location_layer,
            music_layer,
            health_layer,
            directives,
        )
        config = self._get_model(system_instruction, max_tokens)

        loop = asyncio.get_running_loop()
        queue: asyncio.Queue = asyncio.Queue()
        sentinel = object()

        def producer():
            try:
                # H-5: Generate streaming content with the new SDK
                response = self._client.models.generate_content_stream(
                    model="gemini-3-flash-preview", contents=prompt, config=config
                )
                for chunk in response:
                    if chunk.text:
                        loop.call_soon_threadsafe(queue.put_nowait, chunk.text)
                loop.call_soon_threadsafe(queue.put_nowait, sentinel)
            except Exception as exc:
                logger.error("[GeminiService] Producer error: %s", exc, exc_info=True)
                loop.call_soon_threadsafe(queue.put_nowait, exc)
                loop.call_soon_threadsafe(queue.put_nowait, sentinel)

        thread = threading.Thread(target=producer, daemon=True)
        thread.start()

        # H-5: watchdog — if the producer thread is still alive after the timeout, it's hung.
        # Set to 300s (5 min) to allow Gemini to handle large RAG contexts without false triggers.
        _PRODUCER_TIMEOUT_S = (
            90  # 90s: enough for RAG (~2s) + Gemini on slow home server
        )

        async def _watchdog():
            await asyncio.sleep(_PRODUCER_TIMEOUT_S)
            if thread.is_alive():
                logger.error(
                    "[GeminiService] Producer thread timed out after %ds — sending sentinel.",
                    _PRODUCER_TIMEOUT_S,
                )
                loop.call_soon_threadsafe(
                    queue.put_nowait, TimeoutError("LLM producer timed out")
                )
                loop.call_soon_threadsafe(queue.put_nowait, sentinel)

        watchdog_task = asyncio.create_task(_watchdog())

        try:
            while True:
                item = await queue.get()
                if item is sentinel:
                    break
                if isinstance(item, Exception):
                    raise item
                yield item
        finally:
            watchdog_task.cancel()
            try:
                await watchdog_task
            except asyncio.CancelledError:
                pass

    async def generate_content(
        self,
        prompt: str,
        system_instruction: str = None,
        response_mime_type: str = "text/plain",
        temperature: float = 0.4,
    ) -> str:
        """Non-streaming generation for structured or short tasks."""
        if not self._initialized:
            raise RuntimeError(
                "GeminiService.initialize() must be called before calling generate_content."
            )

        # Sanitize whole prompt parts
        safe_prompt = self._sanitize(prompt)

        config = types.GenerateContentConfig(
            temperature=temperature,
            response_mime_type=response_mime_type,
            system_instruction=system_instruction,
        )

        try:
            response = self._client.models.generate_content(
                model="gemini-3-flash-preview", contents=safe_prompt, config=config
            )
            return response.text
        except Exception as exc:
            logger.error("[GeminiService] generate_content error: %s", exc, exc_info=True)
            raise exc


# Module-level singleton — imported by rag_engine and rag.py
gemini_service = GeminiService()
