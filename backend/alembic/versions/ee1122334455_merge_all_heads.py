"""Merge all heads

Revision ID: ee1122334455
Revises: 28776b0b6bb3, 8ce282520bb6, f3d4e5f6g7h8
Create Date: 2026-03-16 22:45:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'ee1122334455'
down_revision = ('28776b0b6bb3', '8ce282520bb6', 'f3d4e5f6g7h8')
branch_labels = None
depends_on = None

def upgrade() -> None:
    pass

def downgrade() -> None:
    pass
