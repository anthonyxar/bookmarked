import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BingoCard(Base):
    __tablename__ = "bingo_cards"
    __table_args__ = (UniqueConstraint("user_id", "year", name="uq_bingo_card_user_year"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    owner: Mapped["User"] = relationship(back_populates="bingo_cards")
    squares: Mapped[list["BingoSquare"]] = relationship(
        back_populates="card", cascade="all, delete-orphan", order_by="BingoSquare.position"
    )


class BingoSquare(Base):
    __tablename__ = "bingo_squares"
    __table_args__ = (UniqueConstraint("card_id", "position", name="uq_bingo_square_card_position"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("bingo_cards.id", ondelete="CASCADE"), nullable=False, index=True)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    card: Mapped["BingoCard"] = relationship(back_populates="squares")
