"""schema catchup

Revision ID: f3d4e5f6g7h8
Revises: a3c17582b5a1
Create Date: 2026-03-15 18:20:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

# revision identifiers, used by Alembic.
revision = 'f3d4e5f6g7h8'
down_revision = 'a3c17582b5a1'
branch_labels = None
depends_on = None

def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    user_columns = [col['name'] for col in inspector.get_columns('users')]
    
    # Add missing columns to users
    if 'needs_loop_recalc' not in user_columns:
        op.add_column('users', sa.Column('needs_loop_recalc', sa.Boolean(), server_default='true', nullable=True))
    
    if 'life_path_baseline' not in user_columns:
        op.add_column('users', sa.Column('life_path_baseline', sa.JSON(), nullable=True))
    
    if 'macro_goal' not in user_columns:
        op.add_column('users', sa.Column('macro_goal', sa.String(), nullable=True))
    
    if 'last_lifepath_eval' not in user_columns:
        op.add_column('users', sa.Column('last_lifepath_eval', sa.DateTime(timezone=True), nullable=True))

    # Add source_type to brain_embeddings if missing
    be_columns = [col['name'] for col in inspector.get_columns('brain_embeddings')]
    if 'source_type' not in be_columns:
        op.add_column('brain_embeddings', sa.Column('source_type', sa.String(), server_default='note', nullable=False))
        op.create_index(op.f('ix_brain_embeddings_source_type'), 'brain_embeddings', ['source_type'], unique=False)

def downgrade() -> None:
    pass
