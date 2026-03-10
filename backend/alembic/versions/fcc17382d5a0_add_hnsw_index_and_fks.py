"""add_hnsw_index_and_fks

Revision ID: fcc17382d5a0
Revises: e9ad86b0261b
Create Date: 2026-03-10 13:17:00.000000

"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "fcc17382d5a0"
down_revision: Union[str, Sequence[str], None] = "e9ad86b0261b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Ensure vector extension exists
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # 2. Add HNSW index CONCURRENTLY (avoids table lock)
    # Note: Using autocommit_block() to allow CREATE INDEX CONCURRENTLY
    with op.get_context().autocommit_block():
        op.execute(
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_brain_embeddings_hnsw "
            "ON brain_embeddings USING hnsw (embedding vector_cosine_ops) "
            "WITH (m = 16, ef_construction = 64)"
        )

    # 3. Add Foreign Key constraints and handle existing data
    # Note: We use batch_op for SQLite compatibility, but for Postgres it's direct ALTER
    # Adding ForeignKey constraints with CASCADE
    op.create_foreign_key(
        "fk_stored_files_user_id",
        "stored_files",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_notes_user_id", "notes", "users", ["user_id"], ["id"], ondelete="CASCADE"
    )
    op.create_foreign_key(
        "fk_chat_messages_user_id",
        "chat_messages",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_user_directives_user_id",
        "user_directives",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    # Remove Foreign Keys
    op.drop_constraint(
        "fk_user_directives_user_id", "user_directives", type_="foreignkey"
    )
    op.drop_constraint("fk_chat_messages_user_id", "chat_messages", type_="foreignkey")
    op.drop_constraint("fk_notes_user_id", "notes", type_="foreignkey")
    op.drop_constraint("fk_stored_files_user_id", "stored_files", type_="foreignkey")

    # Remove HNSW index
    op.execute("DROP INDEX IF EXISTS idx_brain_embeddings_hnsw")
