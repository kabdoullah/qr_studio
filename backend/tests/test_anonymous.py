"""Utilisateurs anonymes : session sans compte, idempotence par
installation, conversion en compte enregistré (email, Google, Facebook)
sans changer d'`id` (SQLite et PostgreSQL)."""

import dataclasses
import uuid

import httpx
import pytest

from app.config import Settings
from app.modules.auth.social import FacebookAuthProvider, GoogleAuthProvider
from tests.helpers import PASSWORD, running_app
from tests.test_social_auth import (
    _KEY,
    FB_APP,
    FB_SECRET,
    GOOGLE_CLIENT,
    FakeGraph,
    google_token,
)

INSTALLATION = "550e8400-e29b-41d4-a716-446655440000"


@pytest.fixture(params=["sqlite", "postgres"])
def settings(request, tmp_path):
    database_url = None
    if request.param == "postgres":
        database_url = request.getfixturevalue("database_url")
    return Settings(public_url="https://api.test", data_dir=tmp_path, database_url=database_url)


@pytest.fixture
def graph():
    graph = FakeGraph()
    graph.add("fb-token")
    return graph


@pytest.fixture
def client(settings, graph):
    providers = {
        "google": GoogleAuthProvider([GOOGLE_CLIENT], signing_key=lambda _: _KEY.public_key()),
        "facebook": FacebookAuthProvider(
            FB_APP, FB_SECRET, transport=httpx.MockTransport(graph.handler)
        ),
    }
    with running_app(settings, authenticated=False, social_providers=providers) as client:
        yield client


def anonymous(client, installation_id: str = INSTALLATION) -> dict:
    response = client.post(
        "/api/v1/auth/anonymous", json={"installation_id": installation_id}
    )
    assert response.status_code == 200, response.text
    return response.json()


def bearer(auth: dict) -> dict:
    return {"Authorization": f"Bearer {auth['access_token']}"}


def create_qr(client, auth: dict) -> str:
    response = client.post(
        "/api/v1/qr-codes",
        json={"type": "text", "title": "Note", "content": {"text": "Bonjour"}},
        headers=bearer(auth),
    )
    assert response.status_code == 201
    return response.json()["id"]


def qr_ids(client, auth: dict) -> list:
    response = client.get("/api/v1/qr-codes", headers=bearer(auth))
    assert response.status_code == 200
    return [item["id"] for item in response.json()["items"]]


def register(client, auth: dict, email: str = "awa@example.com"):
    return client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": PASSWORD,
            "first_name": "Awa",
            "last_name": "Traoré",
        },
        headers=bearer(auth),
    )


# --- Session anonyme ---


def test_anonymous_session_without_account(client):
    auth = anonymous(client)

    assert auth["token_type"] == "bearer"
    assert auth["access_token"] and auth["refresh_token"]
    user = auth["user"]
    assert user["is_anonymous"] is True
    assert user["email"] is None
    assert user["first_name"] is None and user["last_name"] is None
    me = client.get("/api/v1/auth/me", headers=bearer(auth))
    assert me.status_code == 200
    assert me.json()["id"] == user["id"]


def test_same_installation_finds_the_same_user(client):
    first = anonymous(client)
    second = anonymous(client)

    assert second["user"]["id"] == first["user"]["id"]
    # Nouvelle session à chaque appel : les deux restent utilisables.
    assert second["refresh_token"] != first["refresh_token"]
    other = anonymous(client, str(uuid.uuid4()))
    assert other["user"]["id"] != first["user"]["id"]


@pytest.mark.parametrize("installation_id", ["", "pas-un-uuid", None, 42])
def test_installation_id_must_be_a_uuid(client, installation_id):
    response = client.post(
        "/api/v1/auth/anonymous", json={"installation_id": installation_id}
    )

    assert response.status_code == 422


def test_anonymous_session_is_refreshed_like_any_other(client):
    auth = anonymous(client)

    refreshed = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]}
    )

    assert refreshed.status_code == 200
    me = client.get("/api/v1/auth/me", headers=bearer(refreshed.json()))
    assert me.json()["id"] == auth["user"]["id"]
    # Rotation : l'ancien jeton ne sert plus.
    reused = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]}
    )
    assert reused.status_code == 401


def test_installation_id_is_not_a_bearer_token(client):
    anonymous(client)

    response = client.get(
        "/api/v1/qr-codes", headers={"Authorization": f"Bearer {INSTALLATION}"}
    )

    assert response.status_code == 401


def test_anonymous_users_only_see_their_own_qr_codes(client):
    alice = anonymous(client)
    bob = anonymous(client, str(uuid.uuid4()))
    qr_id = create_qr(client, alice)

    assert qr_ids(client, alice) == [qr_id]
    assert qr_ids(client, bob) == []
    response = client.get(f"/api/v1/qr-codes/{qr_id}", headers=bearer(bob))
    assert response.status_code == 404
    response = client.delete(f"/api/v1/qr-codes/{qr_id}", headers=bearer(bob))
    assert response.status_code == 404


def test_anonymous_users_can_upload_files(client):
    auth = anonymous(client)

    response = client.post(
        "/api/v1/cvs",
        files={"file": ("cv.pdf", b"%PDF-1.4 contenu", "application/pdf")},
        headers=bearer(auth),
    )

    assert response.status_code == 201


def test_anonymous_sessions_are_rate_limited(settings, graph):
    settings = dataclasses.replace(settings, anonymous_sessions_per_client_per_hour=2)
    with running_app(settings, authenticated=False) as client:
        anonymous(client)
        anonymous(client, str(uuid.uuid4()))

        response = client.post(
            "/api/v1/auth/anonymous", json={"installation_id": str(uuid.uuid4())}
        )

    assert response.status_code == 429


# --- Conversion par email ---


def test_register_converts_the_anonymous_user(client):
    auth = anonymous(client)
    qr_id = create_qr(client, auth)

    response = register(client, auth)

    assert response.status_code == 201
    converted = response.json()
    assert converted["user"]["id"] == auth["user"]["id"]
    assert converted["user"]["is_anonymous"] is False
    assert converted["user"]["email"] == "awa@example.com"
    assert converted["user"]["first_name"] == "Awa"
    assert qr_ids(client, converted) == [qr_id]
    # Les sessions anonymes sont terminées ; la nouvelle fonctionne.
    old = client.post("/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]})
    assert old.status_code == 401
    # Le compte se connecte ensuite par email, depuis n'importe quel appareil.
    login = client.post(
        "/api/v1/auth/login", json={"email": "awa@example.com", "password": PASSWORD}
    )
    assert login.json()["user"]["id"] == auth["user"]["id"]


def test_converted_account_is_no_longer_reachable_by_installation(client):
    auth = anonymous(client)
    register(client, auth)

    # Après une déconnexion, l'installation ouvre un nouvel anonyme vide,
    # jamais le compte enregistré.
    again = anonymous(client)

    assert again["user"]["id"] != auth["user"]["id"]
    assert again["user"]["is_anonymous"] is True


def test_register_with_a_taken_email_keeps_the_anonymous_user(client):
    register(client, anonymous(client, str(uuid.uuid4())), email="pris@example.com")
    auth = anonymous(client)

    response = register(client, auth, email="pris@example.com")

    assert response.status_code == 409
    me = client.get("/api/v1/auth/me", headers=bearer(auth))
    assert me.json()["is_anonymous"] is True


def test_register_without_session_creates_an_account(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "neuf@example.com",
            "password": PASSWORD,
            "first_name": "Jean",
            "last_name": "Kouassi",
        },
    )

    assert response.status_code == 201
    assert response.json()["user"]["is_anonymous"] is False


def test_register_with_an_invalid_session_is_refused(client):
    response = register(client, {"access_token": "jeton-invalide"})

    # 401 : l'application renouvelle la session puis rejoue l'inscription.
    assert response.status_code == 401


def test_register_from_a_registered_session_creates_another_account(client):
    first = register(client, anonymous(client)).json()

    second = register(client, first, email="autre@example.com")

    assert second.status_code == 201
    assert second.json()["user"]["id"] != first["user"]["id"]


# --- Conversion Google / Facebook ---


def google(client, auth=None, token=None):
    return client.post(
        "/api/v1/auth/social/google",
        json={"id_token": token or google_token()},
        headers=bearer(auth) if auth else {},
    )


def facebook(client, auth=None, token="fb-token"):
    return client.post(
        "/api/v1/auth/social/facebook",
        json={"access_token": token},
        headers=bearer(auth) if auth else {},
    )


def test_google_converts_the_anonymous_user(client):
    auth = anonymous(client)
    qr_id = create_qr(client, auth)

    response = google(client, auth)

    assert response.status_code == 200
    user = response.json()["user"]
    assert user["id"] == auth["user"]["id"]
    assert user["is_anonymous"] is False
    assert user["email"] == "awa@gmail.com"
    assert user["email_verified"] is True
    assert user["first_name"] == "Awa"
    assert qr_ids(client, response.json()) == [qr_id]
    # Plus tard, sans session : Google retrouve le même compte.
    assert google(client).json()["user"]["id"] == auth["user"]["id"]


def test_facebook_converts_the_anonymous_user(client):
    auth = anonymous(client)

    response = facebook(client, auth)

    assert response.status_code == 200
    user = response.json()["user"]
    assert user["id"] == auth["user"]["id"]
    assert user["is_anonymous"] is False
    assert facebook(client).json()["user"]["id"] == auth["user"]["id"]


def test_google_account_of_another_user_is_never_merged(client):
    owner = google(client).json()
    auth = anonymous(client)
    qr_id = create_qr(client, auth)

    response = google(client, auth)

    # Connexion au compte existant, sans fusion : l'anonyme garde ses QR
    # Codes et reste accessible par l'installation (après déconnexion).
    assert response.status_code == 200
    assert response.json()["user"]["id"] == owner["user"]["id"]
    assert qr_ids(client, response.json()) == []
    again = anonymous(client)
    assert again["user"]["id"] == auth["user"]["id"]
    assert again["user"]["is_anonymous"] is True
    assert qr_ids(client, again) == [qr_id]


def test_google_with_the_email_of_an_unverified_account_is_refused(client):
    register(client, anonymous(client, str(uuid.uuid4())), email="awa@gmail.com")
    auth = anonymous(client)

    response = google(client, auth)

    assert response.status_code == 409
    me = client.get("/api/v1/auth/me", headers=bearer(auth))
    assert me.json()["is_anonymous"] is True


def test_invalid_google_token_keeps_the_anonymous_session(client):
    auth = anonymous(client)

    response = google(client, auth, token="pas-un-jwt")

    # 400 et non 401 : la session anonyme présentée reste valide.
    assert response.status_code == 400
    me = client.get("/api/v1/auth/me", headers=bearer(auth))
    assert me.json()["is_anonymous"] is True


def test_anonymous_users_cannot_use_the_link_endpoint(client):
    auth = anonymous(client)

    response = client.post(
        "/api/v1/auth/social/google/link",
        json={"id_token": google_token()},
        headers=bearer(auth),
    )

    assert response.status_code == 400
