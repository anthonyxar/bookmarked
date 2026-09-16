"""add start_date/end_date to club_books

Revision ID: 0006
Revises: 0005
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("club_books", sa.Column("start_date", sa.Date(), nullable=True))
    op.add_column("club_books", sa.Column("end_date", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("club_books", "end_date")
    op.drop_column("club_books", "start_date")
