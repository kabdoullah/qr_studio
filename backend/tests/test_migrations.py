"""Les migrations Alembic produisent le schéma attendu par l'application."""

import uuid
from datetime import datetime, timezone
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient

from app.config import Settings, psycopg_url
from app.core.security import hash_password
from app.main import create_app
from tests.helpers import PASSWORD, register

_BACKEND = Path(__file__).resolve().parent.parent


@pytest.mark.parametrize("use_postgres", [False, True])
def test_migrations_create_the_schema(tmp_path, monkeypatch, request, use_postgres):
    database_url = request.getfixturevalue("database_url") if use_postgres else None
    for key in ("RENDER", "APP_ENV", "DATABASE_URL"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("QR_STUDIO_DATA_DIR", str(tmp_path))
    if database_url:
        monkeypatch.setenv("DATABASE_URL", database_url)
    config = Config(str(_BACKEND / "alembic.ini"))
    config.set_main_option("script_location", str(_BACKEND / "migrations"))

    command.upgrade(config, "head")
    # Aucune différence entre les modèles et le schéma migré.
    command.check(config)

    settings = Settings(
        public_url="https://qr.test", data_dir=tmp_path, database_url=database_url
    )
    with TestClient(create_app(settings)) as client:
        client.headers.update(register(client))
        response = client.post(
            "/api/v1/qr-codes",
            json={"type": "text", "title": "Test", "content": {"text": "Bonjour"}},
        )
    assert response.status_code == 201

    command.downgrade(config, "base")


@pytest.mark.parametrize("use_postgres", [False, True])
def test_existing_accounts_survive_the_anonymous_migration(
    tmp_path, monkeypatch, request, use_postgres
):
    """Un compte créé avant 0003 reste un compte enregistré qui se connecte."""
    database_url = request.getfixturevalue("database_url") if use_postgres else None
    for key in ("RENDER", "APP_ENV", "DATABASE_URL"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("QR_STUDIO_DATA_DIR", str(tmp_path))
    if database_url:
        monkeypatch.setenv("DATABASE_URL", database_url)
    config = Config(str(_BACKEND / "alembic.ini"))
    config.set_main_option("script_location", str(_BACKEND / "migrations"))
    settings = Settings(
        public_url="https://qr.test", data_dir=tmp_path, database_url=database_url
    )

    command.upgrade(config, "0002")
    engine = sa.create_engine(
        psycopg_url(database_url).replace("postgresql://", "postgresql+psycopg://")
        if database_url
        else f"sqlite:///{tmp_path / 'qr_studio.sqlite3'}"
    )
    now = datetime.now(timezone.utc)
    with engine.begin() as db:
        db.execute(
            sa.text(
                "INSERT INTO users (id, email, password_hash, first_name, last_name,"
                " is_active, email_verified, created_at, updated_at) VALUES"
                " (:id, 'ancien@example.com', :hash, 'Awa', 'Traoré', :t, :f, :now, :now)"
            ),
            {
                "id": uuid.uuid4().hex if not database_url else uuid.uuid4(),
                "hash": hash_password(PASSWORD),
                "t": True,
                "f": False,
                "now": now,
            },
        )
    engine.dispose()
    command.upgrade(config, "head")

    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/api/v1/auth/login",
            json={"email": "ancien@example.com", "password": PASSWORD},
        )
    assert response.status_code == 200
    assert response.json()["user"]["is_anonymous"] is False
    assert response.json()["user"]["first_name"] == "Awa"
