# CircleGuard — Design Patterns

This document satisfies **Req 3 (Patrones de Diseño, 10%)** of the final
project. It describes:

1. The architectural and code-level patterns **already present** in the
   CircleGuard codebase before this requirement was implemented.
2. The two patterns **added by this requirement** — a resilience pattern
   (Resilience4j Circuit Breaker) and a configuration pattern
   (Feature Toggle backed by Spring `@ConfigurationProperties` and K8s
   ConfigMaps).
3. How these patterns interact with the rest of the stack
   (observability, change management).
4. The trade-offs that drove our choices.

> Related: [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md),
> [`CI_CD.md`](CI_CD.md), [`BRANCHING.md`](BRANCHING.md).

---

## 1. Patterns already present in the architecture

CircleGuard is a Spring Boot 3 / Java 21 microservice system. Even before
Req 3, several well-known patterns were in use. The table lists them with a
canonical file as evidence; the prose underneath explains why each pattern
fits.

| # | Pattern | Category | Where it lives | Representative file |
|---|---------|----------|----------------|---------------------|
| 1 | **API Gateway** | Integration | `circleguard-gateway-service` is the single ingress for QR validation and routing | [`services/circleguard-gateway-service/src/main/java/com/circleguard/gateway/controller/GateController.java`](../services/circleguard-gateway-service/src/main/java/com/circleguard/gateway/controller/GateController.java) |
| 2 | **Database-per-Service** | Decomposition | Each service owns its own PostgreSQL DB (`circleguard_auth`, `circleguard_identity`, `circleguard_dashboard`, …) | [`init-db.sql`](../init-db.sql), [`k8s/dev/services.yml`](../k8s/dev/services.yml) |
| 3 | **Event-Driven Architecture (Kafka)** | Integration | Promotion publishes status changes, notification subscribes | [`services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/ExposureNotificationListener.java`](../services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/ExposureNotificationListener.java) |
| 4 | **Repository (DAO)** | Persistence | Each service exposes Spring Data JPA repositories | [`services/circleguard-auth-service/src/main/java/com/circleguard/auth/repository/LocalUserRepository.java`](../services/circleguard-auth-service/src/main/java/com/circleguard/auth/repository/LocalUserRepository.java) |
| 5 | **Strategy (multi-channel dispatcher)** | Behavioural | Notification picks among Email / SMS / Push / LMS strategies | [`services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/NotificationDispatcher.java`](../services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/NotificationDispatcher.java) |
| 6 | **Filter Chain (Spring Security)** | Security | JWT auth filter + dual-chain provider compose into the filter chain | [`services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/JwtAuthenticationFilter.java`](../services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/JwtAuthenticationFilter.java) |
| 7 | **Anti-Corruption Layer / Client Adapter** | Integration | `IdentityClient` / `PromotionClient` translate between services | [`services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/client/PromotionClient.java`](../services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/client/PromotionClient.java) |
| 8 | **Saga (implicit, choreographed)** | Workflow | The login → identity → promotion → notification flow forms a choreographed saga over Kafka | See sections 3 and 4 of [`SPRINTS.md`](SPRINTS.md) (tracked as **CG-007**) |

### 1.1 API Gateway

`circleguard-gateway-service` (port 8087) is the single entry point that the
mobile app talks to. It validates QR tokens against Redis and forwards the
authenticated payload to downstream services. This is the classic
*API Gateway* pattern — one address, one auth surface, fan-out internally.

### 1.2 Database-per-Service

Look at the `circleguard-config` ConfigMap in `k8s/dev/services.yml`: every
deployment overrides `SPRING_DATASOURCE_URL` to point at a **distinct**
database (`postgresql://postgres:5432/circleguard_<service>`). No service
reads another's tables — they integrate through HTTP or Kafka. This is what
Sam Newman calls "the strongest form of microservice independence" and it is
the precondition for the Database-per-Service pattern.

### 1.3 Event-Driven Architecture (Kafka)

`ExposureNotificationListener` subscribes to the `promotion.status.changed`
topic with `@KafkaListener`. The publisher (`circleguard-promotion-service`)
never knows the listener exists — they communicate exclusively through Kafka.
This decouples lifecycle (a slow notification dispatch does not block status
promotion) and enables independent scaling.

### 1.4 Repository

Every service that owns persistent state exposes a `*Repository` interface
extending `JpaRepository`. The Repository pattern hides JPA from the service
layer and makes unit testing trivial (`@MockBean LocalUserRepository`).

### 1.5 Strategy (multi-channel dispatcher)

`NotificationDispatcher` does not know how to send an email or a push — it
delegates to `EmailService`, `SmsService`, `PushService`, `LmsService`.
Each implementation is a Strategy; the dispatcher is the context. Adding a
fifth channel (Slack, Webhook, …) requires writing one new bean and one
line in the dispatcher, not editing the existing channels.

### 1.6 Filter Chain (Spring Security)

`JwtAuthenticationFilter` extends `OncePerRequestFilter` and is composed
with the rest of Spring Security's filter chain in `SecurityConfig`. The
*Chain of Responsibility* pattern is exactly what Spring Security ships out
of the box.

### 1.7 Anti-Corruption Layer / Client Adapter

`PromotionClient` and `IdentityClient` wrap raw HTTP calls and return
**domain** types (`UUID`, `Map<String, Object>`), shielding callers from
the wire protocol. This is a small but real ACL — the rest of the
auth-service never sees a `RestTemplate` or a JSON tree.

### 1.8 Saga (implicit, choreographed)

The end-to-end login flow:

```
LoginController -> IdentityClient -> identity-service
                                        |  (creates anon UUID)
                                        v
                              promotion.status.changed (Kafka)
                                        v
                              notification-service dispatches
```

…is a **choreographed saga**: there is no orchestrator, each service
publishes an event and listeners react. The compensating action for a
failed notification is a Kafka retry (see `NotificationRetryTest`). The
saga is tracked under sprint item **CG-007**; an explicit orchestrator
(e.g., Temporal) is out of scope for this iteration.

---

## 2. Patterns added by this project (Req 3)

### 2.1 Circuit Breaker (Resilience4j) — Req 3.a "resilience pattern"

**Problem.** When `identity-service` is slow or down, every login on
`auth-service` blocks for the full HTTP timeout (2 seconds × 3 retries
= 6 seconds), thread-pool fills, and a transient identity outage becomes
a full auth outage.

**Solution.** Wrap the only RPC into identity-service — `IdentityClient.getAnonymousId(...)` —
in a Resilience4j Circuit Breaker plus a Retry, with a deterministic
fallback that returns a placeholder UUID.

**Code.**

- Client: [`services/circleguard-auth-service/src/main/java/com/circleguard/auth/client/IdentityClient.java`](../services/circleguard-auth-service/src/main/java/com/circleguard/auth/client/IdentityClient.java)
  — annotated with `@CircuitBreaker(name="identity-service", fallbackMethod="fallback")`
  and `@Retry(name="identity-service")`.
- RestTemplate bean with tight timeouts: [`services/circleguard-auth-service/src/main/java/com/circleguard/auth/config/HttpClientConfig.java`](../services/circleguard-auth-service/src/main/java/com/circleguard/auth/config/HttpClientConfig.java).
- Config: [`services/circleguard-auth-service/src/main/resources/application.yml`](../services/circleguard-auth-service/src/main/resources/application.yml)
  under `resilience4j:`.
- Test (MockWebServer): [`services/circleguard-auth-service/src/test/java/com/circleguard/auth/client/IdentityClientCircuitBreakerTest.java`](../services/circleguard-auth-service/src/test/java/com/circleguard/auth/client/IdentityClientCircuitBreakerTest.java)
  proves CLOSED → OPEN → HALF_OPEN → CLOSED transitions and that the
  fallback runs while OPEN.

**Configuration knobs.**

```yaml
resilience4j:
  circuitbreaker:
    instances:
      identity-service:
        slidingWindowSize: 20             # last 20 calls drive the rate
        minimumNumberOfCalls: 10          # do not trip on cold start
        failureRateThreshold: 50          # > 50% failures => OPEN
        waitDurationInOpenState: 10s      # cool-off before HALF_OPEN
        permittedNumberOfCallsInHalfOpenState: 2
        automaticTransitionFromOpenToHalfOpenEnabled: true
  retry:
    instances:
      identity-service:
        maxAttempts: 3
        waitDuration: 500ms
```

**Observability.** Resilience4j publishes
`resilience4j_circuitbreaker_state` and
`resilience4j_circuitbreaker_calls_total{kind=successful|failed}` to
Micrometer. The `/actuator/prometheus` endpoint is enabled (see
`management.endpoints.web.exposure.include`), so Prometheus scrapes those
metrics and the Grafana "Service Health" dashboard (see
[`docs/runbooks/`](runbooks)) plots breaker state per instance. A breaker
flipping to `OPEN` raises a P2 alert.

**Local test.**

```bash
./gradlew :services:circleguard-auth-service:test --tests \
  com.circleguard.auth.client.IdentityClientCircuitBreakerTest
```

### 2.2 Feature Toggle — Req 3.b "configuration pattern"

**Problem.** We want to ship work-in-progress code paths (an experimental
GraphQL endpoint, a hotspot-map) without conditioning their visibility on
deploying a new image. Particularly in PROD, we want a human approver to
flip the switch via Change Management without re-running the pipeline.

**Solution.** A `@ConfigurationProperties("features")` POJO
(`FeatureToggles`) holds typed boolean flags. Default values live in
`application.yml`; per-environment overrides live in a dedicated K8s
ConfigMap (`dashboard-service-feature-toggles`) injected as env vars.
Endpoints check the flag and return `404 Not Found` if disabled.

**Code.**

- POJO: [`services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/config/FeatureToggles.java`](../services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/config/FeatureToggles.java)
- Bootstrap (`@EnableConfigurationProperties`): [`services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/DashboardApplication.java`](../services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/DashboardApplication.java)
- Demo controller: [`services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/controller/FeatureGatedController.java`](../services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/controller/FeatureGatedController.java)
- Defaults: [`services/circleguard-dashboard-service/src/main/resources/application.yml`](../services/circleguard-dashboard-service/src/main/resources/application.yml)
- K8s overrides per env:
  - [`k8s/dev/dashboard-service-feature-toggles.yaml`](../k8s/dev/dashboard-service-feature-toggles.yaml)
  - [`k8s/stage/dashboard-service-feature-toggles.yaml`](../k8s/stage/dashboard-service-feature-toggles.yaml)
  - [`k8s/master/dashboard-service-feature-toggles.yaml`](../k8s/master/dashboard-service-feature-toggles.yaml)
- Integration test: [`services/circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/FeatureToggleIT.java`](../services/circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/FeatureToggleIT.java)

**How to flip a toggle (no image rebuild).**

```bash
# 1. Edit the per-env ConfigMap
kubectl -n circleguard-master edit configmap dashboard-service-feature-toggles
#    change: FEATURES_GRAPHQL_ENDPOINT_ENABLED: "true"

# 2. Roll the dashboard pods so they re-read the env vars
kubectl -n circleguard-master rollout restart deployment dashboard-service

# 3. Confirm
curl https://api.circleguard.example/api/v1/dashboard/feature-toggles
# {"graphqlEndpointEnabled":true,"hotspotMapEnabled":true}
```

That sequence is a **Standard change** under
[`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) §1, so it does not require a
CAB review.

### 2.3 Saga (cross-reference)

The choreographed saga described in §1.8 is treated as
*already-implemented* by the Kafka wiring between promotion-service and
notification-service. Promoting it to an *orchestrated* saga (Temporal,
Camunda, or a hand-written orchestrator) is captured as sprint item
**CG-007** and is out of scope for Req 3.

---

## 3. How the new patterns interact with the rest of the stack

```mermaid
flowchart LR
    subgraph Mobile
        APP[CircleGuard App]
    end

    subgraph K8s["Kubernetes Cluster"]
        GW[circleguard-gateway-service]

        subgraph AUTH["circleguard-auth-service"]
            LC[LoginController]
            IC[IdentityClient<br/>@CircuitBreaker<br/>@Retry]
        end

        ID[circleguard-identity-service]

        subgraph DASH["circleguard-dashboard-service"]
            FT[FeatureToggles<br/>@ConfigurationProperties]
            FGC[FeatureGatedController]
        end

        CM[(ConfigMap<br/>dashboard-service-feature-toggles)]
        PROM[(Prometheus)]
        GRAF[(Grafana)]
    end

    APP -->|/login| GW --> LC --> IC
    IC -->|HTTP /identities/map| ID
    IC -. fallback when OPEN .-> LC

    CM -. mounted as env vars .-> FT
    FT --> FGC
    APP -->|/api/v1/dashboard/graphql/ping| GW --> FGC

    IC -. resilience4j_* metrics .-> PROM --> GRAF
    FT -. /actuator/configprops .-> PROM
```

- **Circuit Breaker → Observability.** The breaker emits Micrometer
  metrics; Prometheus scrapes `/actuator/prometheus` on every service pod;
  Grafana dashboards visualise the breaker state. See
  [`docs/runbooks/`](runbooks) for the on-call runbook entry that fires
  when a breaker is OPEN > 5 minutes.

- **Feature Toggles → Change Management.** ConfigMap edits are governed by
  the *Standard change* category in [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md).
  No image rebuild, no semantic-release bump — only a `kubectl edit cm` +
  `rollout restart`. The change is auditable because ConfigMaps are
  versioned in Git (`k8s/<env>/`) and applied via the deploy pipeline
  ([`CI_CD.md`](CI_CD.md) §`.gitlab/ci/deploy.yml`).

---

## 4. Trade-offs

### 4.1 Resilience4j vs. Hystrix

| Option | Verdict | Reason |
|--------|---------|--------|
| Netflix **Hystrix** | rejected | Officially in *maintenance mode* since 2018; no Spring Boot 3 starter, last release predates Java 17. |
| **Resilience4j** | chosen | Spring Boot 3 first-class starter (`resilience4j-spring-boot3`), tiny footprint, Micrometer-native, modular (circuit breaker + retry + bulkhead + rate-limiter all separately composable). |
| Spring Cloud Circuit Breaker abstraction over R4J | rejected | Adds a layer with no extra value for a single backing implementation; harder to reason about config. |

### 4.2 ConfigMap-backed `@ConfigurationProperties` vs. Unleash / LaunchDarkly

| Option | Verdict | Reason |
|--------|---------|--------|
| **LaunchDarkly** | rejected | SaaS, paid, requires outbound internet — overkill for a student project; adds an external trust boundary. |
| **Unleash** | rejected | Self-hostable but ships its own Postgres + admin UI; doubles our infra surface for what amounts to two booleans. |
| **Spring `@ConfigurationProperties` + K8s ConfigMap** | chosen | Zero new infrastructure, native to Spring Boot, the ConfigMap is already declarative (Git-versioned), perfectly adequate for a small set of long-lived toggles. The trade-off — no per-request, per-user targeting — is acceptable: we only need *environment-scoped* toggles. |

### 4.3 Why a new controller instead of editing `AnalyticsController`

The brief allowed either, but the safer option (and the one chosen) was to
add a dedicated `FeatureGatedController`. Editing the existing controller
would have risked breaking the pre-existing `AnalyticsControllerTest`; a
new controller keeps the *blast radius* of Req 3 minimal and makes the
toggle demo trivially discoverable.

---

## 5. Quick reference

| Action | Command |
|--------|---------|
| Run the circuit-breaker test | `./gradlew :services:circleguard-auth-service:test --tests "*IdentityClientCircuitBreakerTest"` |
| Run the feature-toggle IT | `./gradlew :services:circleguard-dashboard-service:test --tests "*FeatureToggleIT"` |
| Inspect breaker state in PROD | `curl http://auth-service:8180/actuator/circuitbreakers` |
| Inspect live toggles in a pod | `curl http://dashboard-service:8084/api/v1/dashboard/feature-toggles` |
| Flip a toggle | `kubectl -n circleguard-<env> edit cm dashboard-service-feature-toggles` then `kubectl rollout restart deployment dashboard-service` |
