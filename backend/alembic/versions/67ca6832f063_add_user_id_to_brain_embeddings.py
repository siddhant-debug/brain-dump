"""add_user_id_to_brain_embeddings

Revision ID: 67ca6832f063
Revises:
Create Date: 2026-02-28 11:28:38.259490

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "67ca6832f063"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. Add column as nullable first
    op.add_column("brain_embeddings", sa.Column("user_id", sa.Integer(), nullable=True))

    # 2. Backfill user_id from the metadata JSONB column
    # NOTE: The python model property is `metadata_` but the DB column is `metadata`.
    op.execute(
        "UPDATE brain_embeddings SET user_id = CAST(metadata->>'user_id' AS INTEGER) WHERE metadata->>'user_id' IS NOT NULL"
    )

    # 3. Alter column to be NOT NULL
    op.alter_column(
        "brain_embeddings", "user_id", existing_type=sa.Integer(), nullable=False
    )

    # 4. Create index and foreign key
    op.create_index(
        op.f("ix_brain_embeddings_user_id"),
        "brain_embeddings",
        ["user_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_brain_embedding_user", "brain_embeddings", "users", ["user_id"], ["id"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "fk_brain_embedding_user", "brain_embeddings", type_="foreignkey"
    )
    op.drop_index(op.f("ix_brain_embeddings_user_id"), table_name="brain_embeddings")
    op.drop_column("brain_embeddings", "user_id")
