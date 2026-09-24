"""Cartes de visite partagées : coordonnées publiées par les utilisateurs.

Les cartes publiées sont visibles par tous les utilisateurs de
l'application (choix produit). La publication est une action explicite
dans l'application, qui prévient l'utilisateur.
"""

import hashlib
import json
import time
from typing import Any, Dict, List, Tuple

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field, field_validator

from .database import Database
from .storage import new_file_id

# Champs de la carte, dans l'ordre du formulaire de l'application.
FIELDS: Tuple[str, ...] = (
    "first_name",
    "last_name",
    "job_title",
    "company",
    "phone",
    "email",
    "website",
    "address",
    "city",
    "country",
    "linkedin",
    "instagram",
    "whatsapp",
)
# Champs sur lesquels porte la recherche.
_SEARCHED = ("first_name", "last_name", "job_title", "company", "city")
_MAX_FIELD_LENGTH = 200


class BusinessCardIn(BaseModel):
    first_name: str = Field(min_length=1, max_length=_MAX_FIELD_LENGTH)
    last_name: str = Field(min_length=1, max_length=_MAX_FIELD_LENGTH)
    job_title: str = Field("", max_length=_MAX_FIELD_LENGTH)
    company: str = Field("", max_length=_MAX_FIELD_LENGTH)
    phone: str = Field("", max_length=_MAX_FIELD_LENGTH)
    email: str = Field("", max_length=_MAX_FIELD_LENGTH)
    website: str = Field("", max_length=_MAX_FIELD_LENGTH)
    address: str = Field("", max_length=_MAX_FIELD_LENGTH)
    city: str = Field("", max_length=_MAX_FIELD_LENGTH)
    country: str = Field("", max_length=_MAX_FIELD_LENGTH)
    linkedin: str = Field("", max_length=_MAX_FIELD_LENGTH)
    instagram: str = Field("", max_length=_MAX_FIELD_LENGTH)
    whatsapp: str = Field("", max_length=_MAX_FIELD_LENGTH)

    # Espaces superflus retirés avant la validation de longueur minimale :
    # un prénom composé d'espaces est refusé.
    @field_validator("*", mode="before")
    @classmethod
    def _strip(cls, value: Any) -> Any:
        return value.strip() if isinstance(value, str) else value


class BusinessCardOut(BusinessCardIn):
    id: str


class BusinessCardList(BaseModel):
    items: List[BusinessCardOut]


class CardStore:
    def __init__(self, db: Database) -> None:
        self._execute = db.execute
        columns = ", ".join(f"{name} TEXT NOT NULL" for name in FIELDS)
        self._execute(
            "CREATE TABLE IF NOT EXISTS business_cards ("
            " id TEXT PRIMARY KEY,"
            f" {columns},"
            # Empêche d'enregistrer deux fois la même carte.
            " content_hash TEXT NOT NULL UNIQUE,"
            " created_at DOUBLE PRECISION NOT NULL)"
        )

    @staticmethod
    def _hash(card: BusinessCardIn) -> str:
        normalized = json.dumps(
            {name: getattr(card, name).casefold() for name in FIELDS},
            sort_keys=True,
        )
        return hashlib.sha256(normalized.encode()).hexdigest()

    def add(self, card: BusinessCardIn) -> BusinessCardOut:
        """Enregistre la carte, ou renvoie la carte identique existante."""
        content_hash = self._hash(card)
        values = tuple(getattr(card, name) for name in FIELDS)
        self._execute(
            f"INSERT INTO business_cards (id, {', '.join(FIELDS)},"
            " content_hash, created_at)"
            f" VALUES ({', '.join(['%s'] * (len(FIELDS) + 3))})"
            " ON CONFLICT (content_hash) DO NOTHING",
            (new_file_id(), *values, content_hash, time.time()),
        )
        rows = self._execute(
            f"SELECT id, {', '.join(FIELDS)} FROM business_cards"
            " WHERE content_hash = %s",
            (content_hash,),
            fetch=True,
        )
        return self._to_card(rows[0])

    def search(self, query: str, limit: int) -> List[BusinessCardOut]:
        sql = f"SELECT id, {', '.join(FIELDS)} FROM business_cards"
        params: Tuple = ()
        terms = query.split()
        if terms:
            haystack = " || ' ' || ".join(_SEARCHED)
            # Chaque mot doit apparaître dans l'un des champs recherchés.
            sql += " WHERE " + " AND ".join(
                f"LOWER({haystack}) LIKE %s" for _ in terms
            )
            params = tuple(f"%{_escape_like(term.lower())}%" for term in terms)
        sql += " ORDER BY created_at DESC LIMIT %s"
        rows = self._execute(sql, (*params, limit), fetch=True)
        return [self._to_card(row) for row in rows]

    @staticmethod
    def _to_card(row: Tuple) -> BusinessCardOut:
        return BusinessCardOut(id=row[0], **dict(zip(FIELDS, row[1:])))


def _escape_like(term: str) -> str:
    # Les jokers saisis par l'utilisateur sont traités comme du texte.
    return term.replace("%", "").replace("_", "")


def create_cards_router(store: CardStore) -> APIRouter:
    router = APIRouter(prefix="/api/v1/business-cards")

    @router.post("", status_code=201, response_model=BusinessCardOut)
    def publish_card(card: BusinessCardIn) -> BusinessCardOut:
        return store.add(card)

    @router.get("", response_model=BusinessCardList)
    def list_cards(
        q: str = Query("", max_length=100),
        limit: int = Query(50, ge=1, le=100),
    ) -> Dict[str, Any]:
        return {"items": store.search(q, limit)}

    return router
