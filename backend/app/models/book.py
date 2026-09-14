import enum
import uuid
from datetime import date, datetime

from sqlalchemy import ARRAY, Boolean, Date, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BookFormat(str, enum.Enum):
    physical = "physical"
    ebook = "ebook"
    audiobook = "audiobook"


class Book(Base):
    __tablename__ = "books"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    author: Mapped[str] = mapped_column(String(255), nullable=False)
    series: Mapped[str | None] = mapped_column(String(255), nullable=True)
    book_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    genre: Mapped[str | None] = mapped_column(String(120), nullable=True)
    cover_color: Mapped[str] = mapped_column(String(9), default="#3F5D4E", nullable=False)
    published: Mapped[str | None] = mapped_column(String(60), nullable=True)
    pages: Mapped[int | None] = mapped_column(Integer, nullable=True)
    format: Mapped[BookFormat] = mapped_column(Enum(BookFormat, name="book_format"), default=BookFormat.physical, nullable=False)

    purchased: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    times_read: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # journal-style review, all nullable until the book is read
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rating_cover: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rating_writing: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rating_plot: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rating_characters: Mapped[int | None] = mapped_column(Integer, nullable=True)
    enjoyed: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    read_again: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    liked_most: Mapped[str | None] = mapped_column(Text, nullable=True)
    liked_least: Mapped[str | None] = mapped_column(Text, nullable=True)
    feel: Mapped[str | None] = mapped_column(Text, nullable=True)
    trope: Mapped[str | None] = mapped_column(String(120), nullable=True)
    final_review: Mapped[str | None] = mapped_column(Text, nullable=True)
    favorite_characters: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, nullable=False)
    notable_scenes: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, nullable=False)
    quotes: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    owner: Mapped["User"] = relationship(back_populates="books")
