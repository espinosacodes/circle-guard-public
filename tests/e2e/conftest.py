"""Shared fixtures for E2E tests — same shape as integration tests."""
import os
import pytest

DEFAULT_HOSTS = {
    "auth":         "http://localhost:8180",
    "identity":     "http://localhost:8083",
    "form":         "http://localhost:8086",
    "promotion":    "http://localhost:8088",
    "notification": "http://localhost:8082",
    "gateway":      "http://localhost:8087",
    "dashboard":    "http://localhost:8084",
}


@pytest.fixture(scope="session")
def hosts():
    return {
        name: os.environ.get(f"CG_{name.upper()}_URL", default)
        for name, default in DEFAULT_HOSTS.items()
    }
