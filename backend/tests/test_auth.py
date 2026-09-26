"""Tests des comptes : inscription, connexion et jetons (SQLite et PostgreSQL)."""

from datetime import timedelta

import pytest

from app.config import Settings
from app.core.security import create_access_token
from tests.helpers import PASSWORD, register, running_app

SECRET = "secret-de-test-suffisamment-long-0123456789"


@pytest.fixture(params=["sqlite", "postgres"])
def settings(request, tmp_path):
    database_url = None
    if request.param == "postgres":
        database_url = request.getfixturevalue("database_url")
    return Settings(
        public_url="https://api.test",
        data_dir=tmp_path,
        database_url=database_url,
        jwt_secret_key=SECRET,
    )


@pytest.fixture
def client(settings):
    with running_app(settings, authenticated=False) as client:
        yield client


def signup(client, **fields):
    body = {
        "email": "Awa@Example.com ",
        "password": PASSWORD,
        "first_name": " Awa ",
        "last_name": "Traoré",
        **fields,
    }
    return client.post("/api/v1/auth/register", json=body)


def login(client, email="awa@example.com", password=PASSWORD):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def test_register_returns_the_account_and_a_session(client):
    response = signup(client)

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "awa@example.com"
    assert body["user"]["first_name"] == "Awa"
    assert body["user"]["is_active"] is True
    assert body["user"]["email_verified"] is False
    assert body["user"]["avatar_url"] is None
    assert body["token_type"] == "bearer"
    assert body["access_token"] and body["refresh_token"]
    assert "password" not in response.text
    assert "hash" not in response.text


def test_password_is_hashed(client, settings):
    signup(client)

    import sqlite3

    if settings.database_url is None:
        with sqlite3.connect(settings.data_dir / "qr_studio.sqlite3") as db:
            stored = db.execute("SELECT password_hash FROM users").fetchone()[0]
    else:
        import psycopg

        with psycopg.connect(settings.database_url) as db:
            stored = db.execute("SELECT password_hash FROM users").fetchone()[0]
    assert PASSWORD not in stored
    assert stored.startswith("$argon2")


def test_duplicate_email_is_refused(client):
    signup(client)

    response = signup(client, email="AWA@example.com")

    assert response.status_code == 409
    assert response.json()["detail"] == (
        "Un compte existe déjà avec cette adresse email."
    )


@pytest.mark.parametrize(
    "fields",
    [
        {"email": "pas-un-email"},
        {"password": "court"},
        {"first_name": "   "},
        {"last_name": ""},
    ],
)
def test_register_validation(client, fields):
    assert signup(client, **fields).status_code == 422


def test_validation_errors_never_echo_the_password(client):
    response = signup(client, password="secret7")

    assert response.status_code == 422
    assert "secret7" not in response.text


def test_login_returns_the_account_and_a_session(client):
    signup(client)

    response = login(client, email=" AWA@example.com")

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"] and body["refresh_token"]
    assert body["user"]["email"] == "awa@example.com"
    assert "password" not in response.text
    assert "hash" not in response.text


def test_access_token_lasts_fifteen_minutes_by_default(client):
    import jwt

    signup(client)
    claims = jwt.decode(_token(client), SECRET, algorithms=["HS256"])

    assert claims["exp"] - claims["iat"] == 15 * 60


@pytest.mark.parametrize(
    "email,password",
    [("awa@example.com", "mauvais-mot-de-passe"), ("inconnu@example.com", PASSWORD)],
)
def test_wrong_credentials(client, email, password):
    signup(client)

    response = login(client, email, password)

    # Même réponse pour un email inconnu : l'existence du compte n'est pas
    # révélée.
    assert response.status_code == 401
    assert response.json()["detail"] == "Email ou mot de passe incorrect."


def test_me_returns_the_connected_account(client):
    headers = register(client, email="jean@example.com", first_name="Jean")

    response = client.get("/api/v1/auth/me", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "jean@example.com"
    assert body["first_name"] == "Jean"
    assert set(body) == {
        "id", "email", "first_name", "last_name", "avatar_url",
        "email_verified", "is_active", "created_at",
    }


def test_me_requires_a_token(client):
    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_expired_token_is_refused(client, settings):
    signup(client)
    me = client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {_token(client)}"}
    ).json()

    expired = create_access_token(me["id"], settings, timedelta(minutes=-1))

    response = client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"}
    )
    assert response.status_code == 401


@pytest.mark.parametrize(
    "token",
    [
        "pas-un-jeton",
        # Signé avec une autre clé.
        create_access_token(
            "00000000-0000-0000-0000-000000000000",
            Settings(public_url="x", data_dir=".", jwt_secret_key="autre-" * 8),
        ),
    ],
)
def test_invalid_token_is_refused(client, token):
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401


def test_token_of_a_deleted_account_is_refused(client, settings):
    token = create_access_token("00000000-0000-0000-0000-000000000000", settings)

    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401


def test_inactive_account_is_forbidden(client, settings):
    signup(client)
    token = _token(client)
    _deactivate(settings)

    assert client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 403
    assert login(client).status_code == 403


def test_login_attempts_are_rate_limited(tmp_path):
    config = Settings(
        public_url="https://api.test",
        data_dir=tmp_path,
        auth_attempts_per_client_per_hour=3,
    )
    with running_app(config, authenticated=False) as client:
        codes = [login(client).status_code for _ in range(4)]

    assert codes == [401, 401, 401, 429]


def _token(client) -> str:
    return login(client).json()["access_token"]


def _deactivate(settings: Settings) -> None:
    sql = "UPDATE users SET is_active = false"
    if settings.database_url is None:
        import sqlite3

        with sqlite3.connect(settings.data_dir / "qr_studio.sqlite3") as db:
            db.execute(sql)
    else:
        import psycopg

        with psycopg.connect(settings.database_url) as db:
            db.execute(sql)
