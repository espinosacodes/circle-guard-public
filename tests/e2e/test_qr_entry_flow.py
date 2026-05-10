"""E2E TEST #3 - Campus Entry QR Validation Flow

Validates a full campus-entry journey:
  1. Pre-seed user health status in Redis (CLEAR)
  2. Generate a QR token for that user (signed with shared qr.secret)
  3. POST the token to gateway-service /api/v1/gate/validate
  4. Gateway parses JWT, looks up Redis status, decides GREEN/RED
  5. Verify the access decision matches the seeded status

Then repeat the flow with a CONTAGIED user and verify access is denied.
"""
import os
import time
import uuid
import pytest
import requests

QR_SECRET = os.environ.get("QR_SECRET", "my-qr-secret-key-for-dev-1234567890")


@pytest.fixture(scope="module")
def redis_client():
    pytest.importorskip("redis")
    import redis as redis_lib
    try:
        c = redis_lib.from_url(os.environ.get("CG_REDIS", "redis://localhost:6379"),
                               socket_timeout=2)
        c.ping()
    except Exception:
        pytest.skip("Redis not reachable")
    return c


def _qr(anonymous_id):
    pytest.importorskip("jwt")
    import jwt
    return jwt.encode(
        {"sub": anonymous_id, "iat": int(time.time()),
         "exp": int(time.time()) + 300},
        QR_SECRET, algorithm="HS256")


@pytest.fixture(scope="module")
def gateway_up(hosts):
    try:
        r = requests.get(hosts["gateway"], timeout=3)
        if r.status_code not in (200, 401, 403, 404, 405):
            pytest.skip("gateway-service not responding")
    except requests.RequestException:
        pytest.skip("gateway-service unreachable")


def test_clear_user_can_enter_campus(hosts, redis_client, gateway_up):
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "CLEAR")
    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": _qr(anonymous_id)}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is True
    assert body.get("status") == "GREEN"


def test_contagied_user_is_blocked_at_campus(hosts, redis_client, gateway_up):
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "CONTAGIED")
    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": _qr(anonymous_id)}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is False
    assert body.get("status") == "RED"


def test_potential_user_is_blocked_at_campus(hosts, redis_client, gateway_up):
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "POTENTIAL")
    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": _qr(anonymous_id)}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is False
    assert body.get("status") == "RED"


def test_gateway_rejects_expired_qr_even_for_clear_user(hosts, redis_client, gateway_up):
    """If the QR token has expired, gateway must deny regardless of Redis status."""
    pytest.importorskip("jwt")
    import jwt
    anonymous_id = str(uuid.uuid4())
    redis_client.set(f"user:status:{anonymous_id}", "CLEAR")
    expired = jwt.encode(
        {"sub": anonymous_id, "iat": int(time.time()) - 600,
         "exp": int(time.time()) - 60},
        QR_SECRET, algorithm="HS256")
    r = requests.post(f"{hosts['gateway']}/api/v1/gate/validate",
                      json={"token": expired}, timeout=5)
    assert r.status_code == 200
    body = r.json()
    assert body.get("valid") is False
