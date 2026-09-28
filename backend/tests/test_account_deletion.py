"""Suppression du compte et pages publiques exigées par Google Play."""

import pytest

from app.config import Settings
from tests.helpers import PASSWORD, register, running_app

PDF = b"%PDF-1.7\n" + b"0" * 2048
TEXT = {"type": "text", "title": "Bienvenue", "content": {"text": "Bonjour"}}


@pytest.fixture(params=["sqlite", "postgres"])
def settings(request, tmp_path):
    database_url = None
    if request.param == "postgres":
        database_url = request.getfixturevalue("database_url")
    return Settings(
        public_url="https://qr.test", data_dir=tmp_path, database_url=database_url
    )


@pytest.fixture
def client(settings):
    with running_app(settings, authenticated=False) as client:
        yield client


def signup(client, email="awa@example.com") -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": PASSWORD, "first_name": "Awa", "last_name": "T"},
    )
    assert response.status_code == 201
    return response.json()


def bearer(auth: dict) -> dict:
    return {"Authorization": f"Bearer {auth['access_token']}"}


def upload_cv(client, headers) -> str:
    response = client.post("/api/v1/cvs", files={"file": ("cv.pdf", PDF)}, headers=headers)
    assert response.status_code == 201
    return response.json()["id"]


def test_delete_account_removes_everything(client):
    auth = signup(client)
    headers = bearer(auth)
    file_id = upload_cv(client, headers)
    cv = client.post(
        "/api/v1/qr-codes",
        json={"type": "cv", "title": "CV", "content": {"file_id": file_id}},
        headers=headers,
    ).json()
    text = client.post("/api/v1/qr-codes", json=TEXT, headers=headers).json()
    # Fichier envoyé mais jamais rattaché à un QR Code.
    orphan_id = upload_cv(client, headers)

    assert client.delete("/api/v1/auth/me", headers=headers).status_code == 204

    for qr in (cv, text):
        assert client.get(f"/q/{qr['slug']}").status_code == 404
    assert client.get(f"/cv/{file_id}").status_code == 404
    assert client.get(f"/cv/{orphan_id}").status_code == 404
    # Session terminée partout.
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    refresh = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]}
    )
    assert refresh.status_code == 401
    login = client.post(
        "/api/v1/auth/login", json={"email": "awa@example.com", "password": PASSWORD}
    )
    assert login.status_code == 401
    # L'adresse est libre à nouveau.
    assert signup(client)["user"]["id"] != auth["user"]["id"]


def test_delete_account_keeps_other_accounts(client):
    headers = bearer(signup(client))
    other = register(client)
    kept = client.post("/api/v1/qr-codes", json=TEXT, headers=other).json()

    assert client.delete("/api/v1/auth/me", headers=headers).status_code == 204

    assert client.get(f"/q/{kept['slug']}").status_code == 200
    items = client.get("/api/v1/qr-codes", headers=other).json()["items"]
    assert [qr["id"] for qr in items] == [kept["id"]]


def test_delete_account_requires_a_session(client):
    assert client.delete("/api/v1/auth/me").status_code == 401


def test_privacy_policy_is_public(client):
    response = client.get("/privacy")

    assert response.status_code == 200
    assert "Politique de confidentialité" in response.text
    assert "script" not in response.headers["Content-Security-Policy"]
    assert 'href="/account/delete"' in response.text


def test_account_deletion_page_is_public(client):
    response = client.get("/account/delete")

    assert response.status_code == 200
    assert "Supprimer mon compte" in response.text
    assert 'href="/privacy"' in response.text
