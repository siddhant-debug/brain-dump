"""Merge multiple heads

Revision ID: 92981f18fcc9
Revises: 2051721b9f4d, fcc17382d5a0
Create Date: 2026-03-11 12:59:02.383843

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '92981f18fcc9'
down_revision: Union[str, Sequence[str], None] = ('2051721b9f4d', 'fcc17382d5a0')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
