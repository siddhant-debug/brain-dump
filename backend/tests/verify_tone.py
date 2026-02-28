import asyncio
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.rag_engine import (
    ask_gemini,
    ask_gemini_stream_async,
)

CONTEXT = "User note: I feel very stuck today. I've been doing the same thing for 3 weeks and I'm not seeing progress in my fitness goals."
QUERY = "Why am I stuck?"


def test_batch():
    print("--- TESTING ask_gemini (BATCH MODE) ---")
    response = ask_gemini(CONTEXT, QUERY)
    print(f"Response:\n{response}\n")


async def test_stream_async():
    # Uses ask_gemini_stream_async directly — same production path,
    # same GeminiService persona (tone layer + emotional state fully active).
    print("--- TESTING ask_gemini_stream_async (ASYNC / PRODUCTION PATH) ---")
    print("Response:")
    async for chunk in ask_gemini_stream_async(CONTEXT, QUERY):
        if chunk:
            print(chunk, end="", flush=True)
    print("\n")


if __name__ == "__main__":
    test_batch()
    asyncio.run(test_stream_async())
