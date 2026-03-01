import sys
import os
import json
import time
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import google.generativeai as genai

# Setup paths to import from backend
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.models.models import Note

load_dotenv()

# Setup Local DB Connection (or edit for your server's connection)
# This assumes you might run it on your local dev environment first,
# or change this URL if running directly on the Ubuntu server's docker container.
DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://postgres:password123@198.168.1.58:5433/postgres",
)
print(f"Connecting to DB: {DB_URL}")

engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

model = genai.GenerativeModel(
    "gemini-1.5-flash",
    generation_config={
        "temperature": 0.1,
        "response_mime_type": "application/json",
    },
    system_instruction="You are an analytical assistant classifying a user's journal entry. Categories should be lowercase tags (e.g., work, health, personal, finance, learning, relationships, anxiety, goals, creativity). Max 3 categories. Sentiment must be EXACTLY 'Positive', 'Negative', or 'Neutral'.",
)


def analyze_thought(content: str) -> dict:
    prompt = f"""
    Analyze the following thought. Return a JSON object with this exact structure:
    {{
        "sentiment": "Positive" | "Negative" | "Neutral",
        "categories": ["tag1", "tag2"]
    }}

    Thought: "{content}"
    """
    try:
        response = model.generate_content(prompt)
        return json.loads(response.text)
    except Exception as e:
        print(f"[ERROR] LLM Insight Analysis failed: {e}")
        return {"sentiment": "Neutral", "categories": []}


try:
    print("Fetching notes without sentiment/categories...")
    # Find notes where sentiment is null or categories is null
    notes_to_process = (
        db.query(Note)
        .filter((Note.sentiment == None) | (Note.categories == None))
        .all()
    )

    total = len(notes_to_process)
    print(f"Found {total} notes to process.")

    if total == 0:
        print("Nothing to backfill!")
        sys.exit(0)

    processed = 0
    for note in notes_to_process:
        print(f"Processing note {note.id} ({processed+1}/{total})...")
        insights = analyze_thought(note.content)

        note.sentiment = insights.get("sentiment", "Neutral")
        note.categories = insights.get("categories", [])

        db.commit()
        processed += 1

        # Sleep to avoid hitting Gemini rate limits (adjust based on your tier)
        time.sleep(1)

    print(f"Backfill Complete: {processed} notes updated.")

except Exception as e:
    print(f"Backfill Failed: {e}")
    db.rollback()
finally:
    db.close()
