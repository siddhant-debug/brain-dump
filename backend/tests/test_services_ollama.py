# backend/tests/test_services_ollama.py
import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.ollama_service import OllamaService
from google.genai import types


@pytest.fixture
def ollama_service(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://localhost:11434")
    monkeypatch.setenv("OLLAMA_MODEL", "qwen2.5:7b")
    # OllamaService subclasses GeminiService's singleton (__new__ keys off
    # cls._instance) — reset so this test gets a fresh instance.
    OllamaService._instance = None
    return OllamaService()


@patch("httpx.Client")
def test_ollama_stream_chunks_yields_text(mock_httpx_client, ollama_service):
    """Streaming hook parses Ollama's NDJSON /api/chat stream into text chunks."""
    mock_client_instance = mock_httpx_client.return_value
    ollama_service.initialize()

    lines = [
        json.dumps({"message": {"content": "Hello "}}),
        json.dumps({"message": {"content": "world!"}}),
        json.dumps({"message": {"content": ""}, "done": True}),
    ]
    mock_response = MagicMock()
    mock_response.iter_lines.return_value = lines
    mock_response.__enter__.return_value = mock_response
    mock_response.__exit__.return_value = False
    mock_client_instance.stream.return_value = mock_response

    config = types.GenerateContentConfig(
        temperature=0.4, max_output_tokens=100, system_instruction="be terse"
    )
    chunks = list(ollama_service._stream_chunks("Hi", config))

    assert chunks == ["Hello ", "world!"]
    called_payload = mock_client_instance.stream.call_args.kwargs["json"]
    assert called_payload["model"] == "qwen2.5:7b"
    assert called_payload["messages"][0] == {"role": "system", "content": "be terse"}
    assert called_payload["messages"][1] == {"role": "user", "content": "Hi"}


@patch("httpx.Client")
def test_ollama_generate_text_returns_content(mock_httpx_client, ollama_service):
    """Non-streaming hook returns the assistant message content."""
    mock_client_instance = mock_httpx_client.return_value
    ollama_service.initialize()

    mock_response = MagicMock()
    mock_response.json.return_value = {"message": {"content": '{"ok": true}'}}
    mock_client_instance.post.return_value = mock_response

    config = types.GenerateContentConfig(temperature=0.4, response_mime_type="application/json")
    result = ollama_service._generate_text("Give me JSON", config)

    assert result == '{"ok": true}'
