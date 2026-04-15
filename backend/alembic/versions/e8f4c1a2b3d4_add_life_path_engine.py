"""Add life path engine

Revision ID: e8f4c1a2b3d4
Revises: 3a2b1c4d5e6f
Create Date: 2026-03-15 16:18:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'e8f4c1a2b3d4'
down_revision = '3a2b1c4d5e6f'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Add life path columns to users
    op.add_column('users', sa.Column('life_path_baseline', sa.JSON(), nullable=True))
    op.add_column('users', sa.Column('macro_goal', sa.String(), nullable=True))
    op.add_column('users', sa.Column('last_lifepath_eval', sa.DateTime(timezone=True), nullable=True))
    
    # Add source_type to brain_embeddings
    op.add_column('brain_embeddings', sa.Column('source_type', sa.String(), server_default='note', nullable=False))
    op.create_index(op.f('ix_brain_embeddings_source_type'), 'brain_embeddings', ['source_type'], unique=False)
    
    # Create lifepath_nodes table
    op.create_table('lifepath_nodes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('computed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('trajectory', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('context_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('embedding_id', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['embedding_id'], ['brain_embeddings.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_lifepath_nodes_id'), 'lifepath_nodes', ['id'], unique=False)
    op.create_index(op.f('ix_lifepath_nodes_user_id'), 'lifepath_nodes', ['user_id'], unique=False)

    # Create music_history table
    op.create_table('music_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('artist', sa.String(), nullable=False),
        sa.Column('played_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_music_history_id'), 'music_history', ['id'], unique=False)
    op.create_index(op.f('ix_music_history_user_id'), 'music_history', ['user_id'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_music_history_user_id'), table_name='music_history')
    op.drop_index(op.f('ix_music_history_id'), table_name='music_history')
    op.drop_table('music_history')
    op.drop_index(op.f('ix_lifepath_nodes_user_id'), table_name='lifepath_nodes')
    op.drop_index(op.f('ix_lifepath_nodes_id'), table_name='lifepath_nodes')
    op.drop_table('lifepath_nodes')
    op.drop_index(op.f('ix_brain_embeddings_source_type'), table_name='brain_embeddings')
    op.drop_column('brain_embeddings', 'source_type')
    op.drop_column('users', 'last_lifepath_eval')
    op.drop_column('users', 'macro_goal')
    op.drop_column('users', 'life_path_baseline')
