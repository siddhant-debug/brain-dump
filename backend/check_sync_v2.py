
import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv(".env")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    DATABASE_URL = "postgresql+psycopg://postgres:password123@localhost:5433/postgres"

engine = create_engine(DATABASE_URL)

def check_sync():
    with engine.connect() as conn:
        try:
            result = conn.execute(text("SELECT user_id, readiness, steps_today, active_energy_kcal, heart_rate, hrv, sleep, fetched_at FROM health_snapshots ORDER BY fetched_at DESC LIMIT 1")).fetchone()
            if result:
                print(f"--- LATEST SNAPSHOT DETAILS ---")
                print(f"Readiness: {result.readiness}")
                print(f"Steps: {result.steps_today} (Type: {type(result.steps_today)})")
                print(f"Active Energy: {result.active_energy_kcal}")
                print(f"Heart Rate: {result.heart_rate}")
                print(f"HRV: {result.hrv}")
                print(f"Sleep: {result.sleep}")
                
                # Check for other snapshots to see if they are updating
                history = conn.execute(text("SELECT steps_today, fetched_at FROM health_snapshots ORDER BY fetched_at DESC LIMIT 5")).fetchall()
                print("\n--- RECENT HISTORY (Steps) ---")
                for row in history:
                    print(f"- {row.steps_today} at {row.fetched_at}")
            else:
                print("No snapshots found.")
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    check_sync()
