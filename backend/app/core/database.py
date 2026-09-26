"""Base SQLAlchemy (async) des comptes et des QR Codes.

Les fichiers, les cartes publiées et les pages `/s/` gardent leur accès SQL
d'origine (`app/database.py`, `app/storage.py`) dans la même base.
"""

import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, AsyncIterator, Dict, Tuple

from fastapi import Request
from sqlalchemy import DateTime
from sqlalchemy.types import TypeDecorator
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from ..config import Settings


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class UtcDateTime(TypeDecorator):
    """Date UTC, relue avec son fuseau (SQLite ne le conserve pas)."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_result_value(self, value, dialect):
        if value is not None and value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value


class TimestampMixin:
    # Dates calculées côté Python : pas de relecture en base après une
    # écriture (interdite hors contexte async).
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime, default=utc_now, onupdate=utc_now
    )


def new_uuid() -> uuid.UUID:
    return uuid.uuid4()


def async_database_url(settings: Settings) -> Tuple[str, Dict[str, Any]]:
    """URL SQLAlchemy async et options de connexion.

    Sans `DATABASE_URL`, base SQLite locale (développement, tests). Pour
    PostgreSQL, les options `sslmode`/`channel_binding` de Neon (propres à
    libpq) sont converties pour asyncpg.
    """
    if settings.database_url is None:
        path = Path(settings.data_dir)
        path.mkdir(parents=True, exist_ok=True)
        return f"sqlite+aiosqlite:///{path / 'qr_studio.sqlite3'}", {}

    url = make_url(settings.database_url).set(drivername="postgresql+asyncpg")
    query = dict(url.query)
    sslmode = query.pop("sslmode", None)
    query.pop("channel_binding", None)
    connect_args: Dict[str, Any] = {
        # Pooler de Neon (PgBouncer) : pas de cache de requêtes préparées.
        "statement_cache_size": 0,
        "prepared_statement_name_func": lambda: f"__qr_{uuid.uuid4().hex}__",
    }
    if sslmode not in (None, "disable"):
        connect_args["ssl"] = "require"
    return url.set(query=query).render_as_string(hide_password=False), connect_args


def create_engine(settings: Settings) -> AsyncEngine:
    url, connect_args = async_database_url(settings)
    return create_async_engine(url, connect_args=connect_args, pool_pre_ping=True)


def create_sessionmaker(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(engine, expire_on_commit=False)


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    """Session de la requête (dépendance FastAPI)."""
    async with request.app.state.sessionmaker() as session:
        yield session
