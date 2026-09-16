"""add cover_url to club_books

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("club_books", sa.Column("cover_url", sa.String(1024), nullable=True))


def downgrade() -> None:
    op.drop_column("club_books", "cover_url")
