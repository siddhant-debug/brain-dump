"""add health dedup index and cleanup

Revision ID: a3c17582b5a1
Revises: 28776b0b6bb3
Create Date: 2026-03-13 18:18:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'a3c17582b5a1'
down_revision = '28776b0b6bb3'
branch_labels = None
depends_on = None


def upgrade():
    # 1. Cleanup existing near-duplicate data FIRST
    # Keep only the first snapshot per 30-minute window per user.
    # This automatically resolves any 1-minute duplicates as well.
    op.execute("""
        DELETE FROM health_snapshots
        WHERE id NOT IN (
            SELECT DISTINCT ON (user_id, date_trunc('hour', fetched_at AT TIME ZONE 'UTC'), 
                                extract(minute from fetched_at AT TIME ZONE 'UTC')::int / 30)
            id FROM health_snapshots
            ORDER BY user_id, date_trunc('hour', fetched_at AT TIME ZONE 'UTC'), 
                     extract(minute from fetched_at AT TIME ZONE 'UTC')::int / 30, fetched_at ASC
        );
    """)

    # 2. Add Unique Index for deduplication safety
    # Now that duplicates are gone, this will succeed.
    op.execute("""
        CREATE UNIQUE INDEX idx_health_snapshot_dedup 
        ON health_snapshots (user_id, date_trunc('minute', fetched_at AT TIME ZONE 'UTC'));
    """)


def downgrade():
    op.execute("DROP INDEX IF EXISTS idx_health_snapshot_dedup")
