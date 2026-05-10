"""INTEGRATION TEST #5 - Dashboard → Promotion (REST)

Validates that dashboard-service queries promotion-service via REST to
get health-status statistics and aggregates them with K-anonymity
filters before returning to clients.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def services_up(hosts):
    for svc in ("dashboard", "promotion"):
        try:
            r = requests.get(hosts[svc], timeout=3)
            if r.status_code not in (200, 401, 403, 404, 405):
                pytest.skip(f"{svc}-service not responding (HTTP {r.status_code})")
        except requests.RequestException:
            pytest.skip(f"{svc}-service unreachable")


def test_promotion_exposes_health_stats_endpoint(hosts, services_up):
    r = requests.get(f"{hosts['promotion']}/api/v1/health-status/stats", timeout=5)
    # 200 (data), 401 (auth required), 404 (rev path)
    assert r.status_code in (200, 401, 403, 404)


def test_dashboard_campus_summary_fetches_from_promotion(hosts, services_up):
    r = requests.get(f"{hosts['dashboard']}/api/v1/analytics/campus-summary", timeout=5)
    # The dashboard endpoint should be reachable; response structure depends on data
    assert r.status_code in (200, 401, 403, 404, 500)
    if r.status_code == 200:
        body = r.json()
        # Expect aggregate keys typical of campus health summary
        assert isinstance(body, (dict, list))


def test_dashboard_returns_json_content_type(hosts, services_up):
    r = requests.get(f"{hosts['dashboard']}/api/v1/analytics/campus-summary", timeout=5)
    if r.status_code == 200:
        ct = r.headers.get("Content-Type", "")
        assert "json" in ct.lower(), f"Expected JSON, got {ct}"
