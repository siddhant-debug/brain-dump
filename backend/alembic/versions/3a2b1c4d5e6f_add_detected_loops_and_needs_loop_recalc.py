"""Add detected_loops and needs_loop_recalc

Revision ID: 3a2b1c4d5e6f
Revises: 2051721b9f4d, fcc17382d5a0
Create Date: 2026-03-11 17:58:30.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '3a2b1c4d5e6f'
down_revision = ('2051721b9f4d', 'fcc17382d5a0')
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Add needs_loop_recalc to users
    op.add_column('users', sa.Column('needs_loop_recalc', sa.Boolean(), server_default='true', nullable=True))
    
    # Create detected_loops table
    op.create_table('detected_loops',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('theme_guess', sa.String(), nullable=False),
        sa.Column('severity', sa.String(), nullable=True),
        sa.Column('occurrences', sa.Integer(), nullable=True),
        sa.Column('path_forward', sa.String(), nullable=True),
        sa.Column('first_seen', sa.String(), nullable=True),
        sa.Column('last_seen', sa.String(), nullable=True),
        sa.Column('notes_json', sa.JSON(), nullable=False),
        sa.Column('computed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_detected_loops_user_id'), 'detected_loops', ['user_id'], unique=False)

def downgrade() -> None:
    # Drop detected_loops table
    op.drop_index(op.f('ix_detected_loops_user_id'), table_name='detected_loops')
    op.drop_table('detected_loops')

    # Drop needs_loop_recalc from users
    op.drop_column('users', 'needs_loop_recalc')
