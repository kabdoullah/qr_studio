"""Environnement Alembic : même base et mêmes options que l'application."""

import asyncio

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import Settings
from app.core.database import Base, async_database_url

# Tous les modèles doivent être importés pour être connus de `Base`.
from app.modules.auth import models as _auth  # noqa: F401
from app.modules.qr_codes import models as _qr_codes  # noqa: F401

# Tables gérées hors d'Alembic (créées au démarrage par leur module) :
# fichiers, annuaire des cartes publiées, pages `/s/`.
_UNMANAGED = {"files", "business_cards", "social_pages"}


def _include(obj, name, type_, reflected, compare_to) -> bool:
    return not (type_ == "table" and name in _UNMANAGED)


def _run(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=Base.metadata,
        include_object=_include,
        render_as_batch=connection.dialect.name == "sqlite",
    )
    with context.begin_transaction():
        context.run_migrations()


async def _run_async() -> None:
    url, connect_args = async_database_url(Settings.from_env())
    engine = create_async_engine(url, connect_args=connect_args)
    async with engine.connect() as connection:
        await connection.run_sync(_run)
    await engine.dispose()


asyncio.run(_run_async())
