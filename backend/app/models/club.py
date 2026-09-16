import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ClubRole(str, enum.Enum):
    owner = "owner"
    admin = "admin"
    member = "member"


class ClubMembershipStatus(str, enum.Enum):
    invited = "invited"
    active = "active"
    declined = "declined"
    removed = "removed"


class BookClub(Base):
    __tablename__ = "book_clubs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # RESTRICT (not CASCADE): deleting a user who still owns a club must
    # fail loudly rather than silently delete the club for every member.
    owner_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    memberships: Mapped[list["ClubMembership"]] = relationship(back_populates="club", cascade="all, delete-orphan")
    books: Mapped[list["ClubBook"]] = relationship(back_populates="club", cascade="all, delete-orphan")
    bingo_card: Mapped["ClubBingoCard | None"] = relationship(back_populates="club", cascade="all, delete-orphan", uselist=False)


class ClubMembership(Base):
    __tablename__ = "club_memberships"
    __table_args__ = (UniqueConstraint("club_id", "user_id", name="uq_club_membership_club_user"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role: Mapped[ClubRole] = mapped_column(Enum(ClubRole, name="club_role"), default=ClubRole.member, nullable=False)
    status: Mapped[ClubMembershipStatus] = mapped_column(
        Enum(ClubMembershipStatus, name="club_membership_status"), default=ClubMembershipStatus.invited, nullable=False
    )
    invited_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    invited_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    joined_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    club: Mapped["BookClub"] = relationship(back_populates="memberships")
    user: Mapped["User"] = relationship(foreign_keys=[user_id])


class ClubBook(Base):
    __tablename__ = "club_books"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    author: Mapped[str] = mapped_column(String(255), nullable=False)
    total_chapters: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cover_color: Mapped[str] = mapped_column(String(9), default="#3F5D4E", nullable=False)
    cover_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    picked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    club: Mapped["BookClub"] = relationship(back_populates="books")
    progress: Mapped[list["ClubReadingProgress"]] = relationship(back_populates="club_book", cascade="all, delete-orphan")
    notes: Mapped[list["ClubNote"]] = relationship(back_populates="club_book", cascade="all, delete-orphan")


class ClubReadingProgress(Base):
    __tablename__ = "club_reading_progress"
    __table_args__ = (UniqueConstraint("club_book_id", "user_id", name="uq_club_progress_book_user"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("club_books.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    current_chapter: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    finished: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    club_book: Mapped["ClubBook"] = relationship(back_populates="progress")
    user: Mapped["User"] = relationship(foreign_keys=[user_id])


class ClubNote(Base):
    __tablename__ = "club_notes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("club_books.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    chapter: Mapped[int] = mapped_column(Integer, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    club_book: Mapped["ClubBook"] = relationship(back_populates="notes")
    user: Mapped["User"] = relationship(foreign_keys=[user_id])


class ClubBingoCard(Base):
    """Club-wide template of 25 labels, authored once by the owner/admin."""

    __tablename__ = "club_bingo_cards"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    club: Mapped["BookClub"] = relationship(back_populates="bingo_card")
    squares: Mapped[list["ClubBingoSquare"]] = relationship(
        back_populates="card", cascade="all, delete-orphan", order_by="ClubBingoSquare.position"
    )


class ClubBingoSquare(Base):
    __tablename__ = "club_bingo_squares"
    __table_args__ = (UniqueConstraint("card_id", "position", name="uq_club_bingo_square_card_position"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("club_bingo_cards.id", ondelete="CASCADE"), nullable=False, index=True)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str] = mapped_column(String(120), nullable=False)

    card: Mapped["ClubBingoCard"] = relationship(back_populates="squares")


class ClubMemberBingoCard(Base):
    """A member's own copy of the club template, checked off individually."""

    __tablename__ = "club_member_bingo_cards"
    __table_args__ = (UniqueConstraint("club_id", "user_id", name="uq_club_member_bingo_card_club_user"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    club_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("book_clubs.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    won_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship(foreign_keys=[user_id])
    squares: Mapped[list["ClubMemberBingoSquare"]] = relationship(
        back_populates="card", cascade="all, delete-orphan", order_by="ClubMemberBingoSquare.position"
    )


class ClubMemberBingoSquare(Base):
    __tablename__ = "club_member_bingo_squares"
    __table_args__ = (UniqueConstraint("card_id", "position", name="uq_club_member_bingo_square_card_position"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    card_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("club_member_bingo_cards.id", ondelete="CASCADE"), nullable=False, index=True
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    card: Mapped["ClubMemberBingoCard"] = relationship(back_populates="squares")
