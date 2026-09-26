"""Tests du stockage PostgreSQL, des limites et de la configuration."""

from pathlib import Path

import pytest

from app.config import Settings, psycopg_url
from app.core.database import async_database_url
from app.rate_limit import UploadRateLimiter
from app.storage import LocalFileStore, PostgresFileStore, create_store
from tests.helpers import running_app

PDF = b"%PDF-1.7\n" + b"0" * 200_000
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 2048


def settings(tmp_path, **overrides):
    values = dict(public_url="https://api.test", data_dir=tmp_path)
    values.update(overrides)
    return Settings(**values)


@pytest.fixture
def pg_client(tmp_path, database_url):
    with running_app(settings(tmp_path, database_url=database_url)) as client:
        yield client


def test_postgres_round_trip(pg_client, tmp_path):
    body = pg_client.post(
        "/api/v1/cvs", files={"file": ("CV Awa Traoré.pdf", PDF)}
    ).json()

    served = pg_client.get(f"/cv/{body['id']}")

    assert served.status_code == 200
    assert served.content == PDF
    assert served.headers["content-type"] == "application/pdf"
    assert served.headers["content-length"] == str(len(PDF))
    assert "Traor%C3%A9" in served.headers["content-disposition"]
    # Rien n'est écrit sur le disque local.
    assert not (tmp_path / "files").exists()


def test_postgres_keeps_files_across_restarts(tmp_path, database_url):
    config = settings(tmp_path, database_url=database_url)
    with running_app(config) as first:
        file_id = first.post(
            "/api/v1/cards", files={"file": ("carte.png", PNG)}
        ).json()["id"]

    # Nouveau processus (redéploiement) : le fichier est toujours là.
    with running_app(config, authenticated=False) as second:
        assert second.get(f"/card/{file_id}").content == PNG


def test_postgres_missing_or_wrong_kind_is_404(pg_client):
    cv_id = pg_client.post("/api/v1/cvs", files={"file": ("cv.pdf", PDF)}).json()[
        "id"
    ]

    assert pg_client.get("/cv/AAAAAAAAAAAAAAAA").status_code == 404
    assert pg_client.get(f"/card/{cv_id}").status_code == 404


def test_postgres_total_bytes(database_url, tmp_path):
    store = PostgresFileStore(database_url)
    config = settings(tmp_path, database_url=database_url)
    with running_app(config, store=store) as client:
        assert store.total_bytes() == 0

        client.post("/api/v1/cvs", files={"file": ("cv.pdf", PDF)})
        client.post("/api/v1/cards", files={"file": ("c.png", PNG)})

    assert store.total_bytes() == len(PDF) + len(PNG)


@pytest.mark.parametrize("use_postgres", [False, True])
def test_upload_refused_when_storage_is_full(tmp_path, request, use_postgres):
    extra = {}
    if use_postgres:
        extra["database_url"] = request.getfixturevalue("database_url")
    config = settings(tmp_path, max_storage_bytes=300_000, **extra)
    with running_app(config) as client:

        def send():
            return client.post("/api/v1/cvs", files={"file": ("cv.pdf", PDF)})

        assert send().status_code == 201
        full = send()
    assert full.status_code == 507
    assert full.json()["detail"] == (
        "L'espace de stockage est plein. Réessayez plus tard."
    )


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


def test_rate_limit_per_client_and_window():
    clock = Clock()
    limiter = UploadRateLimiter(per_client=2, total=100, clock=clock)

    assert limiter.allow("a") and limiter.allow("a")
    assert not limiter.allow("a")
    assert limiter.allow("b")

    clock.now = 3600
    assert limiter.allow("a")


def test_rate_limit_global():
    limiter = UploadRateLimiter(per_client=10, total=3, clock=Clock())

    assert all(limiter.allow(ip) for ip in ["a", "b", "c"])
    # Changer d'adresse ne contourne pas la limite globale.
    assert not limiter.allow("d")


def test_api_returns_429_when_limit_reached(tmp_path):
    with running_app(settings(tmp_path, uploads_per_client_per_hour=2)) as client:

        def send():
            return client.post("/api/v1/cards", files={"file": ("c.png", PNG)})

        assert [send().status_code for _ in range(3)] == [201, 201, 429]
        assert send().json()["detail"] == "Trop d'envois. Réessayez plus tard."
        # Les lectures ne sont pas limitées.
        assert client.get("/health").status_code == 200


@pytest.fixture
def clean_env(monkeypatch):
    for key in [
        "DATABASE_URL",
        "RENDER",
        "RENDER_EXTERNAL_URL",
        "QR_STUDIO_PUBLIC_URL",
        "QR_STUDIO_MAX_STORAGE_MB",
        "QR_STUDIO_CORS_ORIGINS",
        "APP_ENV",
        "JWT_SECRET_KEY",
        "JWT_ALGORITHM",
        "ACCESS_TOKEN_EXPIRE_MINUTES",
        "PUBLIC_BASE_URL",
    ]:
        monkeypatch.delenv(key, raising=False)
    return monkeypatch


def test_render_without_database_refuses_to_start(clean_env):
    clean_env.setenv("RENDER", "true")

    with pytest.raises(RuntimeError, match="Base de données requise"):
        Settings.from_env()


def test_render_config(clean_env):
    url = "postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require"
    clean_env.setenv("RENDER", "true")
    clean_env.setenv("RENDER_EXTERNAL_URL", "https://qr-studio-api.onrender.com/")
    clean_env.setenv("DATABASE_URL", url)
    clean_env.setenv("QR_STUDIO_MAX_STORAGE_MB", "300")
    clean_env.setenv("JWT_SECRET_KEY", "s" * 40)
    clean_env.setenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60")

    config = Settings.from_env()

    assert config.app_env == "production"
    assert config.jwt_secret_key == "s" * 40
    assert config.access_token_expire_minutes == 60

    assert config.public_url == "https://qr-studio-api.onrender.com"
    assert config.database_url == url
    assert config.max_storage_bytes == 300 * 1024 * 1024


def test_public_url_can_be_overridden(clean_env):
    clean_env.setenv("RENDER_EXTERNAL_URL", "https://x.onrender.com")
    clean_env.setenv("QR_STUDIO_PUBLIC_URL", "https://api.qrstudio.app")

    assert Settings.from_env().public_url == "https://api.qrstudio.app"


def test_cors_origins_from_env(clean_env):
    assert Settings.from_env().cors_origins == ()

    clean_env.setenv(
        "QR_STUDIO_CORS_ORIGINS", " https://qr-studio.onrender.com/ , http://localhost:8080"
    )

    assert Settings.from_env().cors_origins == (
        "https://qr-studio.onrender.com",
        "http://localhost:8080",
    )


def test_create_store_uses_postgres_when_configured(tmp_path, database_url):
    assert isinstance(create_store(settings(tmp_path)), LocalFileStore)
    assert isinstance(
        create_store(settings(tmp_path, database_url=database_url)),
        PostgresFileStore,
    )


def test_production_requires_a_jwt_secret(clean_env):
    clean_env.setenv("APP_ENV", "production")

    with pytest.raises(RuntimeError, match="JWT_SECRET_KEY"):
        Settings.from_env()


def test_development_has_a_default_jwt_secret(clean_env):
    config = Settings.from_env()

    assert config.is_development
    assert config.jwt_secret_key


def test_public_base_url_takes_precedence(clean_env):
    clean_env.setenv("QR_STUDIO_PUBLIC_URL", "https://api.qrstudio.app")
    clean_env.setenv("PUBLIC_BASE_URL", "https://qrstudio.app/")

    assert Settings.from_env().public_url == "https://qrstudio.app"


def test_database_url_accepts_both_drivers():
    neon = "postgresql+asyncpg://u:p@ep-x-pooler.neon.tech/db?sslmode=require"

    assert psycopg_url(neon) == (
        "postgresql://u:p@ep-x-pooler.neon.tech/db?sslmode=require"
    )
    url, options = async_database_url(
        Settings(public_url="x", data_dir=Path("."), database_url=neon)
    )
    assert url == "postgresql+asyncpg://u:p@ep-x-pooler.neon.tech/db"
    assert options["ssl"] == "require"
    assert options["statement_cache_size"] == 0
