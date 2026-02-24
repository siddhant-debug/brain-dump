import asyncio
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.rag_engine import (
    ask_gemini,
    ask_gemini_stream,
    ask_gemini_stream_async,
)


def test_batch():
    print("--- TESTING ask_gemini (BATCH MODE) ---")
    context = "User note: I feel very stuck today. I've been doing the same thing for 3 weeks and I'm not seeing progress in my fitness goals."
    query = "Why am I stuck?"

    response = ask_gemini(context, query)
    print(f"Response:\n{response}\n")


def test_stream():
    print("--- TESTING ask_gemini_stream (SYNC) ---")
    context = "User note: I feel very stuck today. I've been doing the same thing for 3 weeks and I'm not seeing progress in my fitness goals."
    query = "Why am I stuck?"

    print("Response:")
    for chunk in ask_gemini_stream(context, query):
        if chunk:
            print(chunk, end="", flush=True)
    print("\n")


async def test_stream_async():
    print("--- TESTING ask_gemini_stream_async (ASYNC) ---")
    context = "User note: I feel very stuck today. I've been doing the same thing for 3 weeks and I'm not seeing progress in my fitness goals."
    query = "Why am I stuck?"

    print("Response:")
    async for chunk in ask_gemini_stream_async(context, query):
        if chunk:
            print(chunk, end="", flush=True)
    print("\n")


if __name__ == "__main__":
    test_batch()
    test_stream()
    asyncio.run(test_stream_async())
