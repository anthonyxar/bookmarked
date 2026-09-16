"""book clubs: membership, shared books, chapter notes, review gating, club bingo

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    club_role = postgresql.ENUM("owner", "admin", "member", name="club_role", create_type=True)
    club_membership_status = postgresql.ENUM(
        "invited", "active", "declined", "removed", name="club_membership_status", create_type=True
    )

    op.create_table(
        "book_clubs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_book_clubs_owner_id", "book_clubs", ["owner_id"])

    op.create_table(
        "club_memberships",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", club_role, nullable=False, server_default="member"),
        sa.Column("status", club_membership_status, nullable=False, server_default="invited"),
        sa.Column("invited_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("invited_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("club_id", "user_id", name="uq_club_membership_club_user"),
    )
    op.create_index("ix_club_memberships_club_id", "club_memberships", ["club_id"])
    op.create_index("ix_club_memberships_user_id", "club_memberships", ["user_id"])

    op.create_table(
        "club_books",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("author", sa.String(255), nullable=False),
        sa.Column("total_chapters", sa.Integer(), nullable=True),
        sa.Column("cover_color", sa.String(9), nullable=False, server_default="#3F5D4E"),
        sa.Column("is_current", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("picked_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_club_books_club_id", "club_books", ["club_id"])

    op.create_table(
        "club_reading_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_book_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("club_books.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("current_chapter", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("finished", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("club_book_id", "user_id", name="uq_club_progress_book_user"),
    )
    op.create_index("ix_club_reading_progress_club_book_id", "club_reading_progress", ["club_book_id"])
    op.create_index("ix_club_reading_progress_user_id", "club_reading_progress", ["user_id"])

    op.create_table(
        "club_notes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_book_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("club_books.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("chapter", sa.Integer(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_club_notes_club_book_id", "club_notes", ["club_book_id"])
    op.create_index("ix_club_notes_user_id", "club_notes", ["user_id"])

    op.create_table(
        "club_bingo_cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_club_bingo_cards_club_id", "club_bingo_cards", ["club_id"])

    op.create_table(
        "club_bingo_squares",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("club_bingo_cards.id", ondelete="CASCADE"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(120), nullable=False),
        sa.UniqueConstraint("card_id", "position", name="uq_club_bingo_square_card_position"),
    )
    op.create_index("ix_club_bingo_squares_card_id", "club_bingo_squares", ["card_id"])

    op.create_table(
        "club_member_bingo_cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("club_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("won_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("club_id", "user_id", name="uq_club_member_bingo_card_club_user"),
    )
    op.create_index("ix_club_member_bingo_cards_club_id", "club_member_bingo_cards", ["club_id"])
    op.create_index("ix_club_member_bingo_cards_user_id", "club_member_bingo_cards", ["user_id"])

    op.create_table(
        "club_member_bingo_squares",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "card_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("club_member_bingo_cards.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(120), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("locked", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.UniqueConstraint("card_id", "position", name="uq_club_member_bingo_square_card_position"),
    )
    op.create_index("ix_club_member_bingo_squares_card_id", "club_member_bingo_squares", ["card_id"])


def downgrade() -> None:
    op.drop_table("club_member_bingo_squares")
    op.drop_table("club_member_bingo_cards")
    op.drop_table("club_bingo_squares")
    op.drop_table("club_bingo_cards")
    op.drop_table("club_notes")
    op.drop_table("club_reading_progress")
    op.drop_table("club_books")
    op.drop_table("club_memberships")
    op.drop_table("book_clubs")
    postgresql.ENUM(name="club_membership_status").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="club_role").drop(op.get_bind(), checkfirst=True)
