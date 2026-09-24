"""Tests des pages de réseaux sociaux (SQLite et PostgreSQL)."""

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

PAGE = {
    "title": "Awa Traoré",
    "bio": "Designer à Abidjan",
    "links": [
        {"network": "instagram", "url": "https://instagram.com/awa"},
        {"network": "whatsapp", "url": "https://wa.me/2250700000000"},
        {"network": "website", "url": "https://awa.design"},
    ],
}


@pytest.fixture(params=["sqlite", "postgres"])
def client(request, tmp_path):
    database_url = None
    if request.param == "postgres":
        database_url = request.getfixturevalue("database_url")
    settings = Settings(
        public_url="https://api.test",
        data_dir=tmp_path,
        database_url=database_url,
    )
    return TestClient(create_app(settings))


def publish(client, page):
    return client.post("/api/v1/social-pages", json=page)


def with_link(network, url):
    return {**PAGE, "links": [{"network": network, "url": url}]}


def test_publish_returns_public_url(client):
    response = publish(client, PAGE)

    assert response.status_code == 201
    body = response.json()
    assert len(body["id"]) == 16
    assert body["url"] == f"https://api.test/s/{body['id']}"


def test_same_content_returns_same_page(client):
    first = publish(client, PAGE).json()
    second = publish(client, {**PAGE, "title": "  Awa Traoré  "}).json()
    other = publish(client, {**PAGE, "bio": "Autre bio"}).json()

    assert first["id"] == second["id"]
    assert other["id"] != first["id"]


def test_page_lists_links_in_order(client):
    page_id = publish(client, PAGE).json()["id"]

    response = client.get(f"/s/{page_id}")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    html = response.text
    assert "<h1>Awa Traoré</h1>" in html
    assert "Designer à Abidjan" in html
    positions = [
        html.index('href="https://instagram.com/awa"'),
        html.index('href="https://wa.me/2250700000000"'),
        html.index('href="https://awa.design"'),
    ]
    assert positions == sorted(positions)
    assert '<meta name="robots" content="noindex">' in html


def test_page_has_security_headers(client):
    page_id = publish(client, PAGE).json()["id"]

    headers = client.get(f"/s/{page_id}").headers

    assert "default-src 'none'" in headers["content-security-policy"]
    assert "script-src" not in headers["content-security-policy"]
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["referrer-policy"] == "no-referrer"


def test_user_content_is_escaped(client):
    page = {
        **PAGE,
        "title": "<script>alert(1)</script>",
        "bio": '"><img src=x onerror=alert(1)>',
        "links": [{"network": "website", "url": 'https://a.com/?q="><b>x'}],
    }
    page_id = publish(client, page).json()["id"]

    html = client.get(f"/s/{page_id}").text

    assert "<script>" not in html
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in html
    assert "<img" not in html
    assert '"><b>' not in html


@pytest.mark.parametrize("page_id", ["AAAAAAAAAAAAAAAA", "court", "AAAAAAAAAAAAAA!!"])
def test_unknown_page_is_404_html(client, page_id):
    response = client.get(f"/s/{page_id}")

    assert response.status_code == 404
    assert "Page introuvable" in response.text
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize(
    "page",
    [
        {**PAGE, "title": "   "},
        {**PAGE, "title": "a" * 81},
        {**PAGE, "bio": "a" * 301},
        {**PAGE, "links": []},
        {**PAGE, "links": PAGE["links"][:1] * 11},
        with_link("myspace", "https://myspace.com/awa"),
        with_link("website", "http://awa.design"),
        with_link("website", "javascript:alert(1)"),
        with_link("website", "https://localhost"),
        with_link("website", "https://a.com/" + "a" * 300),
        with_link("website", "https://a.com/x y"),
        with_link("instagram", "https://evil.com/awa"),
        with_link("instagram", "https://instagram.com.evil.com/awa"),
        with_link("instagram", "https://instagram.com@evil.com/awa"),
    ],
)
def test_invalid_page_is_rejected(client, page):
    assert publish(client, page).status_code == 422


@pytest.mark.parametrize(
    "network, url",
    [
        ("instagram", "https://www.instagram.com/awa"),
        ("x", "https://twitter.com/awa"),
        ("youtube", "https://youtu.be/abc"),
        ("website", "https://sous.domaine.example.org/page?a=1"),
    ],
)
def test_accepted_domains(client, network, url):
    assert publish(client, with_link(network, url)).status_code == 201


def test_pages_survive_restart(tmp_path):
    settings = Settings(public_url="https://api.test", data_dir=tmp_path)
    page_id = publish(TestClient(create_app(settings)), PAGE).json()["id"]

    restarted = TestClient(create_app(settings))

    assert restarted.get(f"/s/{page_id}").status_code == 200
