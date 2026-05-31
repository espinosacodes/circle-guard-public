# CircleGuard — System Architecture

This document is the **single source of truth** for the CircleGuard system
architecture. It uses the [C4 model](https://c4model.com/) to present the
system at three levels of zoom (Context → Container → Component), then
zooms further into data, deployment, and cross-cutting concerns.

> Companion documents:
> - [`OPERATIONS.md`](OPERATIONS.md) — how to run this in prod.
> - [`SECURITY.md`](SECURITY.md) — controls referenced from §7 here.
> - [`OBSERVABILITY.md`](OBSERVABILITY.md) — metrics/logs/traces stack.
> - [`PATTERNS.md`](PATTERNS.md) — design patterns referenced from §3.
> - [`CHAOS_EXPERIMENTS.md`](CHAOS_EXPERIMENTS.md) — fault-injection plans.
> - [`COSTS.md`](COSTS.md) — cost / capacity model behind §5.

---

## 1. C4 Level 1 — System Context

CircleGuard sits between three end-user populations and a small set of
external messaging providers. The system has **one logical address**
(`api.circleguard.<campus>.edu`) regardless of which microservice
ultimately handles a request.

```mermaid
flowchart TB
    subgraph Users["End users"]
        STU["Student<br/>(mobile app)"]
        HCO["Health Center Officer<br/>(web console)"]
        ITA["IT / DevOps Admin<br/>(kubectl + Grafana)"]
    end

    subgraph External["External providers"]
        EMAIL[("SendGrid<br/>(email)")]
        SMS[("Twilio<br/>(SMS)")]
        PUSH[("FCM / APNs<br/>(mobile push)")]
        LDAP[("University LDAP<br/>(student SSO)")]
        LMS[("Canvas / Moodle<br/>(class roster)")]
    end

    CG{{"CircleGuard System<br/>Privacy-first campus<br/>contact tracing & fencing"}}

    STU -- "Submit symptom survey<br/>Scan campus QR<br/>Receive fence alerts" --> CG
    HCO -- "De-identify case<br/>Review circle graph<br/>Trigger fence" --> CG
    ITA -- "Deploy / scale<br/>Read dashboards<br/>Investigate alerts" --> CG

    CG -- "SMTP / HTTPS" --> EMAIL
    CG -- "REST / HTTPS" --> SMS
    CG -- "HTTPS push" --> PUSH
    CG -- "LDAP/S" --> LDAP
    CG -- "LTI 1.3 / REST" --> LMS

    classDef ext fill:#fef3c7,stroke:#f59e0b
    classDef sys fill:#dbeafe,stroke:#1e40af,stroke-width:3px
    classDef usr fill:#dcfce7,stroke:#16a34a
    class EMAIL,SMS,PUSH,LDAP,LMS ext
    class CG sys
    class STU,HCO,ITA usr
```

**Key invariants from this view:**

- Students never talk to internal services directly — every request enters
  through the **Gateway** (containerised as `circleguard-gateway-service`).
- The system never *originates* an SMS / Email / Push — it only *requests*
  delivery via a vetted external provider, so message-platform compliance
  (CAN-SPAM, TCPA) lives outside our trust boundary.
- LDAP and LMS are **read-only** integrations; CircleGuard is never a
  write source for the campus's identity systems.

---

## 2. C4 Level 2 — Container

Eight Spring Boot services, three stateful data stores, one cache, one
message bus, and one ingress.

```mermaid
flowchart TB
    MOBILE["Mobile / Web Client<br/>(Expo + React Native)"]
    BROWSER["Health Center Console<br/>(React SPA, served by gateway)"]

    subgraph Edge["Edge"]
        ISTIO["Istio Ingress Gateway<br/>+ cert-manager TLS"]
        GW["circleguard-gateway-service<br/>(Spring Boot 3, :8087)"]
    end

    subgraph Core["Core domain services"]
        AUTH["circleguard-auth-service<br/>(:8081) JWT + dual-chain LDAP/local"]
        ID["circleguard-identity-service<br/>(:8082) anonymisation vault"]
        FORM["circleguard-form-service<br/>(:8083) symptom surveys"]
        PROMO["circleguard-promotion-service<br/>(:8084) status engine"]
        NOTIF["circleguard-notification-service<br/>(:8085) multi-channel dispatch"]
        DASH["circleguard-dashboard-service<br/>(:8086) analytics API"]
        FILE["circleguard-file-service<br/>(:8088) cert / doc storage"]
    end

    subgraph Data["Stateful infrastructure"]
        PG[("Postgres 16<br/>per-service DBs<br/>+ identity vault")]
        NEO[("Neo4j 5.26<br/>contact graph<br/>14-day TTL edges")]
        KAFKA{{"Apache Kafka 7.6<br/>topics:<br/>promotion.status.changed<br/>form.submitted<br/>notification.dispatch<br/>audit.events"}}
        REDIS[("Redis 7.2<br/>QR cache<br/>session L2")]
        OBJ[("GCS / S3<br/>signed PDFs<br/>medical certs")]
    end

    MOBILE -- "HTTPS" --> ISTIO
    BROWSER -- "HTTPS" --> ISTIO
    ISTIO -- "HTTP + mTLS" --> GW

    GW -- "REST" --> AUTH
    GW -- "REST" --> FORM
    GW -- "REST" --> DASH
    GW -- "REST" --> FILE

    AUTH -- "REST" --> ID
    FORM -- "produce: form.submitted" --> KAFKA
    PROMO -- "consume: form.submitted" --> KAFKA
    PROMO -- "produce: promotion.status.changed" --> KAFKA
    NOTIF -- "consume: promotion.status.changed" --> KAFKA
    NOTIF -- "produce: notification.dispatch" --> KAFKA

    DASH -- "REST (read-only)" --> PROMO
    DASH -- "REST (read-only)" --> ID

    AUTH -- "JDBC" --> PG
    ID -- "JDBC (vault DB)" --> PG
    FORM -- "JDBC" --> PG
    NOTIF -- "JDBC" --> PG
    DASH -- "JDBC" --> PG
    FILE -- "JDBC (metadata)" --> PG

    PROMO -- "Bolt protocol" --> NEO
    DASH -- "Bolt (read-only)" --> NEO

    GW -- "Redis protocol<br/>(QR validation)" --> REDIS
    AUTH -- "Redis (session)" --> REDIS

    FILE -- "S3 API" --> OBJ

    classDef edge fill:#fef3c7,stroke:#f59e0b
    classDef svc fill:#dbeafe,stroke:#1e40af
    classDef data fill:#f3e8ff,stroke:#7c3aed
    classDef ui fill:#dcfce7,stroke:#16a34a
    class ISTIO,GW edge
    class AUTH,ID,FORM,PROMO,NOTIF,DASH,FILE svc
    class PG,NEO,KAFKA,REDIS,OBJ data
    class MOBILE,BROWSER ui
```

### 2.1 Service responsibilities (one-liner each)

| Service                    | Port | Owns                                                                                              |
|----------------------------|-----:|---------------------------------------------------------------------------------------------------|
| `gateway-service`          | 8087 | Public ingress, QR validation against Redis, request fan-out.                                     |
| `auth-service`             | 8081 | JWT issuance, dual-chain LDAP/local authentication, RBAC claim assembly.                          |
| `identity-service`         | 8082 | Salted-hash anonymisation vault, "right-to-be-forgotten" purges, real-name ↔ anon UUID mapping.   |
| `form-service`             | 8083 | Dynamic symptom-survey rendering, submission persistence, Kafka publish.                          |
| `promotion-service`        | 8084 | Status engine (`Suspect → Probable → Confirmed`), recursive Neo4j traversal, Saga orchestration.  |
| `notification-service`     | 8085 | Strategy-pattern multi-channel dispatcher (Email, SMS, Push, LMS), DLQ + retries.                 |
| `dashboard-service`        | 8086 | Aggregated read-only analytics for Health Center console (hotspots, circle counts).               |
| `file-service`             | 8088 | Signed-URL upload/download of medical certificates to S3-compatible storage.                      |

### 2.2 Kafka topic catalogue

| Topic                        | Producer                | Consumer(s)                              | Schema                          |
|------------------------------|-------------------------|------------------------------------------|----------------------------------|
| `form.submitted`             | `form-service`          | `promotion-service`                      | `SymptomSurveyEvent` (Avro)      |
| `promotion.status.changed`   | `promotion-service`     | `notification-service`, `dashboard-service` | `StatusPromotionEvent` (Avro)  |
| `notification.dispatch`      | `notification-service`  | (DLQ retry consumer in same service)     | `DispatchAttemptEvent` (JSON)    |
| `audit.events`               | *all services*          | log-shipper to Loki + GCS                | `AuditEvent` (JSON)              |
| `identity.purge.requested`   | `auth-service`          | `identity-service`                       | `PurgeRequestEvent` (Avro)       |

---

## 3. C4 Level 3 — Component (`promotion-service` deep dive)

`promotion-service` is the heart of CircleGuard. We zoom in on it because
(a) it owns the most business logic, (b) it touches every data store, and
(c) it implements the Saga pattern that the rest of the system rides on
(see [`PATTERNS.md`](PATTERNS.md) §2.4).

```mermaid
flowchart TB
    subgraph Promotion["circleguard-promotion-service (Spring Boot 3, :8084)"]
        direction TB

        subgraph Inbound["Inbound adapters"]
            REST["REST Controller<br/>POST /promotions<br/>GET /promotions/{id}"]
            KCONS["Kafka Consumer<br/>@KafkaListener<br/>form.submitted"]
        end

        subgraph Application["Application layer"]
            SVC["PromotionService<br/>(transactional orchestrator)"]
            SAGA["PromotionSaga<br/>(state machine:<br/>Suspect → Probable → Confirmed)"]
            CB["Resilience4j<br/>CircuitBreaker<br/>('identityClient', 'notifyClient')"]
            FT["FeatureToggle<br/>@ConfigurationProperties<br/>feature.cascade.depth"]
        end

        subgraph Domain["Domain layer"]
            CIRCLE["Circle (aggregate)"]
            EVENT["PromotionEvent (entity)"]
            POL["PromotionPolicy<br/>(business rules)"]
        end

        subgraph Outbound["Outbound adapters"]
            REPO["PromotionRepository<br/>(Spring Data JPA)"]
            GRAPH["CircleGraphClient<br/>(Spring Data Neo4j)"]
            IDCLI["IdentityClient<br/>(WebClient + R4J)"]
            KPROD["Kafka Producer<br/>promotion.status.changed"]
            METRICS["Micrometer<br/>circleguard_promotions_total"]
        end
    end

    PG[("Postgres<br/>circleguard_promotion")]
    NEO[("Neo4j<br/>contact graph")]
    KAFKA{{"Kafka"}}
    IDSVC["identity-service"]

    REST --> SVC
    KCONS --> SVC
    SVC --> SAGA
    SAGA --> POL
    SAGA --> CB
    CB --> IDCLI
    SAGA --> FT
    POL --> CIRCLE
    POL --> EVENT
    SVC --> REPO
    SVC --> GRAPH
    SVC --> KPROD
    SVC --> METRICS

    REPO --> PG
    GRAPH --> NEO
    KPROD --> KAFKA
    IDCLI --> IDSVC

    classDef adapter fill:#fef3c7,stroke:#f59e0b
    classDef app fill:#dbeafe,stroke:#1e40af
    classDef domain fill:#dcfce7,stroke:#16a34a
    classDef out fill:#f3e8ff,stroke:#7c3aed
    class REST,KCONS adapter
    class SVC,SAGA,CB,FT app
    class CIRCLE,EVENT,POL domain
    class REPO,GRAPH,IDCLI,KPROD,METRICS out
```

The layering follows hexagonal architecture: **adapters depend on the
application; the application depends on the domain; the domain depends on
nothing**. Tests assert this with ArchUnit at build time.

---

## 4. Data architecture (hybrid, four stores)

Different questions deserve different data engines. We chose four:

```mermaid
flowchart LR
    subgraph "Why Postgres?"
        Q1["'Who is anon-UUID 0xabc123?'<br/>ACID, FK, row-level encryption"]
    end
    subgraph "Why Neo4j?"
        Q2["'Who shared a class with X in the last 14 days,<br/>recursively up to 3 hops?'<br/>Native graph traversal,<br/>SQL would require N self-joins"]
    end
    subgraph "Why Kafka?"
        Q3["'When status changed, notify N consumers<br/>in any order, replayable for 7 days.'<br/>Persistent log, decoupling, audit"]
    end
    subgraph "Why Redis?"
        Q4["'Is QR token T still valid at gate G?'<br/>p99 < 1 ms reads, TTL-based expiry"]
    end

    PG[("Postgres 16<br/>identity vault +<br/>per-service relational")]
    NEO[("Neo4j 5.26<br/>contact graph<br/>14-day TTL edges")]
    KAFKA{{"Kafka 7.6<br/>event log"}}
    REDIS[("Redis 7.2<br/>L2 cache")]

    Q1 --> PG
    Q2 --> NEO
    Q3 --> KAFKA
    Q4 --> REDIS

    classDef store fill:#f3e8ff,stroke:#7c3aed,stroke-width:2px
    class PG,NEO,KAFKA,REDIS store
```

| Store    | Why this and not Postgres alone?                                                                          | Containment strategy                                                |
|----------|-----------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| Postgres | ACID, row-level encryption, mature backup/PITR. Identity vault must be auditable.                         | Per-service database; vault DB has its own schema and credentials.  |
| Neo4j    | A 3-hop contact query is a single `MATCH` in Cypher vs a 3-table self-join in SQL — orders of magnitude faster at scale. | Edges TTL'd at 14 days; only anon UUIDs stored, never real names.   |
| Kafka    | Decouples publishers from N consumers, persistent audit log, replayable for forensics.                    | Topic retention = 7 days; sensitive payloads carry only anon UUIDs. |
| Redis    | Sub-ms QR validation at campus gates; rate-limiting; session L2.                                          | TTLs aggressive (≤ 15 min); no PII written, only opaque tokens.     |

**Critical privacy invariant:** Neo4j, Kafka, and Redis **never** see a
real name or government-ID number. The mapping `real-id → anon-UUID`
exists in exactly one row of one Postgres table guarded by
`identity-service`. This single chokepoint is what makes FERPA compliance
practical — see [`SECURITY.md`](SECURITY.md) §7.

---

## 5. Deployment topology (multi-cloud)

Production runs on **GKE in `us-central1`** as primary, with **AKS in
`eastus`** as warm-standby for the multi-cloud bonus. State storage and
container images live in GCP; AKS pulls the same images cross-cloud.

```mermaid
flowchart TB
    subgraph GCP["Google Cloud Platform (Primary)"]
        subgraph GCPUSC["us-central1"]
            GKE["GKE Autopilot Cluster<br/>circleguard-prod-gke<br/>3 node pools (system/app/spot)"]
            CSQL[("Cloud SQL Postgres 16<br/>REGIONAL HA")]
            AR[("Artifact Registry<br/>us-central1-docker.pkg.dev")]
            GCS[("GCS<br/>tf state +<br/>file-service blobs")]
            SM[("Secret Manager<br/>+ Workload Identity")]
        end
    end

    subgraph AZ["Microsoft Azure (Secondary / DR)"]
        subgraph AZEUS["eastus"]
            AKS["AKS Cluster<br/>circleguard-prod-aks<br/>spot pool (cost-optimised)"]
            ACR[("ACR<br/>circleguardacr.azurecr.io<br/>(geo-replicated mirror)")]
            AZSQL[("Azure DB for PostgreSQL<br/>(read replica via logical replication)")]
        end
    end

    subgraph TF["Terraform Workspaces"]
        TFD["envs/dev"]
        TFS["envs/stage"]
        TFP["envs/prod"]
        TFBK["backend/<br/>(GCS state, lock via GCS)"]
    end

    USERS["End users<br/>(students, HCO)"]
    DNS["Cloud DNS<br/>api.circleguard.edu<br/>(weighted: 100/0 normal,<br/>0/100 during DR)"]

    USERS --> DNS
    DNS -- "primary" --> GKE
    DNS -- "failover" --> AKS

    AR -- "image pull" --> GKE
    AR -- "image pull (cross-cloud)" --> AKS
    ACR -- "fallback image pull" --> AKS

    CSQL -- "logical replication<br/>(async, RPO ≤ 5 min)" --> AZSQL

    TFD --> GKE
    TFS --> GKE
    TFP --> GKE
    TFP --> AKS
    TFBK --> GCS

    classDef gcp fill:#dbeafe,stroke:#1e40af
    classDef az fill:#fef3c7,stroke:#f59e0b
    classDef tf fill:#dcfce7,stroke:#16a34a
    class GKE,CSQL,AR,GCS,SM gcp
    class AKS,ACR,AZSQL az
    class TFD,TFS,TFP,TFBK tf
```

**Multi-cloud DR strategy** (referenced from [`OPERATIONS.md`](OPERATIONS.md) §6):

| Concern            | Primary (GCP)                                | Secondary (Azure)                              | RPO       | RTO        |
|--------------------|----------------------------------------------|------------------------------------------------|-----------|------------|
| Compute            | GKE Autopilot, 3 zones in us-central1        | AKS spot pool, eastus                          | n/a       | < 15 min   |
| Relational DB      | Cloud SQL REGIONAL HA + 7-day PITR           | Azure PG read-replica (logical replication)    | ≤ 5 min   | < 30 min   |
| Object storage     | GCS multi-region                             | (none — file-service is bridged via GCS API)   | 0         | n/a        |
| Container images   | Artifact Registry                            | ACR mirrored via `acr import` on every release | 0         | n/a        |
| Secrets            | GCP Secret Manager                           | Azure Key Vault (manual seed at DR drill)      | n/a       | < 60 min   |
| DNS                | Cloud DNS weighted records                   | Promoted to 100 % via runbook                  | n/a       | < 5 min    |

**Cost rationale** for the asymmetry (no AKS HA Postgres, no AKS hot
standby) lives in [`COSTS.md`](COSTS.md) §1 and §5 — keeping AKS to a
warm spot pool keeps the DR option open at ~10 % of the cost of a true
active/active multi-cloud setup.

---

## 6. End-to-end request flow

The reference flow: **a student submits a symptom survey, and a fence
cascades to everyone in their circle**. Timings are p95 budgets from
[`OBSERVABILITY.md`](OBSERVABILITY.md) §3.

```mermaid
sequenceDiagram
    autonumber
    actor S as Student (mobile)
    participant ING as Istio Gateway
    participant GW as gateway-service
    participant AUTH as auth-service
    participant FORM as form-service
    participant K as Kafka
    participant PROMO as promotion-service
    participant ID as identity-service
    participant NEO as Neo4j
    participant NOTIF as notification-service
    participant EXT as SendGrid / Twilio / FCM

    S->>ING: POST /api/v1/forms/symptoms (TLS, JWT)
    Note over ING: cert-manager TLS<br/>mTLS to upstream<br/>~10 ms
    ING->>GW: forward (HTTP + mTLS)
    GW->>AUTH: validate JWT
    Note over AUTH: Redis L2 hit<br/>~3 ms
    AUTH-->>GW: 200 + claims
    GW->>FORM: POST /symptoms (with anon-UUID)
    Note over FORM: persist + publish<br/>~25 ms
    FORM->>K: produce form.submitted
    FORM-->>GW: 202 Accepted
    GW-->>S: 202 Accepted
    Note over S,GW: edge p95 ≤ 200 ms (SLO)<br/>see OBSERVABILITY.md

    K-->>PROMO: form.submitted (async)
    Note over PROMO: Saga starts<br/>Suspect → Probable
    PROMO->>ID: GET /anon/{uuid}/circle
    Note over ID: vault lookup<br/>~15 ms
    ID-->>PROMO: circle membership
    PROMO->>NEO: MATCH (s)-[:CONTACT*1..3]-(c) WHERE …
    Note over NEO: graph traversal<br/>14-day window<br/>~40 ms
    NEO-->>PROMO: 47 contacts in circle
    PROMO->>K: produce promotion.status.changed (×47)
    Note over PROMO: end-to-end Saga<br/>≤ 60 s (containment SLO)

    K-->>NOTIF: promotion.status.changed
    NOTIF->>NOTIF: Strategy: pick channel(s)
    NOTIF->>EXT: dispatch email/SMS/push
    Note over EXT: external provider<br/>p95 ≤ 2 s
    EXT-->>NOTIF: 200 OK / 4xx (→ DLQ)
```

**Budget summary:** the synchronous edge (steps 1–7) must complete in
≤ 200 ms p95; the async cascade (steps 8–18) must complete in ≤ 60 s p99
per the headline *Containment Speed* metric in `README.md`. Both SLOs are
wired to alerts in [`OBSERVABILITY.md`](OBSERVABILITY.md) §3.

---

## 7. Cross-cutting concerns

Where each platform-level concern is implemented in the diagrams above:

```mermaid
flowchart LR
    subgraph Concern["Cross-cutting concern"]
        direction TB
        REL["Resilience4j"]
        OTEL["OpenTelemetry"]
        ISTIO["Istio (mesh)"]
        MTLS["mTLS"]
        RBAC["RBAC"]
        FT["Feature Toggles"]
    end

    subgraph Where["Where it lives"]
        direction TB
        SVC["In each Spring Boot service<br/>(circuit breakers, retries, bulkheads)"]
        AGENT["OTel Java agent +<br/>Micrometer registry"]
        SIDECAR["istio-proxy sidecar +<br/>VirtualService / DestinationRule"]
        PEER["PeerAuthentication STRICT<br/>(mesh-wide)"]
        K8S["K8s RBAC + Istio AuthZ +<br/>Spring Security"]
        CFG["@ConfigurationProperties +<br/>ConfigMap rollout"]
    end

    REL --> SVC
    OTEL --> AGENT
    ISTIO --> SIDECAR
    MTLS --> PEER
    RBAC --> K8S
    FT --> CFG

    classDef concern fill:#fef3c7,stroke:#f59e0b
    classDef where fill:#dbeafe,stroke:#1e40af
    class REL,OTEL,ISTIO,MTLS,RBAC,FT concern
    class SVC,AGENT,SIDECAR,PEER,K8S,CFG where
```

| Concern              | Implementation                                                                                                              | Doc reference                                                              |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| **Resilience4j**     | Circuit breaker + retry + bulkhead beans configured in each service's `application.yaml`; metrics emitted to Prometheus.    | [`PATTERNS.md`](PATTERNS.md) §2.1                                          |
| **OpenTelemetry**    | Java agent attached at JVM start (`-javaagent:opentelemetry-javaagent.jar`); OTLP push to Jaeger; trace IDs in MDC for log correlation. | [`OBSERVABILITY.md`](OBSERVABILITY.md) §1                       |
| **Istio**            | Sidecar per pod; `VirtualService` for canary routing and retries; `DestinationRule` for connection-pool circuit-breaking.    | `infra/k8s/istio/`                                                          |
| **mTLS**             | `PeerAuthentication` set to `STRICT` mesh-wide; cert-manager issues public cert to the Istio ingress only.                  | `infra/k8s/istio/peer-authentication-strict.yaml`, [`SECURITY.md`](SECURITY.md) §4 |
| **RBAC**             | Three layers: K8s RBAC (cluster ops), Istio `AuthorizationPolicy` (service-to-service), Spring Security (end-user roles).   | [`SECURITY.md`](SECURITY.md) §3                                            |
| **Feature Toggles**  | `@ConfigurationProperties("feature")` + K8s ConfigMap; rollout policy described in change-management doc.                   | [`PATTERNS.md`](PATTERNS.md) §2.2, [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) |
| **Chaos engineering**| Chaos Mesh installed in `chaos-mesh` namespace; experiments target `circleguard-dev` only.                                   | [`CHAOS_EXPERIMENTS.md`](CHAOS_EXPERIMENTS.md)                              |
| **FinOps**           | Spot pools dev/stage, scale-to-zero CronJobs, billing export to BigQuery.                                                    | [`COSTS.md`](COSTS.md)                                                      |

---

## 8. Architecture Decision Records (rolled up)

The decisions baked into the diagrams above, with the rejected
alternatives:

| Decision                                    | Chose             | Rejected                  | Why                                                                       |
|---------------------------------------------|-------------------|---------------------------|---------------------------------------------------------------------------|
| Primary cloud                               | GCP               | AWS / Azure-only          | Free GKE control plane on dev; team familiarity; cheapest egress for us.  |
| Secondary cloud (DR + bonus)                | Azure             | Self-managed colo / multi-region GCP | Real multi-cloud demonstrates vendor-independence; AKS spot is cheap.   |
| Primary graph store                         | Neo4j             | Postgres + recursive CTEs | 3-hop traversal performance gap is orders of magnitude.                   |
| Event bus                                   | Apache Kafka      | RabbitMQ / Pub/Sub        | Persistent log + replay required for audit / forensics.                   |
| Cache                                       | Redis             | Memcached / in-JVM Caffeine| Need cross-pod TTL semantics for QR tokens.                              |
| Log store                                   | Grafana Loki      | ELK stack                 | Single binary, label-indexed, cheaper object storage. See [`OBSERVABILITY.md`](OBSERVABILITY.md) §6. |
| Tracing                                     | Jaeger (OTLP)     | Zipkin / Tempo            | Native OTLP + UI maturity.                                                |
| Service mesh                                | Istio             | Linkerd / Consul          | Richest AuthZ policy model; required for the mesh bonus.                  |
| IaC                                         | Terraform         | Pulumi / Crossplane       | Most widely understood + the rubric explicitly calls for it.              |
| CI/CD                                       | GitLab CI         | Jenkins (legacy) / GitHub Actions | Native MR + environments + protected variables.                  |

---

## 9. What this architecture deliberately is *not*

- **Not serverless.** The latency floor for cold starts (>1 s) would
  blow the QR-validation SLO. We accept the cost of always-on pods.
- **Not active/active multi-cloud.** Async replication is RPO ≤ 5 min;
  we explicitly trade RPO for cost and operational simplicity.
- **Not a single monolith with one DB.** Database-per-service is a
  precondition for the privacy story — `identity-service`'s vault
  cannot be browsable by any other deployment.
- **Not "Kubernetes-native at the app layer".** Services know nothing
  about Kubernetes (no `KubernetesClient` calls); they consume config
  via Spring's standard mechanisms and could in principle run on plain
  VMs. This keeps local dev possible (`docker-compose.dev.yml`).
