"""Jetons de renouvellement : rotation, réutilisation, sessions et
déconnexion (SQLite et PostgreSQL)."""

import dataclasses
import sqlite3

import pytest

from app.config import Settings
from app.core.security import hash_refresh_token
from tests.helpers import PASSWORD, running_app

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
        client.post(
            "/api/v1/auth/register",
            json={
                "email": "awa@example.com",
                "password": PASSWORD,
                "first_name": "Awa",
                "last_name": "Traoré",
            },
        )
        yield client


def login(client) -> dict:
    response = client.post(
        "/api/v1/auth/login", json={"email": "awa@example.com", "password": PASSWORD}
    )
    assert response.status_code == 200
    return response.json()


def refresh(client, token: str):
    return client.post("/api/v1/auth/refresh", json={"refresh_token": token})


def me(client, access_token: str):
    return client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {access_token}"}
    )


def sql(settings: Settings, query: str, *params):
    if settings.database_url is None:
        with sqlite3.connect(settings.data_dir / "qr_studio.sqlite3") as db:
            return db.execute(query.replace("%s", "?"), params).fetchall()
    import psycopg

    with psycopg.connect(settings.database_url) as db:
        cursor = db.execute(query, params)
        return cursor.fetchall() if cursor.description else []


def test_refresh_returns_new_tokens(client):
    session = login(client)

    response = refresh(client, session["refresh_token"])

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"access_token", "refresh_token", "token_type"}
    assert body["refresh_token"] != session["refresh_token"]
    assert me(client, body["access_token"]).status_code == 200


def test_refresh_token_is_stored_hashed(client, settings):
    session = login(client)

    stored = [row[0] for row in sql(settings, "SELECT token_hash FROM refresh_tokens")]

    assert session["refresh_token"] not in stored
    assert hash_refresh_token(session["refresh_token"]) in stored


def test_rotation_revokes_the_previous_token(client, settings):
    first = login(client)["refresh_token"]
    second = refresh(client, first).json()["refresh_token"]

    rows = sql(
        settings,
        "SELECT revoked_at, replaced_by_token_id FROM refresh_tokens WHERE token_hash = %s",
        hash_refresh_token(first),
    )
    assert rows[0][0] is not None and rows[0][1] is not None
    assert refresh(client, second).status_code == 200


def test_reuse_of_a_revoked_token_revokes_the_session(client):
    stolen = login(client)["refresh_token"]
    current = refresh(client, stolen).json()["refresh_token"]

    reuse = refresh(client, stolen)

    assert reuse.status_code == 401
    # Le jeton légitime de la même session ne fonctionne plus non plus.
    assert refresh(client, current).status_code == 401


def test_reuse_does_not_affect_other_sessions(client):
    phone = login(client)["refresh_token"]
    browser = login(client)["refresh_token"]
    refresh(client, phone)

    assert refresh(client, phone).status_code == 401
    assert refresh(client, browser).status_code == 200


def test_expired_refresh_token_is_refused(client, settings):
    token = login(client)["refresh_token"]
    sql(
        settings,
        "UPDATE refresh_tokens SET expires_at = %s",
        "2000-01-01 00:00:00+00:00",
    )

    assert refresh(client, token).status_code == 401


@pytest.mark.parametrize("token", ["inconnu", "x" * 64])
def test_unknown_refresh_token_is_refused(client, token):
    response = refresh(client, token)

    assert response.status_code == 401
    assert response.json()["detail"] == (
        "Session expirée ou invalide. Veuillez vous reconnecter."
    )


def test_inactive_account_cannot_refresh(client, settings):
    token = login(client)["refresh_token"]
    sql(settings, "UPDATE users SET is_active = false")

    assert refresh(client, token).status_code == 403


def test_logout_revokes_only_that_session(client):
    phone = login(client)["refresh_token"]
    browser = login(client)["refresh_token"]

    response = client.post("/api/v1/auth/logout", json={"refresh_token": phone})

    assert response.status_code == 204
    assert refresh(client, phone).status_code == 401
    assert refresh(client, browser).status_code == 200


def test_logout_with_an_unknown_token_is_harmless(client):
    response = client.post("/api/v1/auth/logout", json={"refresh_token": "inconnu"})

    assert response.status_code == 204


def test_logout_all_revokes_every_session(client):
    phone = login(client)
    browser = login(client)["refresh_token"]

    response = client.post(
        "/api/v1/auth/logout-all",
        headers={"Authorization": f"Bearer {phone['access_token']}"},
    )

    assert response.status_code == 204
    assert refresh(client, phone["refresh_token"]).status_code == 401
    assert refresh(client, browser).status_code == 401


def test_logout_all_requires_an_access_token(client):
    assert client.post("/api/v1/auth/logout-all").status_code == 401


def test_sessions_record_the_device(client, settings):
    client.post(
        "/api/v1/auth/login",
        json={"email": "awa@example.com", "password": PASSWORD},
        headers={"User-Agent": "QR Studio Android"},
    )

    agents = [row[0] for row in sql(settings, "SELECT user_agent FROM refresh_tokens")]

    assert "QR Studio Android" in agents


def test_expired_tokens_are_purged_on_login(client, settings):
    login(client)
    sql(settings, "UPDATE refresh_tokens SET expires_at = %s", "2000-01-01 00:00:00+00:00")

    login(client)

    assert len(sql(settings, "SELECT id FROM refresh_tokens")) == 1


def test_refresh_lifetime_is_configurable(settings):
    config = dataclasses.replace(settings, refresh_token_expire_days=0)
    with running_app(config, authenticated=False) as client:
        body = client.post(
            "/api/v1/auth/register",
            json={
                "email": "jean@example.com",
                "password": PASSWORD,
                "first_name": "Jean",
                "last_name": "Kouassi",
            },
        ).json()

        # Durée nulle : le jeton est expiré dès sa création.
        assert refresh(client, body["refresh_token"]).status_code == 401
