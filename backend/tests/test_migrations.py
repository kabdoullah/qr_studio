"""Les migrations Alembic produisent le schéma attendu par l'application."""

from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.helpers import register

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
