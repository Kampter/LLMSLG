"""Round-trip serialization tests for auth and user models."""

from __future__ import annotations

import json

from shared.models.auth import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from shared.models.user import User, UserId, UserProfile


def test_register_request_serialization() -> None:
    req = RegisterRequest(username="alice", password="secure1234")
    data = json.loads(req.model_dump_json())
    assert data["username"] == "alice"
    assert data["password"] == "secure1234"
    assert data["email"] is None


def test_register_request_with_email_serialization() -> None:
    req = RegisterRequest(
        username="alice",
        password="secure1234",
        email="alice@example.com",
    )
    data = json.loads(req.model_dump_json())
    assert data["email"] == "alice@example.com"


def test_login_request_serialization() -> None:
    req = LoginRequest(username="alice", password="secret")
    data = json.loads(req.model_dump_json())
    assert data["username"] == "alice"
    assert data["password"] == "secret"


def test_token_response_serialization() -> None:
    resp = TokenResponse(access_token="tok", expires_in=3600)
    data = json.loads(resp.model_dump_json())
    assert data["access_token"] == "tok"
    assert data["token_type"] == "bearer"
    assert data["expires_in"] == 3600


def test_refresh_request_serialization() -> None:
    req = RefreshRequest(refresh_token="refresh_tok")
    data = json.loads(req.model_dump_json())
    assert data["refresh_token"] == "refresh_tok"


def test_user_serialization() -> None:
    user = User(
        user_id=UserId("alice"),
        username="alice",
        email=None,
        display_name=None,
        created_at="2024-01-01T00:00:00Z",
        updated_at="2024-01-01T00:00:00Z",
    )
    data = json.loads(user.model_dump_json())
    assert data["user_id"] == "alice"
    assert data["username"] == "alice"
    assert data["email"] is None
    assert data["display_name"] is None
    assert data["created_at"] == "2024-01-01T00:00:00Z"
    assert data["updated_at"] == "2024-01-01T00:00:00Z"


def test_user_profile_serialization() -> None:
    profile = UserProfile(display_name="Alice", avatar="https://example.com/avatar.png")
    data = json.loads(profile.model_dump_json())
    assert data["display_name"] == "Alice"
    assert data["avatar"] == "https://example.com/avatar.png"


def test_user_id_newtype_preserves_str() -> None:
    uid = UserId("user-123")
    assert uid == "user-123"
    assert isinstance(uid, str)
