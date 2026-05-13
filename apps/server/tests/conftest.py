"""Pytest fixtures shared by tests/ in this package."""

from __future__ import annotations

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from server.app import create_app
from server.persistence.models import Base
from server.rpc.resources import _get_db
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool


@pytest_asyncio.fixture
async def test_db():
    """In-memory engine + sessionmaker shared by client and direct DB access."""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_maker = async_sessionmaker(engine, expire_on_commit=False)

    async def _override_get_db():
        async with session_maker() as session:
            yield session

    yield {
        "engine": engine,
        "session_maker": session_maker,
        "override_get_db": _override_get_db,
    }

    await engine.dispose()


@pytest_asyncio.fixture
async def client(test_db):
    """HTTP client pointing at an in-memory app instance."""
    app = create_app()
    app.dependency_overrides[_get_db] = test_db["override_get_db"]

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest_asyncio.fixture
async def db_session(test_db):
    """Fresh session for direct DB manipulation in tests."""
    session_maker = test_db["session_maker"]
    async with session_maker() as session:
        yield session
