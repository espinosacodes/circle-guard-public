"""E2E TEST - CG-012 Health Center promote-to-confirmed flow

Validates the asynchronous officer-initiated promotion pipeline:
  health-center officer -> promotion-service /api/v1/promotion/health-center/promote
                        -> kafka (promotion.confirmed)
                        -> notification-service fan-out
                        -> visible at /api/v1/notifications/by-correlation/<id>

End-to-end SLO: < 60 s from POST to first notification landing.

Skipped automatically if any service is not reachable (lets the same
test file work locally with port-forwards and in stage CI).
"""
import os
import time
import uuid

import pytest
import requests


PROMOTE_PATH = "/api/v1/promotion/health-center/promote"
LOOKUP_PATH_TPL = "/api/v1/notifications/by-correlation/{cid}"

POLL_INTERVAL_S = 2
SLO_S = 60   # project-wide cascade SLO

OFFICER_USERNAME = os.environ.get("CG_OFFICER_USERNAME", "health-center@circleguard.test")
OFFICER_PASSWORD = os.environ.get("CG_OFFICER_PASSWORD", "health-center-test-pass")


def _alive(url: str) -> bool:
    try:
        return requests.get(url, timeout=3).status_code in (200, 401, 403, 404, 405)
    except requests.RequestException:
        return False


@pytest.fixture(scope="module")
def stack_up(hosts):
    """Skip if either side of the cascade is unreachable."""
    for svc in ("auth", "promotion", "notification"):
        if not _alive(hosts[svc]):
            pytest.skip(f"{svc}-service not reachable; cannot run e2e cascade test")


@pytest.fixture(scope="module")
def officer_headers(hosts, stack_up):
    """Log in as a Health Center officer and return Authorization headers.

    The dev/stage auth-service ships with a seeded user for this purpose;
    if the login fails we fall back to the X-Test-Role header (only
    honoured in the `test` Spring profile — works in stage, not in prod).
    """
    login = requests.post(
        f"{hosts['auth']}/api/v1/auth/login",
        json={"username": OFFICER_USERNAME, "password": OFFICER_PASSWORD},
        timeout=10,
    )
    if login.status_code in (200, 201):
        token = login.json().get("token")
        if token:
            return {"Authorization": f"Bearer {token}"}

    # Stage fallback — the promotion-service runs with the `test` profile
    # in stage to enable RBAC integration testing without a real IdP.
    return {"X-Test-Role": "HEALTH_CENTER_OFFICER"}


def test_promote_to_confirmed_fanout_under_slo(hosts, stack_up, officer_headers):
    """Submit a promotion, then poll the notification side until SLO."""
    suspect_hash = f"e2e-{uuid.uuid4()}"
    payload = {
        "suspectHashId": suspect_hash,
        "evidenceUrl":   "https://s3.example.com/cg-evidence/e2e-test.pdf",
        "reason":        "automated e2e test - synthetic suspect",
    }

    start = time.time()

    # ---- 1. Submit -------------------------------------------------------
    submit = requests.post(
        f"{hosts['promotion']}{PROMOTE_PATH}",
        headers={"Content-Type": "application/json", **officer_headers},
        json=payload,
        timeout=10,
    )
    assert submit.status_code == 202, (
        f"Expected 202 Accepted, got {submit.status_code}: {submit.text}"
    )
    body = submit.json()
    assert "correlationId" in body, f"Response missing correlationId: {body}"
    correlation_id = body["correlationId"]
    assert correlation_id, "correlationId must be non-empty"
    assert body.get("status") == "ACCEPTED"

    # ---- 2. Poll the notification side ---------------------------------
    lookup_url = f"{hosts['notification']}{LOOKUP_PATH_TPL.format(cid=correlation_id)}"
    landed = False
    last_status = None
    while (time.time() - start) < SLO_S:
        try:
            r = requests.get(lookup_url, headers=officer_headers, timeout=5)
            last_status = r.status_code
            if r.status_code == 200:
                try:
                    data = r.json()
                except ValueError:
                    data = None
                # Notification-service may return either {items:[...]} or
                # a bare list; treat anything non-empty as proof of fan-out.
                if data:
                    items = data.get("items") if isinstance(data, dict) else data
                    if items:
                        landed = True
                        break
        except requests.RequestException:
            pass    # transient — keep polling
        time.sleep(POLL_INTERVAL_S)

    elapsed = time.time() - start
    assert landed, (
        f"No notifications landed within {SLO_S}s SLO for correlationId={correlation_id} "
        f"(last status code from notification-service: {last_status})"
    )
    assert elapsed < SLO_S, (
        f"Cascade SLO violated: {elapsed:.2f}s >= {SLO_S}s for correlationId={correlation_id}"
    )


def test_promote_rejects_real_name_in_reason(hosts, stack_up, officer_headers):
    """Privacy guard - real-name pattern in `reason` must return 422."""
    payload = {
        "suspectHashId": f"e2e-{uuid.uuid4()}",
        "evidenceUrl":   "https://s3.example.com/cg-evidence/e2e-test.pdf",
        "reason":        "Confirmed in conversation with John Smith",
    }
    r = requests.post(
        f"{hosts['promotion']}{PROMOTE_PATH}",
        headers={"Content-Type": "application/json", **officer_headers},
        json=payload,
        timeout=10,
    )
    assert r.status_code == 422, (
        f"Expected 422 Unprocessable Entity, got {r.status_code}: {r.text}"
    )


def test_promote_requires_officer_role(hosts, stack_up):
    """Without the officer header / token, request is rejected (401 or 403)."""
    payload = {
        "suspectHashId": f"e2e-{uuid.uuid4()}",
        "evidenceUrl":   "https://s3.example.com/cg-evidence/e2e-test.pdf",
        "reason":        "test without auth",
    }
    r = requests.post(
        f"{hosts['promotion']}{PROMOTE_PATH}",
        headers={"Content-Type": "application/json"},
        json=payload,
        timeout=10,
    )
    assert r.status_code in (401, 403), (
        f"Expected 401/403 without auth, got {r.status_code}: {r.text}"
    )
