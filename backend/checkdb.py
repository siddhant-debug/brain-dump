import os
from sqlalchemy import create_engine, text
from sqlalchemy.engine.reflection import Inspector

# Using psycopg (v3) as per requirements.txt
# Standard SQLAlchemy URL for psycopg 3 is postgresql+psycopg://
# If standard postgresql:// is used, it might try psycopg2 which isn't installed.
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg://postgres:password123@127.0.0.1:5433/postgres")
#test
def sync_schema():
    print(f"Connecting to: {DATABASE_URL}")
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            inspector = Inspector.from_engine(engine)
            columns = [col['name'] for col in inspector.get_columns('users')]
            
            print(f"Current columns in 'users': {columns}")
            
            # Idempotent Column Additions
            # 1. needs_loop_recalc
            if 'needs_loop_recalc' not in columns:
                print("Adding 'needs_loop_recalc'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN needs_loop_recalc BOOLEAN DEFAULT true;"))
            
            # 2. life_path_baseline
            if 'life_path_baseline' not in columns:
                print("Adding 'life_path_baseline'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN life_path_baseline JSON;"))
            
            # 3. macro_goal
            if 'macro_goal' not in columns:
                print("Adding 'macro_goal'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN macro_goal VARCHAR;"))
            
            # 4. last_lifepath_eval
            if 'last_lifepath_eval' not in columns:
                print("Adding 'last_lifepath_eval'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN last_lifepath_eval TIMESTAMP WITH TIME ZONE;"))
            
            # 5. weight/height (from health snapshot phase)
            if 'weight_kg' not in columns:
                print("Adding 'weight_kg'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN weight_kg FLOAT;"))
            if 'height_cm' not in columns:
                print("Adding 'height_cm'...")
                conn.execute(text("ALTER TABLE users ADD COLUMN height_cm FLOAT;"))

            # Check brain_embeddings
            be_columns = [col['name'] for col in inspector.get_columns('brain_embeddings')]
            if 'source_type' not in be_columns:
                print("Adding 'source_type' to brain_embeddings...")
                conn.execute(text("ALTER TABLE brain_embeddings ADD COLUMN source_type VARCHAR DEFAULT 'note' NOT NULL;"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_brain_embeddings_source_type ON brain_embeddings (source_type);"))

            # Check notes table
            note_columns = [col['name'] for col in inspector.get_columns('notes')]
            print(f"Current columns in 'notes': {note_columns}")
            
            note_missing_logic = {
                'title': "ALTER TABLE notes ADD COLUMN title VARCHAR;",
                'location_name': "ALTER TABLE notes ADD COLUMN location_name VARCHAR;",
                'music_track': "ALTER TABLE notes ADD COLUMN music_track VARCHAR;",
                'focus_mode': "ALTER TABLE notes ADD COLUMN focus_mode VARCHAR;",
                'health_readiness': "ALTER TABLE notes ADD COLUMN health_readiness VARCHAR;",
                'is_favorite': "ALTER TABLE notes ADD COLUMN is_favorite BOOLEAN DEFAULT false;",
                'sentiment': "ALTER TABLE notes ADD COLUMN sentiment VARCHAR;",
                'categories': "ALTER TABLE notes ADD COLUMN categories JSON;"
            }
            
            for col, sql in note_missing_logic.items():
                if col not in note_columns:
                    print(f"Restoring missing column: {col} in 'notes'...")
                    conn.execute(text(sql))

            conn.commit()
            print("\nSUCCESS: Database schema stabilized.")
            
    except Exception as e:
        print(f"!! ERROR: {e}")

if __name__ == "__main__":
    sync_schema()

