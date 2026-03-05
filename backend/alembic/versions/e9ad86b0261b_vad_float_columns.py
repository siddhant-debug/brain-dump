"""Add VAD Float columns to MusicVibeCache

Revision ID: e9ad86b0261b
Revises: b32af39acf33
Create Date: 2026-03-06 00:00:00.000000

NOTE: JSON → FLOAT requires explicit USING clause in PostgreSQL.
op.alter_column() cannot auto-cast JSON to double precision, so we use
raw SQL with (col #>> '{}')::float which extracts the JSON root value as
text and casts to float. Handles NULL values gracefully.
"""

from typing import Sequence, Union
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e9ad86b0261b"
down_revision: Union[str, Sequence[str], None] = "b32af39acf33"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Change valence, arousal, dominance columns from JSON to FLOAT.

    Uses USING (col #>> '{}')::float to extract the JSON scalar value
    as text and cast to double precision — the only way PostgreSQL allows
    this type transition.
    """
    op.execute(
        """
        ALTER TABLE music_vibe_cache
            ALTER COLUMN valence   TYPE FLOAT USING (valence   #>> '{}')::float,
            ALTER COLUMN arousal   TYPE FLOAT USING (arousal   #>> '{}')::float,
            ALTER COLUMN dominance TYPE FLOAT USING (dominance #>> '{}')::float
    """
    )


def downgrade() -> None:
    """Revert FLOAT columns back to JSON."""
    op.execute(
        """
        ALTER TABLE music_vibe_cache
            ALTER COLUMN valence   TYPE JSON USING to_json(valence),
            ALTER COLUMN arousal   TYPE JSON USING to_json(arousal),
            ALTER COLUMN dominance TYPE JSON USING to_json(dominance)
    """
    )
