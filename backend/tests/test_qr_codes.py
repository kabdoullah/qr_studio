"""Tests des QR Codes des comptes : propriété, modification, accès public."""

import pytest

from app.config import Settings
from tests.helpers import register, running_app

PDF = b"%PDF-1.7\n" + b"0" * 2048
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 2048

WEBSITE = {
    "type": "website",
    "title": "Mon portfolio",
    "content": {"url": "https://example.com"},
}
TEXT = {"type": "text", "title": "Bienvenue", "content": {"text": "Bonjour <b>!</b>"}}
WIFI = {
    "type": "wifi",
    "title": "Wi-Fi Maison",
    "content": {
        "ssid": "Maison",
        "security": "WPA2",
        "password": "secret-wifi-123",
        "hidden": False,
    },
}
SOCIAL = {
    "type": "social_media",
    "title": "Mes réseaux",
    "content": {
        "description": "Retrouvez-moi",
        "links": [
            {"platform": "instagram", "url": "https://instagram.com/awa"},
            {"platform": "github", "url": "https://github.com/awa", "label": "Code"},
            {
                "platform": "linkedin",
                "url": "https://linkedin.com/in/awa",
                "is_visible": False,
            },
        ],
    },
}
CARD = {
    "type": "business_card",
    "title": "Awa Traoré",
    "content": {
        "mode": "details",
        "details": {
            "first_name": "Awa",
            "last_name": "Traoré",
            "phone": "+225 07 00 00 00",
            "email": "awa@example.com",
        },
    },
}


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
    with running_app(settings) as client:
        yield client


@pytest.fixture
def other(client):
    """En-têtes d'un second compte, sur le même serveur."""
    return register(client)


def create(client, body, **kwargs):
    return client.post("/api/v1/qr-codes", json=body, **kwargs)


def upload(client, endpoint, content, **kwargs):
    response = client.post(endpoint, files={"file": ("cv.pdf", content)}, **kwargs)
    assert response.status_code == 201
    return response.json()["id"]


def public(client, slug):
    return client.get(f"/api/v1/public/q/{slug}")


# --- CRUD ---


def test_create_returns_a_dynamic_public_url(client):
    response = create(client, WEBSITE)

    assert response.status_code == 201
    qr = response.json()
    assert qr["type"] == "website"
    assert qr["title"] == "Mon portfolio"
    assert qr["is_active"] is True
    assert len(qr["slug"]) == 12
    assert qr["public_url"] == f"https://qr.test/q/{qr['slug']}"
    assert qr["content"] == {"url": "https://example.com"}


def test_slugs_are_unique(client):
    slugs = {create(client, TEXT).json()["slug"] for _ in range(10)}
    assert len(slugs) == 10


def test_list_returns_own_qr_codes_newest_first(client, other):
    create(client, TEXT)
    create(client, WEBSITE)
    create(client, WIFI, headers=other)

    items = client.get("/api/v1/qr-codes").json()["items"]

    assert [qr["type"] for qr in items] == ["website", "text"]


def test_get_one(client):
    qr = create(client, SOCIAL).json()

    response = client.get(f"/api/v1/qr-codes/{qr['id']}")

    assert response.status_code == 200
    assert response.json() == qr


def test_update_keeps_the_slug(client):
    qr = create(client, WEBSITE).json()
    changed = {**WEBSITE, "title": "Nouveau", "content": {"url": "https://new.example"}}

    response = client.put(f"/api/v1/qr-codes/{qr['id']}", json=changed)

    assert response.status_code == 200
    updated = response.json()
    assert updated["slug"] == qr["slug"]
    assert updated["title"] == "Nouveau"
    assert public(client, qr["slug"]).json()["url"] == "https://new.example"


def test_type_cannot_change(client):
    qr = create(client, WEBSITE).json()

    response = client.put(f"/api/v1/qr-codes/{qr['id']}", json=TEXT)

    assert response.status_code == 422


def test_delete_makes_the_public_page_unavailable(client):
    qr = create(client, TEXT).json()

    assert client.delete(f"/api/v1/qr-codes/{qr['id']}").status_code == 204

    assert client.get(f"/api/v1/qr-codes/{qr['id']}").status_code == 404
    assert public(client, qr["slug"]).status_code == 404
    page = client.get(f"/q/{qr['slug']}")
    assert page.status_code == 404
    assert "QR Code indisponible" in page.text
    assert client.get("/api/v1/qr-codes").json()["items"] == []


def test_qr_codes_require_an_account(settings):
    with running_app(settings, authenticated=False) as anonymous:
        assert anonymous.get("/api/v1/qr-codes").status_code == 401
        assert create(anonymous, TEXT).status_code == 401


# --- Propriété : le QR Code d'un autre compte n'existe pas ---


def test_user_cannot_read_another_users_qr_code(client, other):
    qr = create(client, WIFI).json()

    response = client.get(f"/api/v1/qr-codes/{qr['id']}", headers=other)

    assert response.status_code == 404
    assert "secret-wifi-123" not in response.text


def test_user_cannot_update_another_users_qr_code(client, other):
    qr = create(client, WEBSITE).json()
    changed = {**WEBSITE, "content": {"url": "https://evil.example"}}

    response = client.put(f"/api/v1/qr-codes/{qr['id']}", json=changed, headers=other)

    assert response.status_code == 404
    assert public(client, qr["slug"]).json()["url"] == "https://example.com"


def test_user_cannot_delete_another_users_qr_code(client, other):
    qr = create(client, WEBSITE).json()

    response = client.delete(f"/api/v1/qr-codes/{qr['id']}", headers=other)

    assert response.status_code == 404
    assert public(client, qr["slug"]).status_code == 200


def test_user_cannot_use_another_users_file(client, other):
    file_id = upload(client, "/api/v1/cvs", PDF, headers=other)

    response = create(client, {"type": "cv", "title": "CV", "content": {"file_id": file_id}})

    assert response.status_code == 422


# --- Accès public ---


def test_public_access_needs_no_account(client, settings):
    qr = create(client, WEBSITE).json()

    with running_app(settings, authenticated=False) as anonymous:
        response = public(anonymous, qr["slug"])

    assert response.status_code == 200
    assert response.json() == {
        "type": "website",
        "title": "Mon portfolio",
        "url": "https://example.com",
    }


def test_unknown_or_malformed_slug(client):
    assert public(client, "AAAAAAAAAAAA").status_code == 404
    assert public(client, "court").status_code == 422
    assert client.get("/q/court").status_code == 404


def test_public_page_for_each_type(client):
    cv_id = upload(client, "/api/v1/cvs", PDF)
    card_id = upload(client, "/api/v1/cards", PNG)
    bodies = {
        "Visiter le site": WEBSITE,
        "Télécharger le CV": {"type": "cv", "title": "CV", "content": {"file_id": cv_id}},
        "instagram.com/awa": SOCIAL,
        "Bonjour &lt;b&gt;!&lt;/b&gt;": TEXT,
        "Maison": WIFI,
        "awa@example.com": CARD,
        f"/card/{card_id}": {
            "type": "business_card",
            "title": "Ma carte",
            "content": {"mode": "image", "file_id": card_id},
        },
    }
    for expected, body in bodies.items():
        slug = create(client, body).json()["slug"]

        page = client.get(f"/q/{slug}")

        assert page.status_code == 200, body["type"]
        assert expected in page.text, body["type"]
        assert "<script" not in page.text
        assert "default-src 'none'" in page.headers["content-security-policy"]


def test_public_cv_links_to_the_file(client):
    file_id = upload(client, "/api/v1/cvs", PDF)
    qr = create(client, {"type": "cv", "title": "Mon CV", "content": {"file_id": file_id}}).json()

    body = public(client, qr["slug"]).json()

    assert body == {
        "type": "cv",
        "title": "Mon CV",
        "filename": "cv.pdf",
        "url": f"https://qr.test/cv/{file_id}",
    }
    assert client.get(f"/cv/{file_id}").content == PDF


def test_cv_file_is_deleted_with_its_qr_code(client):
    file_id = upload(client, "/api/v1/cvs", PDF)
    qr = create(client, {"type": "cv", "title": "CV", "content": {"file_id": file_id}}).json()

    client.delete(f"/api/v1/qr-codes/{qr['id']}")

    assert client.get(f"/cv/{file_id}").status_code == 404


def test_replacing_the_cv_deletes_the_old_file(client):
    first = upload(client, "/api/v1/cvs", PDF)
    second = upload(client, "/api/v1/cvs", PDF)
    qr = create(client, {"type": "cv", "title": "CV", "content": {"file_id": first}}).json()

    client.put(
        f"/api/v1/qr-codes/{qr['id']}",
        json={"type": "cv", "title": "CV", "content": {"file_id": second}},
    )

    assert client.get(f"/cv/{first}").status_code == 404
    assert client.get(f"/cv/{second}").status_code == 200


def test_a_file_serves_a_single_qr_code(client):
    file_id = upload(client, "/api/v1/cvs", PDF)
    body = {"type": "cv", "title": "CV", "content": {"file_id": file_id}}
    assert create(client, body).status_code == 201

    assert create(client, body).status_code == 422


# --- Réseaux sociaux ---


def test_social_media_public_shows_visible_links_in_order(client):
    qr = create(client, SOCIAL).json()

    body = public(client, qr["slug"]).json()

    assert body["description"] == "Retrouvez-moi"
    assert body["links"] == [
        {"platform": "instagram", "label": "Instagram", "url": "https://instagram.com/awa"},
        {"platform": "github", "label": "Code", "url": "https://github.com/awa"},
    ]


def test_social_media_update_replaces_links(client):
    qr = create(client, SOCIAL).json()
    changed = {
        **SOCIAL,
        "content": {"links": [{"platform": "youtube", "url": "https://youtube.com/@awa"}]},
    }

    updated = client.put(f"/api/v1/qr-codes/{qr['id']}", json=changed).json()

    assert [link["platform"] for link in updated["content"]["links"]] == ["youtube"]
    assert updated["slug"] == qr["slug"]


def test_social_media_delete(client):
    qr = create(client, SOCIAL).json()

    client.delete(f"/api/v1/qr-codes/{qr['id']}")

    assert public(client, qr["slug"]).status_code == 404


@pytest.mark.parametrize(
    "change",
    [
        {"title": ""},
        {"title": "x" * 101},
        {"content": {"links": []}},
        {"content": {"description": "x" * 301, "links": SOCIAL["content"]["links"]}},
        {"content": {"links": [{"platform": "instagram", "url": "https://instagram.com/a"}] * 16}},
        {"content": {"links": [{"platform": "myspace", "url": "https://myspace.com/a"}]}},
        {"content": {"links": [{"platform": "instagram", "url": "https://evil.com/a"}]}},
        {"content": {"links": [{"platform": "website", "url": "javascript:alert(1)"}]}},
        {"content": {"links": [{"platform": "website", "url": "http://site.com"}]}},
        {"content": {"links": [{"platform": "website", "url": "https://a.com/" + "x" * 500}]}},
        {"content": {"links": [{"platform": "github", "url": "https://github.com/a", "label": "x" * 51}]}},
    ],
)
def test_social_media_validation(client, change):
    assert create(client, {**SOCIAL, **change}).status_code == 422


# --- Site web ---


@pytest.mark.parametrize(
    "url",
    ["https://example.com", "https://www.mon-site.com/page?x=1", "http://localhost.dev:8080"],
)
def test_website_valid_urls(client, url):
    assert create(client, {**WEBSITE, "content": {"url": url}}).status_code == 201


@pytest.mark.parametrize(
    "url", ["", "example", "ftp://example.com", "javascript:alert(1)", "https://user:pw@example.com"]
)
def test_website_invalid_urls(client, url):
    assert create(client, {**WEBSITE, "content": {"url": url}}).status_code == 422


def test_website_http_is_refused_in_production(tmp_path):
    config = Settings(
        public_url="https://qr.test",
        data_dir=tmp_path,
        app_env="production",
        jwt_secret_key="k" * 40,
    )
    with running_app(config) as client:
        response = create(client, {**WEBSITE, "content": {"url": "http://example.com"}})

    assert response.status_code == 422


# --- Wi-Fi ---


def test_wifi_password_is_private(client):
    qr = create(client, WIFI).json()

    assert qr["content"]["password"] == "secret-wifi-123"
    body = public(client, qr["slug"]).json()
    assert body == {"type": "wifi", "title": "Wi-Fi Maison", "ssid": "Maison", "security": "WPA2"}
    assert "secret-wifi-123" not in client.get(f"/q/{qr['slug']}").text


def test_open_network_keeps_no_password(client):
    body = {**WIFI, "content": {"ssid": "Libre", "security": "none", "password": "ignoré"}}

    qr = create(client, body).json()

    assert qr["content"]["password"] == ""


def test_hidden_network(client):
    body = {**WIFI, "content": {**WIFI["content"], "hidden": True}}

    assert create(client, body).json()["content"]["hidden"] is True


@pytest.mark.parametrize(
    "content",
    [
        {"ssid": "", "security": "WPA2", "password": "12345678"},
        {"ssid": "x" * 33, "security": "WPA2", "password": "12345678"},
        {"ssid": "Maison", "security": "WPA2", "password": "court"},
        {"ssid": "Maison", "security": "WEP", "password": ""},
        {"ssid": "Maison", "security": "WPA4", "password": "12345678"},
    ],
)
def test_wifi_validation_never_echoes_the_password(client, content):
    response = create(client, {**WIFI, "content": content})

    assert response.status_code == 422
    if content["password"]:
        assert content["password"] not in response.text


def test_special_characters_are_stored_as_typed(client):
    content = {"ssid": 'Café;"Wi,Fi":\\', "security": "WPA", "password": 'p;a,s:s"\\w'}

    qr = create(client, {**WIFI, "content": content}).json()

    assert qr["content"]["ssid"] == content["ssid"]
    assert qr["content"]["password"] == content["password"]


# --- Texte et carte de visite ---


@pytest.mark.parametrize("text", ["", "   ", "x" * 1001])
def test_text_validation(client, text):
    assert create(client, {**TEXT, "content": {"text": text}}).status_code == 422


def test_business_card_details_round_trip(client):
    qr = create(client, CARD).json()

    assert qr["content"]["mode"] == "details"
    assert qr["content"]["details"]["email"] == "awa@example.com"
    assert public(client, qr["slug"]).json()["details"]["first_name"] == "Awa"


def test_business_card_requires_names_or_image(client):
    no_names = {**CARD, "content": {"mode": "details", "details": {"first_name": "Awa"}}}
    no_image = {**CARD, "content": {"mode": "image"}}

    assert create(client, no_names).status_code == 422
    assert create(client, no_image).status_code == 422
