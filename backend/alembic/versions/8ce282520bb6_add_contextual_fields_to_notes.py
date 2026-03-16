"""Add contextual fields to notes

Revision ID: 8ce282520bb6
Revises: 70db9ec6a3cd
Create Date: 2026-03-15 11:51:36.704925

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '8ce282520bb6'
down_revision: Union[str, Sequence[str], None] = '70db9ec6a3cd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Using existence checks to prevent crashes if columns already exist on other branches
    conn = op.get_bind()
    from sqlalchemy.engine.reflection import Inspector
    inspector = Inspector.from_engine(conn)
    
    # Drop index if it exists
    tables = inspector.get_table_names()
    if 'health_snapshots' in tables:
        indices = [idx['name'] for idx in inspector.get_indexes('health_snapshots')]
        if 'idx_health_snapshot_dedup' in indices:
            op.drop_index(op.f('idx_health_snapshot_dedup'), table_name='health_snapshots')

    if 'users' in tables:
        columns = [col['name'] for col in inspector.get_columns('users')]
        if 'last_lifepath_eval' in columns:
            op.drop_column('users', 'last_lifepath_eval')

def downgrade() -> None:
    op.add_column('users', sa.Column('last_lifepath_eval', postgresql.TIMESTAMP(timezone=True), autoincrement=False, nullable=True))
    op.create_index(op.f('idx_health_snapshot_dedup'), 'health_snapshots', ['user_id', sa.literal_column("date_trunc('minute'::text, (fetched_at AT TIME ZONE 'UTC'::text))")], unique=True)
