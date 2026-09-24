"""Tests des cartes de visite partagées (SQLite et PostgreSQL)."""

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

AWA = {
    "first_name": "Awa",
    "last_name": "Traoré",
    "job_title": "Designer",
    "company": "Studio Lagune",
    "phone": "+225 07 00 00 00",
    "email": "awa@example.com",
    "city": "Abidjan",
}
JEAN = {"first_name": "Jean", "last_name": "Kouassi", "company": "Orange CI"}


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


def publish(client, card):
    return client.post("/api/v1/business-cards", json=card)


def names(response):
    return [c["first_name"] for c in response.json()["items"]]


def test_publish_returns_card_with_all_fields(client):
    response = publish(client, AWA)

    assert response.status_code == 201
    body = response.json()
    assert len(body["id"]) == 16
    assert body["first_name"] == "Awa"
    assert body["company"] == "Studio Lagune"
    # Champs absents : chaînes vides.
    assert body["linkedin"] == ""


def test_list_newest_first(client):
    publish(client, AWA)
    publish(client, JEAN)

    assert names(client.get("/api/v1/business-cards")) == ["Jean", "Awa"]


def test_same_card_is_not_duplicated(client):
    first = publish(client, AWA).json()["id"]
    # Même contenu, casse et espaces différents.
    again = publish(client, {**AWA, "first_name": "  AWA ", "city": "abidjan"})

    assert again.json()["id"] == first
    assert names(client.get("/api/v1/business-cards")) == ["Awa"]


@pytest.mark.parametrize(
    "query,expected",
    [
        ("awa", ["Awa"]),
        ("lagune", ["Awa"]),
        ("designer abidjan", ["Awa"]),
        ("orange", ["Jean"]),
        ("kouassi jean", ["Jean"]),
        ("inconnu", []),
        ("", ["Jean", "Awa"]),
    ],
)
def test_search(client, query, expected):
    publish(client, AWA)
    publish(client, JEAN)

    response = client.get("/api/v1/business-cards", params={"q": query})

    assert names(response) == expected


def test_search_wildcards_are_plain_text(client):
    publish(client, AWA)

    assert names(client.get("/api/v1/business-cards", params={"q": "%"})) == [
        "Awa"
    ]
    assert names(client.get("/api/v1/business-cards", params={"q": "_x_"})) == []


def test_limit(client):
    for i in range(5):
        publish(client, {"first_name": f"P{i}", "last_name": "Test"})

    response = client.get("/api/v1/business-cards", params={"limit": 2})

    assert names(response) == ["P4", "P3"]
    assert client.get("/api/v1/business-cards", params={"limit": 500}).status_code == 422


@pytest.mark.parametrize(
    "card",
    [
        {"last_name": "Traoré"},
        {"first_name": "   ", "last_name": "Traoré"},
        {"first_name": "Awa", "last_name": "T", "company": "x" * 201},
        {"first_name": "Awa", "last_name": "T", "phone": 225},
    ],
)
def test_invalid_cards_are_rejected(client, card):
    assert publish(client, card).status_code == 422


def test_cards_survive_restart(tmp_path, database_url):
    settings = Settings(
        public_url="https://api.test", data_dir=tmp_path, database_url=database_url
    )
    publish(TestClient(create_app(settings)), AWA)

    restarted = TestClient(create_app(settings))

    assert names(restarted.get("/api/v1/business-cards")) == ["Awa"]


def test_publishing_counts_toward_rate_limit(tmp_path):
    settings = Settings(
        public_url="https://api.test",
        data_dir=tmp_path,
        uploads_per_client_per_hour=2,
    )
    client = TestClient(create_app(settings))

    statuses = [
        publish(client, {"first_name": f"P{i}", "last_name": "T"}).status_code
        for i in range(3)
    ]

    assert statuses == [201, 201, 429]
    # La consultation n'est pas limitée.
    assert client.get("/api/v1/business-cards").status_code == 200
