"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-09-14

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("reading_goal", sa.Integer(), nullable=False, server_default="40"),
        sa.Column("genres", postgresql.ARRAY(sa.String()), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_email", "users", ["email"])

    book_format = postgresql.ENUM("physical", "ebook", "audiobook", name="book_format", create_type=True)

    op.create_table(
        "books",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("author", sa.String(255), nullable=False),
        sa.Column("series", sa.String(255), nullable=True),
        sa.Column("book_no", sa.Integer(), nullable=True),
        sa.Column("genre", sa.String(120), nullable=True),
        sa.Column("cover_color", sa.String(9), nullable=False, server_default="#3F5D4E"),
        sa.Column("published", sa.String(60), nullable=True),
        sa.Column("pages", sa.Integer(), nullable=True),
        sa.Column("format", book_format, nullable=False, server_default="physical"),
        sa.Column("purchased", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("times_read", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("rating_cover", sa.Integer(), nullable=True),
        sa.Column("rating_writing", sa.Integer(), nullable=True),
        sa.Column("rating_plot", sa.Integer(), nullable=True),
        sa.Column("rating_characters", sa.Integer(), nullable=True),
        sa.Column("enjoyed", sa.Boolean(), nullable=True),
        sa.Column("read_again", sa.Boolean(), nullable=True),
        sa.Column("liked_most", sa.Text(), nullable=True),
        sa.Column("liked_least", sa.Text(), nullable=True),
        sa.Column("feel", sa.Text(), nullable=True),
        sa.Column("trope", sa.String(120), nullable=True),
        sa.Column("final_review", sa.Text(), nullable=True),
        sa.Column("favorite_characters", postgresql.ARRAY(sa.String()), nullable=False, server_default="{}"),
        sa.Column("notable_scenes", postgresql.ARRAY(sa.String()), nullable=False, server_default="{}"),
        sa.Column("quotes", postgresql.ARRAY(sa.String()), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_books_user_id", "books", ["user_id"])

    op.create_table(
        "bingo_cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "year", name="uq_bingo_card_user_year"),
    )
    op.create_index("ix_bingo_cards_user_id", "bingo_cards", ["user_id"])

    op.create_table(
        "bingo_squares",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("bingo_cards.id", ondelete="CASCADE"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(120), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("locked", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.UniqueConstraint("card_id", "position", name="uq_bingo_square_card_position"),
    )
    op.create_index("ix_bingo_squares_card_id", "bingo_squares", ["card_id"])


def downgrade() -> None:
    op.drop_table("bingo_squares")
    op.drop_table("bingo_cards")
    op.drop_table("books")
    op.drop_table("users")
    postgresql.ENUM(name="book_format").drop(op.get_bind(), checkfirst=True)
