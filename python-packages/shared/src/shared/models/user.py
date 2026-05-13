"""User and profile models for the wire protocol."""

from __future__ import annotations

from typing import NewType

from pydantic import BaseModel

UserId = NewType("UserId", str)


class User(BaseModel):
    """Public user record returned by the API."""

    user_id: UserId
    username: str
    email: str | None
    display_name: str | None
    created_at: str
    updated_at: str


class UserProfile(BaseModel):
    """Subset of user fields that can be updated by the owner."""

    display_name: str | None
    avatar: str | None
