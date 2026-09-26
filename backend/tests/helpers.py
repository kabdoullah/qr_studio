"""Clients de test : application démarrée et comptes connectés."""

import dataclasses
import itertools
from contextlib import contextmanager
from typing import Iterator

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

PASSWORD = "motdepasse-solide"
_emails = itertools.count()


def register(client: TestClient, email: str = "", **fields) -> dict:
    """Crée un compte et renvoie ses en-têtes d'authentification."""
    email = email or f"user{next(_emails)}@example.com"
    body = {
        "email": email,
        "password": PASSWORD,
        "first_name": "Awa",
        "last_name": "Traoré",
        **fields,
    }
    response = client.post("/api/v1/auth/register", json=body)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@contextmanager
def running_app(
    settings: Settings, authenticated: bool = True, **app_options
) -> Iterator[TestClient]:
    """Application démarrée (schéma créé), connectée à un nouveau compte."""
    settings = dataclasses.replace(settings, auto_create_schema=True)
    with TestClient(create_app(settings, **app_options)) as client:
        if authenticated:
            client.headers.update(register(client))
        yield client
