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

    conn = op.get_bind()

    # 2. Backfill user_id from the metadata JSONB column
    op.execute(
        "UPDATE brain_embeddings SET user_id = CAST(metadata->>'user_id' AS INTEGER) WHERE metadata->>'user_id' IS NOT NULL"
    )

    # DEBUG: Count orphaned embeddings before delete
    orphaned_count_query = "SELECT COUNT(*) FROM brain_embeddings WHERE user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = brain_embeddings.user_id)"
    before_count = conn.execute(sa.text(orphaned_count_query)).scalar()
    print(f"\n[DEBUG] Orphaned embeddings before delete: {before_count}\n")

    # 3. Clean up orphaned embeddings
    op.execute(
        "DELETE FROM brain_embeddings WHERE user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = brain_embeddings.user_id)"
    )

    # DEBUG: Count orphaned embeddings after delete
    after_count = conn.execute(sa.text(orphaned_count_query)).scalar()
    print(f"\n[DEBUG] Orphaned embeddings after delete: {after_count}\n")

    # Fail intentionally if there are still orphans to prevent ForeignKey error from masking it
    if after_count > 0:
        raise Exception(f"Failed to delete {after_count} orphaned embeddings!")

    # 4. Alter column to be NOT NULL
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
