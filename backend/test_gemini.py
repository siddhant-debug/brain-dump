import os
import asyncio
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=API_KEY)

async def test():
    print("Testing gemini-1.5-flash...")
    model = genai.GenerativeModel('gemini-1.5-flash')
    try:
        response = await model.generate_content_async("Hello!", stream=True)
        async for chunk in response:
            print(chunk.text, end="")
        print("\n✅ gemini-1.5-flash works!")
    except Exception as e:
        print(f"\nError: {e}")

    try:
        print("\nTesting gemini-3-flash-preview...")
        model2 = genai.GenerativeModel('gemini-3-flash-preview')
        response2 = await model2.generate_content_async("Hello!", stream=True)
        async for chunk in response2:
            print(chunk.text, end="")
        print("\n✅ gemini-3-flash-preview works!")
    except Exception as e:
        print(f"\nError: {e}")

asyncio.run(test())
