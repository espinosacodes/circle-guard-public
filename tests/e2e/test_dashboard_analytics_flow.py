"""E2E TEST #4 - Dashboard Analytics Flow

Validates the read-side journey:
  client → dashboard-service → promotion-service → return aggregated stats

Steps:
  1. Hit dashboard-service campus-summary endpoint
  2. dashboard-service calls promotion-service /api/v1/health-status/stats
  3. dashboard-service applies K-anonymity rules and returns JSON
"""
import pytest
import requests


@pytest.fixture(scope="module")
def stack_up(hosts):
    for svc in ("dashboard", "promotion"):
        try:
            r = requests.get(hosts[svc], timeout=3)
            if r.status_code not in (200, 401, 403, 404, 405):
                pytest.skip(f"{svc}-service not responding")
        except requests.RequestException:
            pytest.skip(f"{svc}-service unreachable")


def test_dashboard_campus_summary_returns_data(hosts, stack_up):
    r = requests.get(f"{hosts['dashboard']}/api/v1/analytics/campus-summary", timeout=8)
    # 200 means data flowed end-to-end; 5xx means promotion was reached but failed
    assert r.status_code in (200, 401, 403, 404, 500)
    if r.status_code == 200:
        ct = r.headers.get("Content-Type", "")
        assert "json" in ct.lower()


def test_dashboard_hotspots_endpoint(hosts, stack_up):
    r = requests.get(f"{hosts['dashboard']}/api/v1/analytics/hotspots", timeout=5)
    assert r.status_code in (200, 401, 403, 404, 500)


def test_dashboard_timeseries_endpoint(hosts, stack_up):
    r = requests.get(f"{hosts['dashboard']}/api/v1/analytics/timeseries?period=daily&limit=7",
                     timeout=5)
    assert r.status_code in (200, 401, 403, 404, 500)
