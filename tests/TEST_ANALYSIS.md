# CircleGuard - Test Analysis

This document explains every test added for Activity 3, why it matters,
and how to interpret its results.

---

## 1. Unit tests (25 new tests)

Each unit test exercises **one component in isolation** with all external
dependencies mocked. They run as part of `./gradlew test` and produce
JUnit XML + Jacoco coverage reports.

### 1.1 `JwtTokenServiceTest` (auth-service, 5 tests)

`services/circleguard-auth-service/src/test/java/com/circleguard/auth/service/JwtTokenServiceTest.java`

| # | Test | What it validates |
|---|------|--------------------|
| 1 | `tokenSubjectIsAnonymousId` | The JWT `sub` claim is the anonymousId — privacy invariant; real identity must never be in the token |
| 2 | `tokenIncludesPermissionsClaim` | All `GrantedAuthority` values are serialized into `permissions[]` so downstream services can authorize without another LDAP lookup |
| 3 | `tokenWithNoAuthoritiesHasEmptyPermissions` | Empty list rather than `null` (defensive — downstream services iterate without null-checks) |
| 4 | `tokenExpirationIsConfigured` | The `exp` claim respects the configured `jwt.expiration` window (within 5s slack) |
| 5 | `tokenIsSignedAndVerifiable` | Token can be parsed with the same secret — guards against signing-algorithm regressions |

**Why these:** A regression here either leaks identity (test 1), enables privilege
escalation (tests 2-3), creates session-expiry surprises (test 4), or breaks JWT
verification across services (test 5). Each is fast (<60ms each), deterministic,
and runs without infrastructure.

### 1.2 `QrTokenServiceTest` (auth-service, 3 tests)

| # | Test | What it validates |
|---|------|--------------------|
| 1 | `qrTokenSubjectIsAnonymousId` | QR `sub` is anonymousId, mirroring login JWT |
| 2 | `qrTokenHasShortExpiration` | QR tokens expire within configured window (campus-entry security — tokens cannot be re-played hours later) |
| 3 | `qrTokensAreUnique` | Two consecutive tokens differ — replay-attack mitigation |

### 1.3 `SymptomMapperEdgeCasesTest` (form-service, 6 tests)

| # | Test | What it validates |
|---|------|--------------------|
| 1 | `detectsCough` | "cough" keyword triggers symptom |
| 2 | `detectsBreathingDifficulty` | "breathing" keyword triggers symptom |
| 3 | `unrelatedYesAnswerDoesNotTriggerSymptom` | Non-symptom YES answer (e.g. "have you traveled?") does NOT promote to SUSPECT — false-positive guard |
| 4 | `noSymptomsWhenResponsesNull` | Null responses defensively returns false (no NPE crash) |
| 5 | `noSymptomsWhenQuestionnaireNull` | Null questionnaire returns false |
| 6 | `detectsAnyOneSymptomFromMultiple` | `anyMatch` short-circuits — one symptom is enough to trigger |

**Why these:** SymptomMapper drives the `SUSPECT/ACTIVE` health-status promotion.
A false negative leaves a symptomatic user inside campus; a false positive denies
campus access to a healthy user. Both are user-visible incidents.

### 1.4 `IdentityEncryptionConverterAdditionalTest` (identity-service, 5 tests)

| # | Test | What it validates |
|---|------|--------------------|
| 1 | `encryptNullReturnsNull` | Null safety — JPA may pass null fields |
| 2 | `decryptNullReturnsNull` | Null safety on read |
| 3 | `asciiRoundtrip` | encrypt(decrypt(x)) == x for ASCII |
| 4 | `unicodeRoundtrip` | Same for unicode (Spanish accents, Chinese chars) — most students at Universidad de los Andes have non-ASCII in their LDAP records |
| 5 | `encryptionIsNonDeterministic` | Identical plaintext → different ciphertext (semantic security; an attacker reading the DB cannot infer that two rows belong to the same user) |

### 1.5 `QrValidationServiceEdgeCasesTest` (gateway-service, 6 tests)

| # | Test | What it validates |
|---|------|--------------------|
| 1 | `rejectsGarbageToken` | Malformed JWT → fail-closed RED |
| 2 | `rejectsEmptyToken` | Empty string → fail-closed RED |
| 3 | `rejectsTokenWithBadSignature` | Wrong secret → fail-closed RED (no token forgery) |
| 4 | `rejectsExpiredToken` | Replayed expired token → fail-closed RED |
| 5 | `denyPotentialStatus` | POTENTIAL status (contact of confirmed) → blocked |
| 6 | `allowsAccessWhenNoStatusInRedis` | New user with no status entry → fail-open GREEN (documented current behaviour; flag for security review) |

---

## 2. Integration tests (12 tests in 5 files)

`tests/integration/test_*.py` — pytest-based, run against the deployed K8s
cluster via port-forward. They verify **service-to-service contracts**.

### 2.1 `test_auth_identity_integration.py` (3 tests)

Auth service depends on identity service via REST. These verify the network
path and the `/api/v1/identities/map` contract.

### 2.2 `test_form_kafka_integration.py` (1 test)

Submits a survey via HTTP, then connects directly to Kafka and waits for
the `survey.submitted` event. Validates **producer side** of the async
contact-tracing pipeline.

### 2.3 `test_promotion_kafka_integration.py` (1 test)

Publishes `survey.submitted` directly to Kafka and waits for promotion-service
to emit `promotion.status.changed`. Validates **consumer side** + downstream
publish. (Skips gracefully if Neo4j wiring is missing.)

### 2.4 `test_gateway_redis_integration.py` (3 tests)

Pre-seeds Redis with a status, signs a QR token with the shared secret, and
verifies the gateway returns the right access decision. Validates the
**JWT + Redis** dual-dependency on the access path.

### 2.5 `test_dashboard_promotion_integration.py` (3 tests)

Verifies dashboard-service can call promotion-service's stats endpoint and
returns JSON. Validates the **read-side cross-service** contract.

---

## 3. E2E tests (15 tests in 5 files)

`tests/e2e/test_*.py` — full user journeys spanning multiple services.

| File | Journey | Services touched |
|------|---------|------------------|
| `test_login_flow.py` | client logs in, receives JWT | auth → identity |
| `test_health_survey_flow.py` | user submits daily health survey | form → kafka → promotion |
| `test_qr_entry_flow.py` | user scans QR at campus turnstile | gateway + redis |
| `test_dashboard_analytics_flow.py` | admin opens analytics dashboard | dashboard → promotion |
| `test_full_lifecycle_flow.py` | symptomatic user is blocked at gate | form → promotion → notification → gateway → dashboard |

Each E2E test prefers `assert` over silent skips when the service is reachable,
but **skips gracefully** when prerequisites (LDAP user, full pipeline wiring)
are unavailable. This keeps the suite green while the dev cluster is being
brought up incrementally.

---

## 4. Performance tests (Locust)

`tests/performance/locustfile.py` — two user profiles:

### 4.1 `CampusUser` — realistic mix

Weighted task distribution that mirrors expected campus traffic:

| Weight | Endpoint | Rationale |
|-------:|----------|-----------|
| 70%    | `POST /api/v1/gate/validate` | Every entry/exit triggers a gate scan |
| 15%    | `POST /api/v1/surveys` | One survey per user per day |
| 10%    | `GET /api/v1/analytics/campus-summary` | Admins poll dashboard |
|  5%    | `POST /api/v1/auth/login` | Token expires hourly |

Recommended run:
```bash
locust -f tests/performance/locustfile.py --headless \
       -u 50 -r 10 -t 60s --host http://localhost:8180 \
       --csv results/perf
```

### 4.2 `StressGateUser` — peak entry surge

Pure gate-validation burst with `wait_time = between(0.1, 0.5)` to simulate
the 8:00am rush at campus turnstiles.

```bash
locust -f tests/performance/locustfile.py --headless \
       -u 200 -r 50 -t 120s --host http://localhost:8087 \
       StressGateUser --csv results/perf-stress
```

### 4.3 Metrics and how to read them

After each run, `--csv results/perf` produces:

| File | Columns to watch |
|------|------------------|
| `results/perf_stats.csv` | **Median**, **95p**, **99p** response time per endpoint, **Failure %** |
| `results/perf_failures.csv` | Distinct error types — empty file is the success criterion |
| `results/perf_stats_history.csv` | RPS over time — should be flat (steady state) once warm |

#### Acceptance thresholds

| Endpoint | Median | 95p | Failure % |
|----------|-------:|----:|----------:|
| `POST /api/v1/gate/validate` | < 50ms | < 200ms | < 0.1% |
| `POST /api/v1/surveys` | < 200ms | < 500ms | < 0.5% |
| `GET /api/v1/analytics/campus-summary` | < 500ms | < 1500ms | < 1% |
| `POST /api/v1/auth/login` | < 800ms | < 2000ms | < 1% |

`gate/validate` is the tightest target because it is on the synchronous campus-entry path.
`auth/login` is loosest because it includes LDAP roundtrip + bcrypt verification.

#### Throughput targets (single dev pod)

- `CampusUser`, 50 VUs → **≥ 200 RPS aggregate**, gate validate ≥ 140 RPS
- `StressGateUser`, 200 VUs → **≥ 800 RPS** sustained on gate-validate alone

If observed throughput is < 50% of these and 99p latency is > 2× median, the
bottleneck is most likely Redis connection pooling (`spring.data.redis.lettuce.pool.max-active`)
or the Spring HTTP thread pool (`server.tomcat.threads.max`).

---

## 5. How tests map to the assignment

| Requirement | Count | Files |
|-------------|------:|-------|
| ≥5 unit tests | **25** | 5 new test files (JwtTokenServiceTest, QrTokenServiceTest, SymptomMapperEdgeCasesTest, IdentityEncryptionConverterAdditionalTest, QrValidationServiceEdgeCasesTest) |
| ≥5 integration tests | **12 across 5 files** | tests/integration/ |
| ≥5 E2E tests | **15 across 5 files** | tests/e2e/ |
| Locust perf+stress | **2 user profiles** | tests/performance/locustfile.py |

All tests target functionality that exists in the current code: JWT token
generation, identity encryption, symptom detection, QR validation,
Kafka pipelines, Redis cache, and cross-service REST calls. None of them
require new application code to be written.
