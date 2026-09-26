"""Connexion Google et Facebook : vérification des credentials côté serveur,
création, retrouvailles et liaison des comptes (SQLite et PostgreSQL)."""

import time
from typing import Any, Dict, Optional

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.config import Settings
from app.modules.auth.social import FacebookAuthProvider, GoogleAuthProvider
from tests.helpers import PASSWORD, running_app

GOOGLE_CLIENT = "web-client.apps.googleusercontent.com"
FB_APP, FB_SECRET = "1234567890", "facebook-app-secret"
_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def google_token(key=_KEY, **overrides) -> str:
    now = int(time.time())
    claims: Dict[str, Any] = {
        "iss": "https://accounts.google.com",
        "aud": GOOGLE_CLIENT,
        "sub": "google-sub-1",
        "email": "Awa@Gmail.com",
        "email_verified": True,
        "given_name": "Awa",
        "family_name": "Traoré",
        "picture": "https://lh3.googleusercontent.com/a/photo",
        "iat": now,
        "exp": now + 3600,
        **overrides,
    }
    return jwt.encode({k: v for k, v in claims.items() if v is not None}, key, "RS256")


class FakeGraph:
    """Graph API simulée : jetons Facebook connus et leur profil."""

    def __init__(self) -> None:
        self.users: Dict[str, Dict[str, Any]] = {}
        self.app_of: Dict[str, str] = {}
        self.down = False
        self.requests: list = []

    def add(self, token: str, app_id: str = FB_APP, **profile) -> None:
        self.users[token] = {
            "id": "fb-1",
            "first_name": "Awa",
            "last_name": "Traoré",
            "email": "awa@example.com",
            "picture": {"data": {"url": "https://fb.test/p.jpg", "is_silhouette": False}},
            **profile,
        }
        self.app_of[token] = app_id

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if self.down:
            raise httpx.ConnectError("injoignable")
        if request.url.path.endswith("/debug_token"):
            assert request.headers["authorization"] == f"OAuth {FB_APP}|{FB_SECRET}"
            token = request.url.params["input_token"]
            user = self.users.get(token)
            data = (
                {"is_valid": True, "app_id": self.app_of[token], "user_id": user["id"]}
                if user
                else {"is_valid": False}
            )
            return httpx.Response(200, json={"data": data})
        token = request.headers["authorization"].removeprefix("Bearer ")
        if token not in self.users:
            return httpx.Response(400, json={"error": {"message": "invalid"}})
        assert request.url.params["appsecret_proof"]
        return httpx.Response(
            200, json={k: v for k, v in self.users[token].items() if v is not None}
        )


@pytest.fixture(params=["sqlite", "postgres"])
def settings(request, tmp_path):
    database_url = None
    if request.param == "postgres":
        database_url = request.getfixturevalue("database_url")
    return Settings(public_url="https://api.test", data_dir=tmp_path, database_url=database_url)


@pytest.fixture
def graph():
    return FakeGraph()


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


def google(client, token: Optional[str] = None):
    return client.post("/api/v1/auth/social/google", json={"id_token": token or google_token()})


def facebook(client, token: str = "fb-token"):
    return client.post("/api/v1/auth/social/facebook", json={"access_token": token})


def signup(client, email="awa@gmail.com") -> dict:
    return client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": PASSWORD, "first_name": "A", "last_name": "B"},
    ).json()


# --- Google ---


def test_google_creates_a_verified_account(client):
    response = google(client)

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"] and body["refresh_token"]
    assert body["user"]["email"] == "awa@gmail.com"
    assert body["user"]["email_verified"] is True
    assert body["user"]["first_name"] == "Awa"
    assert body["user"]["avatar_url"] == "https://lh3.googleusercontent.com/a/photo"


def test_google_account_has_no_password(client):
    google(client)

    response = client.post(
        "/api/v1/auth/login", json={"email": "awa@gmail.com", "password": PASSWORD}
    )

    assert response.status_code == 401


def test_existing_google_identity_finds_the_same_account(client):
    first = google(client).json()["user"]["id"]

    # Même `sub`, même si l'email a changé chez Google.
    second = google(client, google_token(email="nouvelle@gmail.com")).json()["user"]["id"]

    assert first == second


@pytest.mark.parametrize(
    "token",
    [
        "pas-un-jwt",
        google_token(key=_OTHER_KEY),  # signature
        google_token(exp=int(time.time()) - 60),  # expiré
        google_token(aud="autre-application"),  # audience
        google_token(iss="https://accounts.evil.com"),  # émetteur
        google_token(sub=None),  # sans identifiant
    ],
    ids=["malformed", "signature", "expired", "audience", "issuer", "no-sub"],
)
def test_invalid_google_tokens_are_refused(client, token):
    response = google(client, token)

    assert response.status_code == 401
    assert response.json()["detail"] == "La connexion avec Google a échoué. Veuillez réessayer."


def test_google_email_of_a_password_account_is_not_merged(client):
    signup(client, "awa@gmail.com")

    response = google(client)

    # L'adresse du compte existant n'a jamais été vérifiée : pas de fusion.
    assert response.status_code == 409
    assert "liez Google depuis votre compte" in response.json()["detail"]


def test_connected_user_can_link_google(client):
    headers = {"Authorization": f"Bearer {signup(client)['access_token']}"}

    linked = client.post(
        "/api/v1/auth/social/google/link", json={"id_token": google_token()}, headers=headers
    )
    login = google(client)

    assert linked.status_code == 200
    assert login.status_code == 200
    assert login.json()["user"]["id"] == linked.json()["id"]


def test_google_identity_cannot_be_linked_to_two_accounts(client):
    google(client)
    headers = {"Authorization": f"Bearer {signup(client, 'autre@example.com')['access_token']}"}

    response = client.post(
        "/api/v1/auth/social/google/link", json={"id_token": google_token()}, headers=headers
    )

    assert response.status_code == 409


def test_link_requires_a_session(client):
    response = client.post("/api/v1/auth/social/google/link", json={"id_token": google_token()})

    assert response.status_code == 401


def test_two_verified_google_identities_share_an_account(client):
    first = google(client).json()["user"]["id"]

    # Autre compte Google, même adresse vérifiée des deux côtés.
    second = google(client, google_token(sub="google-sub-2"))

    assert second.status_code == 200
    assert second.json()["user"]["id"] == first


def test_google_unconfigured_is_unavailable(tmp_path):
    with running_app(
        Settings(public_url="https://api.test", data_dir=tmp_path), authenticated=False
    ) as client:
        response = google(client)

    assert response.status_code == 503


# --- Facebook ---


def test_facebook_creates_an_account(client, graph):
    graph.add("fb-token")

    response = facebook(client)

    assert response.status_code == 200
    user = response.json()["user"]
    assert user["email"] == "awa@example.com"
    # L'email Facebook n'est jamais considéré comme vérifié.
    assert user["email_verified"] is False
    assert user["avatar_url"] == "https://fb.test/p.jpg"


def test_facebook_without_email_creates_an_account(client, graph):
    graph.add("fb-token", email=None)

    response = facebook(client)

    assert response.status_code == 200
    assert response.json()["user"]["email"] is None


def test_several_facebook_accounts_without_email(client, graph):
    graph.add("a", id="fb-a", email=None)
    graph.add("b", id="fb-b", email=None)

    assert facebook(client, "a").status_code == 200
    assert facebook(client, "b").status_code == 200


def test_existing_facebook_identity_finds_the_same_account(client, graph):
    graph.add("fb-token")
    graph.add("fb-token-2")

    first = facebook(client).json()["user"]["id"]
    second = facebook(client, "fb-token-2").json()["user"]["id"]

    assert first == second


def test_invalid_facebook_token_is_refused(client, graph):
    response = facebook(client, "inconnu")

    assert response.status_code == 401
    assert response.json()["detail"] == (
        "La connexion avec Facebook a échoué. Veuillez réessayer."
    )


def test_facebook_token_of_another_app_is_refused(client, graph):
    graph.add("fb-token", app_id="autre-app")

    assert facebook(client).status_code == 401


def test_expired_facebook_token_is_refused(client, graph):
    # `debug_token` signale un jeton expiré par `is_valid: false`.
    graph.add("fb-token")
    graph.users.pop("fb-token")

    assert facebook(client).status_code == 401


def test_facebook_email_of_an_existing_account_is_not_merged(client, graph):
    signup(client, "awa@example.com")
    graph.add("fb-token")

    response = facebook(client)

    assert response.status_code == 409
    assert "liez Facebook depuis votre compte" in response.json()["detail"]


def test_facebook_unreachable_is_unavailable(client, graph):
    graph.add("fb-token")
    graph.down = True

    assert facebook(client).status_code == 503


def test_facebook_user_token_is_sent_in_a_header(client, graph):
    graph.add("fb-token")
    facebook(client)

    me_request = graph.requests[-1]
    assert "fb-token" not in str(me_request.url)
    assert me_request.headers["authorization"] == "Bearer fb-token"


# --- Sécurité ---


def test_responses_never_expose_secrets(client, graph):
    graph.add("fb-token")
    bodies = [google(client).text, facebook(client).text]

    for text in bodies:
        assert "hash" not in text
        assert FB_SECRET not in text
        assert "provider_user_id" not in text


def test_client_supplied_ids_are_not_accepted(client):
    response = client.post(
        "/api/v1/auth/social/google", json={"google_user_id": "123", "email": "x@y.z"}
    )

    assert response.status_code == 422
