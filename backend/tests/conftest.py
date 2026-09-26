"""Serveur PostgreSQL embarqué, partagé par les tests qui en ont besoin."""

import pytest


@pytest.fixture(scope="session")
def postgres_server(tmp_path_factory):
    pgserver = pytest.importorskip("pgserver")
    server = pgserver.get_server(
        str(tmp_path_factory.mktemp("pg")), cleanup_mode="stop"
    )
    yield server
    server.cleanup()


@pytest.fixture
def database_url(postgres_server):
    """Base vierge pour chaque test."""
    import psycopg

    url = postgres_server.get_uri()
    with psycopg.connect(url, autocommit=True) as db:
        db.execute("DROP SCHEMA public CASCADE")
        db.execute("CREATE SCHEMA public")
    return url
