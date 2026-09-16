"""book rating supports half stars

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "books",
        "rating",
        existing_type=sa.Integer(),
        type_=sa.Float(),
        existing_nullable=True,
    )

    # Backfill: recompute existing ratings to the nearest half star (round-half-up)
    # instead of the nearest whole star they were previously stored as.
    op.execute(
        """
        UPDATE books
        SET rating = FLOOR(
            (
                (COALESCE(rating_cover, 0) + COALESCE(rating_writing, 0)
                    + COALESCE(rating_plot, 0) + COALESCE(rating_characters, 0))::float
                / NULLIF(
                    (rating_cover IS NOT NULL)::int + (rating_writing IS NOT NULL)::int
                        + (rating_plot IS NOT NULL)::int + (rating_characters IS NOT NULL)::int,
                    0
                )
            ) * 2 + 0.5
        ) / 2
        WHERE rating_cover IS NOT NULL OR rating_writing IS NOT NULL
            OR rating_plot IS NOT NULL OR rating_characters IS NOT NULL
        """
    )


def downgrade() -> None:
    op.alter_column(
        "books",
        "rating",
        existing_type=sa.Float(),
        type_=sa.Integer(),
        existing_nullable=True,
    )
