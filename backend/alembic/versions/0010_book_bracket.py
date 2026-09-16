"""add monthly_favorites and bracket_picks

Revision ID: 0010
Revises: 0009
Create Date: 2026-09-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "monthly_favorites",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("month", sa.Integer(), nullable=False),
        sa.Column("book_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("books.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "year", "month", name="uq_monthly_favorite_user_year_month"),
    )
    op.create_index("ix_monthly_favorites_user_id", "monthly_favorites", ["user_id"])

    op.create_table(
        "bracket_picks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("match_id", sa.String(16), nullable=False),
        sa.Column("book_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("books.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "year", "match_id", name="uq_bracket_pick_user_year_match"),
    )
    op.create_index("ix_bracket_picks_user_id", "bracket_picks", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_bracket_picks_user_id", table_name="bracket_picks")
    op.drop_table("bracket_picks")
    op.drop_index("ix_monthly_favorites_user_id", table_name="monthly_favorites")
    op.drop_table("monthly_favorites")
