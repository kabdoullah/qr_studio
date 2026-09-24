"""Tests de l'API de mise en ligne des fichiers."""

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

PDF = b"%PDF-1.7\n" + b"0" * 2048
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 2048
JPEG = b"\xff\xd8\xff\xe0" + b"0" * 2048
WEBP = b"RIFF\x00\x00\x00\x00WEBPVP8 " + b"0" * 2048
HEIC = b"\x00\x00\x00\x18ftypheic" + b"0" * 2048


@pytest.fixture
def client(tmp_path):
    settings = Settings(
        public_url="https://qrstudio.test",
        data_dir=tmp_path,
        max_file_bytes=100 * 1024,
    )
    return TestClient(create_app(settings))


def upload(client, endpoint, content, filename="fichier"):
    return client.post(endpoint, files={"file": (filename, content)})


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_upload_cv_returns_public_link(client):
    response = upload(client, "/api/v1/cvs", PDF, "CV_Awa_Traoré.pdf")

    assert response.status_code == 201
    body = response.json()
    assert len(body["id"]) == 16
    assert body["url"] == f"https://qrstudio.test/cv/{body['id']}"


def test_uploaded_cv_opens_in_browser(client):
    file_id = upload(client, "/api/v1/cvs", PDF, "CV_Awa_Traoré.pdf").json()["id"]

    response = client.get(f"/cv/{file_id}")

    assert response.status_code == 200
    assert response.content == PDF
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["content-disposition"].startswith("inline")
    assert "CV_Awa_Traor" in response.headers["content-disposition"]
    assert response.headers["x-content-type-options"] == "nosniff"


def test_ids_are_unique(client):
    ids = {upload(client, "/api/v1/cvs", PDF).json()["id"] for _ in range(20)}
    assert len(ids) == 20


@pytest.mark.parametrize(
    "content,content_type",
    [(PNG, "image/png"), (JPEG, "image/jpeg"), (WEBP, "image/webp")],
)
def test_upload_card_image(client, content, content_type):
    body = upload(client, "/api/v1/cards", content, "carte.jpg").json()

    assert body["url"] == f"https://qrstudio.test/card/{body['id']}"
    served = client.get(f"/card/{body['id']}")
    assert served.content == content
    assert served.headers["content-type"] == content_type


def test_type_is_checked_on_content_not_name(client):
    # Un faux PDF (une image renommée) est refusé.
    response = upload(client, "/api/v1/cvs", PNG, "cv.pdf")

    assert response.status_code == 415
    assert response.json()["detail"] == "Le fichier doit être un PDF."


@pytest.mark.parametrize("content", [HEIC, PDF, b"GIF89a" + b"0" * 100])
def test_card_rejects_non_web_images(client, content):
    assert upload(client, "/api/v1/cards", content).status_code == 415


def test_empty_file_is_rejected(client):
    assert upload(client, "/api/v1/cvs", b"").status_code == 400


def test_too_large_file_is_rejected_before_reading(client):
    content = b"%PDF-" + b"0" * (300 * 1024)

    response = upload(client, "/api/v1/cvs", content)

    assert response.status_code == 413


def test_file_just_over_limit_is_rejected(client, tmp_path):
    # Passe le contrôle de l'en-tête (marge multipart) mais pas celui du
    # contenu : aucun fichier partiel ne doit rester sur le disque.
    content = b"%PDF-" + b"0" * (100 * 1024)

    response = upload(client, "/api/v1/cvs", content)

    assert response.status_code == 413
    assert list((tmp_path / "files").iterdir()) == []


def test_rejected_upload_leaves_no_file(client, tmp_path):
    upload(client, "/api/v1/cvs", PNG)
    assert list((tmp_path / "files").iterdir()) == []


def test_cv_and_card_links_are_separate(client):
    cv_id = upload(client, "/api/v1/cvs", PDF).json()["id"]

    assert client.get(f"/card/{cv_id}").status_code == 404


def test_unknown_or_malformed_id(client):
    assert client.get("/cv/AAAAAAAAAAAAAAAA").status_code == 404
    assert client.get("/cv/..%2F..%2Fetc%2Fpasswd").status_code in (404, 422)
    assert client.get("/cv/court").status_code == 422


def test_filename_is_sanitized(client):
    file_id = upload(
        client, "/api/v1/cvs", PDF, "../../secret\r\nX-Injected: 1.pdf"
    ).json()["id"]

    response = client.get(f"/cv/{file_id}")

    assert "x-injected" not in response.headers
    assert ".." not in response.headers["content-disposition"].split("filename")[-1][:5]
