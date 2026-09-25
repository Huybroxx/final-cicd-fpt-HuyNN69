import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.endpoints.items import reset_db


@pytest.fixture(autouse=True)
def clean_db():
    reset_db()
    yield
    reset_db()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client
