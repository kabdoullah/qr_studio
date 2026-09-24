"""Tests du stockage R2, des limites d'envoi et de la configuration."""

import io

import pytest
from botocore.exceptions import ClientError
from botocore.response import StreamingBody
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.rate_limit import UploadRateLimiter
from app.storage import R2FileStore

PDF = b"%PDF-1.7\n" + b"0" * 200_000
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 2048


class FakeS3:
    """Client S3 minimal en mémoire (mêmes erreurs et réponses que boto3)."""

    def __init__(self):
        self.objects = {}

    def upload_file(self, filename, bucket, key, ExtraArgs):
        with open(filename, "rb") as source:
            self.objects[(bucket, key)] = (source.read(), ExtraArgs)

    def _find(self, bucket, key, operation):
        if (bucket, key) not in self.objects:
            raise ClientError({"Error": {"Code": "404"}}, operation)
        return self.objects[(bucket, key)]

    def head_object(self, Bucket, Key):
        data, extra = self._find(Bucket, Key, "HeadObject")
        return {
            "ContentType": extra["ContentType"],
            "ContentLength": len(data),
            "Metadata": extra["Metadata"],
        }

    def get_object(self, Bucket, Key):
        data, _ = self._find(Bucket, Key, "GetObject")
        return {"Body": StreamingBody(io.BytesIO(data), len(data))}


def settings(tmp_path, **overrides):
    values = dict(public_url="https://api.test", data_dir=tmp_path)
    values.update(overrides)
    return Settings(**values)


@pytest.fixture
def s3():
    return FakeS3()


@pytest.fixture
def r2_client(tmp_path, s3):
    store = R2FileStore(s3, "qr-studio")
    return TestClient(create_app(settings(tmp_path), store=store))


def test_r2_round_trip(r2_client, s3, tmp_path):
    body = r2_client.post(
        "/api/v1/cvs", files={"file": ("CV Awa Traoré.pdf", PDF)}
    ).json()

    # Rangé sous cv/<id>, avec le type détecté et le nom encodé en ASCII.
    data, extra = s3.objects[("qr-studio", f"cv/{body['id']}")]
    assert data == PDF
    assert extra["ContentType"] == "application/pdf"
    assert extra["Metadata"]["filename"].isascii()
    # Rien n'est écrit sur le disque local.
    assert not (tmp_path / "files").exists() or not any(
        (tmp_path / "files").iterdir()
    )

    served = r2_client.get(f"/cv/{body['id']}")
    assert served.content == PDF
    assert served.headers["content-type"] == "application/pdf"
    assert served.headers["content-length"] == str(len(PDF))
    assert "Traor%C3%A9" in served.headers["content-disposition"]


def test_r2_missing_file_is_404(r2_client):
    assert r2_client.get("/card/AAAAAAAAAAAAAAAA").status_code == 404


def test_r2_cv_is_not_served_as_card(r2_client):
    file_id = r2_client.post(
        "/api/v1/cvs", files={"file": ("cv.pdf", PDF)}
    ).json()["id"]
    assert r2_client.get(f"/card/{file_id}").status_code == 404


def test_r2_other_errors_are_not_hidden(s3):
    class Broken(FakeS3):
        def head_object(self, Bucket, Key):
            raise ClientError({"Error": {"Code": "AccessDenied"}}, "HeadObject")

    with pytest.raises(ClientError):
        R2FileStore(Broken(), "b").get("AAAAAAAAAAAAAAAA", "cv")


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


def test_rate_limit_per_client_and_window():
    clock = Clock()
    limiter = UploadRateLimiter(per_client=2, total=100, clock=clock)

    assert limiter.allow("a") and limiter.allow("a")
    assert not limiter.allow("a")
    assert limiter.allow("b")

    clock.now = 3600
    assert limiter.allow("a")


def test_rate_limit_global():
    limiter = UploadRateLimiter(per_client=10, total=3, clock=Clock())

    assert all(limiter.allow(ip) for ip in ["a", "b", "c"])
    # Changer d'adresse ne contourne pas la limite globale.
    assert not limiter.allow("d")


def test_api_returns_429_when_limit_reached(tmp_path):
    client = TestClient(
        create_app(settings(tmp_path, uploads_per_client_per_hour=2))
    )

    def send():
        return client.post("/api/v1/cards", files={"file": ("c.png", PNG)})

    assert [send().status_code for _ in range(3)] == [201, 201, 429]
    assert send().json()["detail"] == "Trop d'envois. Réessayez plus tard."
    # Les lectures ne sont pas limitées.
    assert client.get("/health").status_code == 200


R2_ENV = {
    "R2_ACCOUNT_ID": "acc",
    "R2_ACCESS_KEY_ID": "key",
    "R2_SECRET_ACCESS_KEY": "secret",
    "R2_BUCKET": "qr-studio",
}


@pytest.fixture
def clean_env(monkeypatch):
    for key in [
        *R2_ENV,
        "RENDER",
        "RENDER_EXTERNAL_URL",
        "QR_STUDIO_PUBLIC_URL",
    ]:
        monkeypatch.delenv(key, raising=False)
    return monkeypatch


def test_render_without_r2_refuses_to_start(clean_env):
    clean_env.setenv("RENDER", "true")

    with pytest.raises(RuntimeError, match="R2 requis"):
        Settings.from_env()


def test_partial_r2_config_is_rejected(clean_env):
    clean_env.setenv("R2_BUCKET", "qr-studio")

    with pytest.raises(RuntimeError, match="incomplète"):
        Settings.from_env()


def test_render_config(clean_env):
    clean_env.setenv("RENDER", "true")
    clean_env.setenv("RENDER_EXTERNAL_URL", "https://qr-studio-api.onrender.com/")
    for key, value in R2_ENV.items():
        clean_env.setenv(key, value)

    config = Settings.from_env()

    assert config.public_url == "https://qr-studio-api.onrender.com"
    assert config.r2.bucket == "qr-studio"
    assert config.r2.endpoint_url == "https://acc.r2.cloudflarestorage.com"


def test_public_url_can_be_overridden(clean_env):
    clean_env.setenv("RENDER_EXTERNAL_URL", "https://x.onrender.com")
    clean_env.setenv("QR_STUDIO_PUBLIC_URL", "https://api.qrstudio.app")

    assert Settings.from_env().public_url == "https://api.qrstudio.app"


def test_create_store_uses_r2_when_configured(tmp_path):
    from app.config import R2Settings
    from app.storage import LocalFileStore, create_store

    r2 = R2Settings("acc", "key", "secret", "qr-studio")

    assert isinstance(create_store(settings(tmp_path)), LocalFileStore)
    store = create_store(settings(tmp_path, r2=r2))
    assert isinstance(store, R2FileStore)
    assert store._client.meta.endpoint_url == "https://acc.r2.cloudflarestorage.com"
