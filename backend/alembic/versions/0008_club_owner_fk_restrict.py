"""restrict delete of a user who owns a club

Revision ID: 0008
Revises: 0007
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # book_clubs.owner_id -> users.id was ON DELETE CASCADE, meaning
    # deleting a user silently deleted every club they own out from under
    # their members. Switch to RESTRICT so that path fails loudly instead;
    # a club must be deleted or handed off before its owner's account can be.
    op.drop_constraint("book_clubs_owner_id_fkey", "book_clubs", type_="foreignkey")
    op.create_foreign_key(
        "book_clubs_owner_id_fkey",
        "book_clubs",
        "users",
        ["owner_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint("book_clubs_owner_id_fkey", "book_clubs", type_="foreignkey")
    op.create_foreign_key(
        "book_clubs_owner_id_fkey",
        "book_clubs",
        "users",
        ["owner_id"],
        ["id"],
        ondelete="CASCADE",
    )
