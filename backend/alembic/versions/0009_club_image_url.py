"""add image_url to book_clubs

Revision ID: 0009
Revises: 0008
Create Date: 2026-09-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("book_clubs", sa.Column("image_url", sa.String(1024), nullable=True))


def downgrade() -> None:
    op.drop_column("book_clubs", "image_url")
