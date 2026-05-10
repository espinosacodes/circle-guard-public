"""Locust performance & stress tests for CircleGuard.

Run with the deployed K8s services accessible via port-forward, e.g.:
    kubectl port-forward -n circleguard-dev svc/auth-service       8180:8180 &
    kubectl port-forward -n circleguard-dev svc/form-service       8086:8086 &
    kubectl port-forward -n circleguard-dev svc/gateway-service    8087:8087 &
    kubectl port-forward -n circleguard-dev svc/dashboard-service  8084:8084 &

Headless run:
    locust -f tests/performance/locustfile.py --headless \\
           -u 50 -r 10 -t 60s --host http://localhost:8180 \\
           --csv results/perf

Web UI:
    locust -f tests/performance/locustfile.py --host http://localhost:8180

Realistic mix of campus traffic:
  - 70% gate scans (gateway-service, frequent)
  - 15% survey submits (form-service, daily per user)
  - 10% dashboard reads (dashboard-service, admin polling)
  -  5% logins (auth-service, infrequent)
"""
import os
import random
import time
import uuid

from locust import HttpUser, between, events, task

QR_SECRET = os.environ.get("QR_SECRET", "my-qr-secret-key-for-dev-1234567890")
HOSTS = {
    "auth":      os.environ.get("CG_AUTH_URL",      "http://localhost:8180"),
    "form":      os.environ.get("CG_FORM_URL",      "http://localhost:8086"),
    "gateway":   os.environ.get("CG_GATEWAY_URL",   "http://localhost:8087"),
    "dashboard": os.environ.get("CG_DASHBOARD_URL", "http://localhost:8084"),
}


def _qr_token(anonymous_id: str) -> str:
    """Generate a QR JWT compatible with gateway-service's qr.secret."""
    try:
        import jwt
    except ImportError:
        # Locust without PyJWT installed — return a clearly bogus token so
        # gateway returns RED but the request still measures performance.
        return f"locust.{anonymous_id}.test"
    return jwt.encode(
        {"sub": anonymous_id, "iat": int(time.time()),
         "exp": int(time.time()) + 300},
        QR_SECRET, algorithm="HS256")


class CampusUser(HttpUser):
    """Simulates one student/staff member doing typical daily operations."""

    wait_time = between(1, 3)

    def on_start(self):
        self.anonymous_id = str(uuid.uuid4())
        self.qr_token = _qr_token(self.anonymous_id)

    @task(70)
    def gate_validate(self):
        """Most frequent operation — campus turnstile QR scan."""
        with self.client.post(
            f"{HOSTS['gateway']}/api/v1/gate/validate",
            json={"token": self.qr_token},
            name="POST /api/v1/gate/validate",
            catch_response=True,
        ) as r:
            if r.status_code != 200:
                r.failure(f"gate validate returned {r.status_code}")

    @task(15)
    def submit_survey(self):
        """Daily health questionnaire submission."""
        payload = {
            "anonymousId": self.anonymous_id,
            "responses": {"q1": random.choice(["YES", "NO"]),
                          "q2": random.choice(["YES", "NO"])},
            "hasFever": random.random() < 0.05,  # 5% report fever
            "hasCough": random.random() < 0.10,  # 10% report cough
        }
        with self.client.post(
            f"{HOSTS['form']}/api/v1/surveys",
            json=payload,
            name="POST /api/v1/surveys",
            catch_response=True,
        ) as r:
            if r.status_code not in (200, 201):
                r.failure(f"survey submit returned {r.status_code}")

    @task(10)
    def dashboard_summary(self):
        """Admin polling the analytics dashboard."""
        with self.client.get(
            f"{HOSTS['dashboard']}/api/v1/analytics/campus-summary",
            name="GET /api/v1/analytics/campus-summary",
            catch_response=True,
        ) as r:
            if r.status_code >= 500:
                r.failure(f"dashboard returned {r.status_code}")

    @task(5)
    def login(self):
        """Periodic re-authentication (1 in 20 tasks)."""
        with self.client.post(
            f"{HOSTS['auth']}/api/v1/auth/login",
            json={"username": "perf-test@circleguard.edu",
                  "password": "perf-test-pass"},
            name="POST /api/v1/auth/login",
            catch_response=True,
        ) as r:
            # 401/403 are expected if no LDAP user is provisioned — those still
            # measure server-side performance, only mark real errors
            if r.status_code >= 500:
                r.failure(f"login returned {r.status_code}")


class StressGateUser(HttpUser):
    """Stress profile — pure gate-validation burst (peak entry hours)."""

    wait_time = between(0.1, 0.5)

    def on_start(self):
        self.anonymous_id = str(uuid.uuid4())
        self.qr_token = _qr_token(self.anonymous_id)

    @task
    def hammer_gate(self):
        with self.client.post(
            f"{HOSTS['gateway']}/api/v1/gate/validate",
            json={"token": self.qr_token},
            name="STRESS POST /api/v1/gate/validate",
            catch_response=True,
        ) as r:
            if r.status_code != 200:
                r.failure(f"stress gate returned {r.status_code}")


# Print a summary at the end of the run
@events.quitting.add_listener
def _final_report(environment, **_kwargs):
    stats = environment.stats.total
    print("\n=== CircleGuard Performance Summary ===")
    print(f"Total requests : {stats.num_requests}")
    print(f"Failures       : {stats.num_failures} ({stats.fail_ratio*100:.2f}%)")
    print(f"Median (ms)    : {stats.median_response_time}")
    print(f"95p (ms)       : {stats.get_response_time_percentile(0.95)}")
    print(f"99p (ms)       : {stats.get_response_time_percentile(0.99)}")
    print(f"Throughput RPS : {stats.total_rps:.2f}")
