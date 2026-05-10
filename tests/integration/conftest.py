"""Shared fixtures for integration & E2E tests.

These tests assume the 7 microservices are deployed in K8s namespace
`circleguard-dev` and reachable via port-forward at the URLs below.
"""
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
    """Service hostnames, can be overridden via env vars CG_<SERVICE>_URL."""
    return {
        name: os.environ.get(f"CG_{name.upper()}_URL", default)
        for name, default in DEFAULT_HOSTS.items()
    }


@pytest.fixture(scope="session")
def kafka_bootstrap():
    return os.environ.get("CG_KAFKA", "localhost:9092")


@pytest.fixture(scope="session")
def redis_url():
    return os.environ.get("CG_REDIS", "redis://localhost:6379")


@pytest.fixture(scope="session")
def postgres_url():
    return os.environ.get("CG_POSTGRES", "postgresql://admin:password@localhost:5432")
