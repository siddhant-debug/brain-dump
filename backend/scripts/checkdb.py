from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy.engine.reflection import Inspector
import os

# Ensure this matches your server's DB connection string
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password123@localhost/braindump")

def check_schema():
    engine = create_engine(DATABASE_URL)
    inspector = Inspector.from_engine(engine)
    print("--- Database Schema Check ---")
    if 'users' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('users')]
        print(f"Table 'users' exists with columns: {columns}")
        required = ['needs_loop_recalc', 'life_path_baseline', 'macro_goal', 'last_lifepath_eval']
        missing = [c for c in required if c not in columns]
        if missing: print(f"MISSING COLUMNS: {missing}")
        else: print("All required columns are present.")
    else: print("Table 'users' NOT FOUND!")
    
    if 'alembic_version' in inspector.get_table_names():
        with engine.connect() as conn:
            from sqlalchemy import text
            res = conn.execute(text("SELECT version_num FROM alembic_version")).fetchall()
            print(f"Alembic Version: {[r[0] for r in res]}")

if __name__ == "__main__":
    check_schema()

