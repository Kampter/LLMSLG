"""SQLAlchemy ORM models for game state persistence."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import Float, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def _utc_now() -> datetime:
    return datetime.now(UTC)


class Base(DeclarativeBase):
    pass


class PlayerState(Base):
    """A player's persistent game state.

    Resources grow by integer increments only.  Sub-second time is kept in
    ``last_tick_at`` and carried over to the next read.
    """

    __tablename__ = "player_states"

    user_id: Mapped[str] = mapped_column(String(64), primary_key=True)

    # Energy
    energy: Mapped[float] = mapped_column(Float, default=0.0)
    energy_capacity: Mapped[float] = mapped_column(Float, default=500.0)
    energy_rate: Mapped[float] = mapped_column(Float, default=1.0)

    # Mineral
    mineral: Mapped[float] = mapped_column(Float, default=0.0)
    mineral_capacity: Mapped[float] = mapped_column(Float, default=500.0)
    mineral_rate: Mapped[float] = mapped_column(Float, default=1.0)

    # Anchor for offline / idle income calculation
    last_tick_at: Mapped[datetime] = mapped_column(default=_utc_now)

    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        default=_utc_now,
        onupdate=_utc_now,
    )

    def compute_now(self) -> None:
        """Advance stored resources by whole seconds.

        Only complete seconds count; partial seconds remain in
        ``last_tick_at`` for the next call.  Does **not** commit.
        """
        now = _utc_now()
        last = self.last_tick_at
        # SQLite returns offset-naive datetimes; treat them as UTC.
        if last.tzinfo is None:
            last = last.replace(tzinfo=UTC)

        elapsed_seconds = int((now - last).total_seconds())
        if elapsed_seconds <= 0:
            return

        self.energy = min(
            self.energy + self.energy_rate * elapsed_seconds,
            self.energy_capacity,
        )
        self.mineral = min(
            self.mineral + self.mineral_rate * elapsed_seconds,
            self.mineral_capacity,
        )
        # Advance the anchor by *whole* seconds so fractional time carries over.
        self.last_tick_at = last + timedelta(seconds=elapsed_seconds)

    def snapshot(self) -> dict[str, Any]:
        """Return a JSON-safe dict of the *current* resource values."""
        self.compute_now()
        return {
            "user_id": self.user_id,
            "energy": int(self.energy),
            "energy_capacity": int(self.energy_capacity),
            "energy_rate": int(self.energy_rate),
            "mineral": int(self.mineral),
            "mineral_capacity": int(self.mineral_capacity),
            "mineral_rate": int(self.mineral_rate),
            "last_tick_at": self.last_tick_at.isoformat(),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }
