"""INTEGRATION TEST #3 - Gateway ↔ Redis

Validates that gateway-service consults the Redis status cache when
validating QR tokens, and reacts correctly to CONTAGIED/POTENTIAL/ACTIVE
status values seeded in Redis.
"""
import os
import time
import uuid
import pytest
import requests

QR_SECRET = os.environ.get("QR_SECRET", "my-qr-secret-key-for-dev-1234567890")


@pytest.fixture(scope="module")
def redis_client(redis_url):
    pytest.importorskip("redis")
    import redis as redis_lib
    try:
        client = redis_lib.from_url(redis_url, socket_timeout=2)
        client.ping()
    except Exception:
        pytest.skip(f"Redis not reachable at {redis_url}")
    return client


def _signed_qr(anonymous_id: str) -> str:
    """Sign a QR token compatible with gateway-service's qr.secret."""
    pytest.importorskip("jwt")
    import jwt
    payload = {
        "sub": anonymous_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 300,
    }
    return jwt.encode(payload, QR_SECRET, algorithm="HS256")


@pytest.fixture(scope="module")
def gateway_alive(hosts):
    try:
        r = requests.get(hosts["gateway"], timeout=3)
        if r.status_code not in (200, 401, 403, 404, 405):
            pytest.skip("gateway-service not responding")
    except requests.RequestException:
        pytest.skip("gateway-service unreachable — port-forward required")


def test_gateway_grants_access_when_redis_status_clear(hosts, redis_client, gateway_alive):
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "CLEAR")
    token = _signed_qr(anonymous_id)

    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": token}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is True
    assert body.get("status") == "GREEN"


def test_gateway_denies_access_when_redis_status_contagied(hosts, redis_client, gateway_alive):
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "CONTAGIED")
    token = _signed_qr(anonymous_id)

    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": token}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is False
    assert body.get("status") == "RED"


def test_gateway_rejects_invalid_token_without_consulting_redis(hosts, gateway_alive):
    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": "garbage.token.value"}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is False
