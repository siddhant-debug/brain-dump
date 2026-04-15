
import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Try to find .env in current or parent dir
load_dotenv(".env")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    # Try hardcoded default if .env is missing or doesn't have it
    DATABASE_URL = "postgresql+psycopg://postgres:password123@localhost:5433/postgres"

engine = create_engine(DATABASE_URL)

def check_sync():
    with engine.connect() as conn:
        try:
            result = conn.execute(text("SELECT count(*) FROM health_snapshots")).fetchone()
            print(f"Total Health Snapshots: {result[0]}")
            
            if result[0] > 0:
                latest = conn.execute(text("SELECT user_id, readiness, steps_today, active_energy_kcal, heart_rate, hrv, sleep, fetched_at FROM health_snapshots ORDER BY fetched_at DESC LIMIT 1")).fetchone()
                print(f"--- LATEST SNAPSHOT ---")
                print(f"User: {latest.user_id}")
                print(f"Readiness: {latest.readiness}")
                print(f"Steps: {latest.steps_today}")
                print(f"Active Energy (kcal): {latest.active_energy_kcal}")
                print(f"Heart Rate: {latest.heart_rate}")
                print(f"HRV: {latest.hrv}")
                print(f"Sleep: {latest.sleep}")
                print(f"Fetched At: {latest.fetched_at}")
            else:
                print("No health snapshots found.")
        except Exception as e:
            print(f"Error querying database: {e}")

if __name__ == "__main__":
    check_sync()

