"""Authentication request/response models for the wire protocol."""

from __future__ import annotations

from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    """Request body for user registration."""

    username: str = Field(
        ...,
        min_length=3,
        max_length=32,
        pattern=r"^[a-zA-Z0-9_-]+$",
    )
    password: str = Field(..., min_length=8, max_length=128)
    email: str | None = Field(
        None,
        pattern=r"^[^@]+@[^@]+\.[^@]+$",
    )


class LoginRequest(BaseModel):
    """Request body for user login."""

    username: str
    password: str


class TokenResponse(BaseModel):
    """Response returned on successful authentication."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshRequest(BaseModel):
    """Request body for token refresh."""

    refresh_token: str
