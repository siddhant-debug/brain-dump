"""
OllamaService — dev/test LLM provider, swappable in for GeminiService via
app.services.llm_service (LLM_PROVIDER=ollama).

Subclasses GeminiService to reuse its prompt assembly, injection sanitization,
and streaming/watchdog machinery unchanged — only the two provider-specific
hooks (_stream_chunks / _generate_text) and initialize() are overridden.
"""

import os
import json
import logging

import httpx

from app.services.gemini_service import GeminiService

logger = logging.getLogger(__name__)


class OllamaService(GeminiService):
    def initialize(self):
        if self._initialized:
            return
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
        self._model = os.getenv("OLLAMA_MODEL", "qwen2.5:7b")
        self._client = httpx.Client(
            base_url=base_url,
            timeout=httpx.Timeout(connect=10.0, read=None, write=30.0, pool=10.0),
        )
        self._initialized = True
        logger.info(
            "[OllamaService] Configured — base_url=%s model=%s", base_url, self._model
        )

    def _stream_chunks(self, prompt: str, config):
        payload = {
            "model": self._model,
            "messages": self._to_messages(prompt, config.system_instruction),
            "stream": True,
            "options": {
                "temperature": config.temperature,
                "num_predict": config.max_output_tokens,
            },
        }
        with self._client.stream("POST", "/api/chat", json=payload) as response:
            response.raise_for_status()
            for line in response.iter_lines():
                if not line:
                    continue
                data = json.loads(line)
                content = data.get("message", {}).get("content", "")
                if content:
                    yield content

    def _generate_text(self, prompt: str, config) -> str:
        payload = {
            "model": self._model,
            "messages": self._to_messages(prompt, config.system_instruction),
            "stream": False,
            "options": {"temperature": config.temperature},
        }
        response = self._client.post("/api/chat", json=payload)
        response.raise_for_status()
        return response.json().get("message", {}).get("content", "")

    @staticmethod
    def _to_messages(prompt: str, system_instruction: str | None) -> list[dict]:
        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})
        messages.append({"role": "user", "content": prompt})
        return messages
