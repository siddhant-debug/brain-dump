"""Merge life path and health dedup

Revision ID: 70db9ec6a3cd
Revises: a3c17582b5a1, e8f4c1a2b3d4
Create Date: 2026-03-15 11:16:46.639184

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '70db9ec6a3cd'
down_revision: Union[str, Sequence[str], None] = ('a3c17582b5a1', 'e8f4c1a2b3d4')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    pass

def downgrade() -> None:
    pass
