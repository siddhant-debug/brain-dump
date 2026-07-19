"""
LLM provider factory. Default (LLM_PROVIDER unset or "gemini") preserves the
existing production behavior exactly. Set LLM_PROVIDER=ollama to run the same
chat/generation call sites against a local Ollama model instead — for local
dev/testing only, see backend/.env.example.
"""

import os

_LLM_PROVIDER = os.getenv("LLM_PROVIDER", "gemini").lower()

if _LLM_PROVIDER == "ollama":
    from app.services.ollama_service import OllamaService

    llm_service = OllamaService()
else:
    from app.services.gemini_service import GeminiService

    llm_service = GeminiService()
