# CircleGuard Monorepo

**Absolute Privacy. High-Speed Containment. Secure Campus.**

CircleGuard is a state-of-the-art university contact tracing and fencing
system designed to identify interconnected contact groups ("Circles") and
apply rapid health fences while preserving individual anonymity.

> **For graders:** start at [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md)
> for the rubric coverage table and reading order. Architecture diagrams
> live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The demo video
> script (recording pending) is at [`VIDEO_SCRIPT_FINAL.md`](VIDEO_SCRIPT_FINAL.md).

---

## Vision & Mission

Our vision is a university campus where health-containment speed outpaces
lab-confirmation timelines without compromising student privacy.
CircleGuard leverages campus-native intelligence — class schedules and
WiFi infrastructure — to deliver a human-validated, graph-based
protection ecosystem.

### Key Differentiators

- **Privacy-as-Code** — zero real-name exposure outside a secure Health
  Center vault.
- **Recursive Containment** — status promotion cascades
  (Suspect → Probable → Confirmed) that trigger in milliseconds.
- **Campus Integration** — smart check-ins using existing WiFi AP
  triangulation and Bluetooth Low Energy (BLE).

---

## Success Metrics

| Metric                    | Target            | Measurement                                            |
|---------------------------|-------------------|--------------------------------------------------------|
| **Containment Speed**     | < 60 seconds      | Automated test of promotion-engine cascade             |
| **Privacy Compliance**    | 100 % anonymity   | Penetration test on graph DB (zero real names)         |
| **Check-in Adoption**     | > 70 %            | Analytics on scheduled-class contact validation        |
| **False Positive Rate**   | < 15 %            | Post-fence surveys of actual vs. suspected contact     |
| **System Uptime**         | 99.5 %            | 07:00–22:00 (academic peak hours)                      |

---

## Project Status (Final)

Compact rubric mapping. The full version (with status legend and self-scored
grade) lives in [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md).

| Req | Title                              | Weight | Status | Primary evidence                                                                   |
|-----|------------------------------------|-------:|--------|------------------------------------------------------------------------------------|
| 1   | Agile + branching                  | 10 %   | ✅     | [`docs/AGILE_METHODOLOGY.md`](docs/AGILE_METHODOLOGY.md), [`docs/BRANCHING.md`](docs/BRANCHING.md), [`docs/SPRINTS.md`](docs/SPRINTS.md) |
| 2   | Terraform IaC                      | 20 %   | ✅     | [`infra/terraform/`](infra/terraform/) (8 modules, 3 envs, GCS remote state)        |
| 3   | Design patterns                    | 10 %   | ✅     | [`docs/PATTERNS.md`](docs/PATTERNS.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §3 |
| 4   | CI/CD advanced                     | 15 %   | ✅     | [`.gitlab-ci.yml`](.gitlab-ci.yml), [`.gitlab/ci/`](.gitlab/ci/), [`docs/CI_CD.md`](docs/CI_CD.md) |
| 5   | Tests                              | 15 %   | ⚙️     | Unit (per service), `tests/integration/`, `tests/e2e/`, `tests/performance/`        |
| 6   | Change Management                  | 5 %    | ✅     | [`docs/CHANGE_MANAGEMENT.md`](docs/CHANGE_MANAGEMENT.md)                            |
| 7   | Observability                      | 10 %   | ✅     | [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md), [`infra/k8s/observability/`](infra/k8s/observability/), [`docs/runbooks/`](docs/runbooks/) |
| 8   | Security                           | 5 %    | ✅     | [`docs/SECURITY.md`](docs/SECURITY.md)                                              |
| 9   | Docs + video + presentation        | 10 %   | ⚙️     | This `README.md`, [`docs/`](docs/), [`VIDEO_SCRIPT_FINAL.md`](VIDEO_SCRIPT_FINAL.md) (video pending) |
| B1  | Multi-cloud (bonus)                | 5 %    | ⚙️     | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §5, `infra/terraform/modules/azure-*`|
| B2  | Service Mesh (bonus)               | 5 %    | ✅     | [`infra/k8s/istio/`](infra/k8s/istio/)                                              |
| B3  | Chaos Engineering (bonus)          | 5 %    | ✅     | [`docs/CHAOS_EXPERIMENTS.md`](docs/CHAOS_EXPERIMENTS.md), [`infra/k8s/chaos-mesh/`](infra/k8s/chaos-mesh/) |
| B4  | FinOps (bonus)                     | 5 %    | ✅     | [`docs/COSTS.md`](docs/COSTS.md), [`infra/k8s/finops/`](infra/k8s/finops/)          |

Legend: ✅ complete · ⚙️ mostly complete (documented gap) · 🟡 in progress · ❌ not done.

---

## Repository Map

```
.
├── .gitlab/                 GitLab CI templates, issue & MR templates
├── .gitlab-ci.yml           Parent pipeline (stages, includes, workflow rules)
├── docs/                    All documentation (see Doc Index below)
├── infra/
│   ├── terraform/           IaC: modules/, envs/{dev,stage,prod}/, backend/
│   └── k8s/                 Cluster add-ons: observability/, istio/, chaos-mesh/, finops/
├── k8s/                     Per-env app manifests (dev/, stage/, master/)
├── services/                8 Spring Boot 3 microservices (Java 21)
│   ├── circleguard-auth-service
│   ├── circleguard-identity-service
│   ├── circleguard-form-service
│   ├── circleguard-promotion-service
│   ├── circleguard-notification-service
│   ├── circleguard-gateway-service
│   ├── circleguard-dashboard-service
│   └── circleguard-file-service
├── mobile/                  Expo (React Native) — iOS / Android / Web from one codebase
├── tests/                   integration/, e2e/, performance/ (Locust)
├── scripts/                 Pipeline helpers, smoke tests, release-notes generator
├── jenkins/                 Legacy local-Jenkins setup (kept for reference)
├── Jenkinsfile.{dev,stage,master}   Legacy Jenkins pipelines (kept as reference)
├── docker-compose.{dev,}.yml        Local middleware + service composition
└── REPORTE_TALLER_2.{md,pdf}        Previous report (Taller 2 era)
```

### Documentation index

| File                                                          | Purpose                                            |
|---------------------------------------------------------------|----------------------------------------------------|
| [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md)    | **Start here.** Rubric coverage + reading order.    |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)                | C4 Context / Container / Component + data + topology |
| [`docs/OPERATIONS.md`](docs/OPERATIONS.md)                    | Cold start, day-2 ops, incident response, DR        |
| [`docs/SECURITY.md`](docs/SECURITY.md)                        | Vulnerability scans, secrets, RBAC, TLS, FERPA      |
| [`docs/AGILE_METHODOLOGY.md`](docs/AGILE_METHODOLOGY.md)      | Scrum framework, roles, DoR, DoD                    |
| [`docs/BRANCHING.md`](docs/BRANCHING.md)                      | GitFlow specification + gitGraph                    |
| [`docs/SPRINTS.md`](docs/SPRINTS.md)                          | Sprint backlog and ceremonies                       |
| [`docs/USER_STORIES.md`](docs/USER_STORIES.md)                | Connextra-format stories with AC                    |
| [`docs/CHANGE_MANAGEMENT.md`](docs/CHANGE_MANAGEMENT.md)      | Change types, CAB, rollback, release notes          |
| [`docs/CI_CD.md`](docs/CI_CD.md)                              | GitLab CI pipeline reference                        |
| [`docs/PATTERNS.md`](docs/PATTERNS.md)                        | Design patterns in the codebase                     |
| [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md)              | Metrics, logs, traces, alerts, dashboards           |
| [`docs/CHAOS_EXPERIMENTS.md`](docs/CHAOS_EXPERIMENTS.md)      | Chaos Mesh experiment runbook                       |
| [`docs/COSTS.md`](docs/COSTS.md)                              | FinOps forecast, billing export, scale-to-zero      |
| [`docs/runbooks/`](docs/runbooks/)                            | Incident playbooks (gateway SLO, Kafka lag, crashloop) |
| [`VIDEO_SCRIPT_FINAL.md`](VIDEO_SCRIPT_FINAL.md)              | 20–30 min demo video script                          |
| [`VIDEO_SCRIPT.md`](VIDEO_SCRIPT.md)                          | (Reference) Taller 2 8-min script                    |

---

## Architecture (one-paragraph version)

CircleGuard is a microservice architecture on a hybrid data model. The
**status engine** (`promotion-service`) uses **Neo4j** for recursive
graph traversals to identify contacts within a 14-day temporal window.
A segregated **PostgreSQL vault** (`identity-service`) handles
salted-hash identity mapping (FERPA-compliant) — every other service
sees only opaque anon UUIDs. **Apache Kafka** carries asynchronous
status changes, audit events, and notification dispatches. **Redis** is
the L2 cache for QR-token validation at campus gates. Eight Spring
Boot 3 / Java 21 services run on GKE (primary) with AKS as a warm
standby for DR. Diagrams in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Technology Stack

| Layer            | Technology              | Rationale                                                |
|------------------|-------------------------|----------------------------------------------------------|
| Backend          | Spring Boot 3 / Java 21 | Enterprise maturity, low-latency Jakarta EE              |
| Graph DB         | Neo4j 5.26              | Recursive traversals unreachable with SQL                |
| Relational DB    | PostgreSQL 16           | ACID storage for identity + per-service config            |
| Message Bus      | Apache Kafka 7.6        | Persistent, audit-trailed event log                       |
| Cache            | Redis 7.2               | Sub-ms gate validation, session L2                        |
| Mobile / Web     | Expo (React Native)     | iOS, Android, browser from one codebase                   |
| Orchestration    | Kubernetes (GKE + AKS)  | Multi-cloud, HA, auto-scaling                             |
| Service Mesh     | Istio                   | mTLS, AuthZ policies, canary, traffic management          |
| IaC              | Terraform 1.7           | Multi-cloud, remote state in GCS                          |
| CI/CD            | GitLab CI               | Native MR + environments + protected variables            |
| Observability    | Prometheus / Loki / Jaeger / Grafana | CNCF reference stack                         |
| Chaos            | Chaos Mesh              | Native K8s CRDs, scoped to dev namespace                  |
| Container build  | Kaniko                  | Rootless, no DinD                                         |

---

## Running it

- **Local dev** (laptop, Docker Desktop): see
  [`docs/OPERATIONS.md`](docs/OPERATIONS.md) §1 (prerequisites) and
  the historic local-dev section in
  [`REPORTE_TALLER_2.md`](REPORTE_TALLER_2.md) §1.
- **Cluster (dev / stage / prod)**: full cold-start sequence in
  [`docs/OPERATIONS.md`](docs/OPERATIONS.md) §2.
- **Day-2 operations** (deploy, scale, rotate, rollback):
  [`docs/OPERATIONS.md`](docs/OPERATIONS.md) §3.
- **Incident response**: [`docs/runbooks/`](docs/runbooks/) +
  [`docs/OPERATIONS.md`](docs/OPERATIONS.md) §4.

---

## Live URLs

> Placeholders below — replaced once the GitLab project is published and
> the video is recorded. Single source of truth lives in
> [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md) §4.

| What                       | URL                                                                  |
|----------------------------|----------------------------------------------------------------------|
| GitLab project             | `https://gitlab.com/<group>/circle-guard-public` *(placeholder)*    |
| GitLab Issue Board         | `https://gitlab.com/<group>/circle-guard-public/-/boards`           |
| GitLab Milestones          | `https://gitlab.com/<group>/circle-guard-public/-/milestones`       |
| GitLab Pipelines           | `https://gitlab.com/<group>/circle-guard-public/-/pipelines`        |
| Demo video                 | `https://youtu.be/<id>` *(placeholder — record per VIDEO_SCRIPT_FINAL.md)* |
| Presentation slides        | `https://docs.google.com/presentation/d/<id>` *(placeholder)*       |
| Grafana (prod, SSO)        | `https://grafana.circleguard.edu` *(placeholder)*                   |
| Kiali (prod, SSO)          | `https://kiali.circleguard.edu` *(placeholder)*                     |

---

## Roadmap

### Phase 1 — MVP: the intelligence core (current)
- [x] Status Promotion Machine (Suspect → Probable → Confirmed).
- [x] Temporal graph with 14-day TTL edges.
- [x] Multi-channel fence notifications (push / email / SMS).
- [ ] Health Center de-identification console.

### Phase 2 — Growth: spatial intelligence
- [ ] WiFi AP triangulation integration.
- [ ] Campus entry validation (Gatekeeper) QR integration.
- [ ] LMS integration for "Remote Attendance" status automation.

### Phase 3 — Vision: full ecosystem
- [ ] Off-campus circle detection via P2P Bluetooth.
- [ ] Global Health Dashboard with hotspot visualisation.
- [ ] Lab API bridge for automated test-result ingestion.

---

## Privacy & Compliance

- **FERPA mapping** — full requirement-to-evidence table in
  [`docs/SECURITY.md`](docs/SECURITY.md) §7.
- **Right to be Forgotten** — `POST /api/v1/identity/forget` triggers
  cascading delete across all services via the
  `identity.purge.requested` Kafka topic.
- **Temporal Privacy** — all contact edges TTL'd after 14 days.

---

## Authors & Acknowledgments

**Author:** Santiago Espinosa (`espinosacodes`) — IngeSoft V student,
Universidad Nacional / EAFIT (placeholder — replace with your
institution).

**Course:** IngeSoft V (Software Engineering V), 2026 semester.

**Acknowledgments:**

- Course staff for designing a final project that forces real
  trade-offs instead of just stacking technologies.
- The open-source maintainers behind Spring, Kubernetes, Istio,
  Prometheus, Loki, Jaeger, Chaos Mesh, cert-manager, Terraform, and
  GitLab — every YAML file here stands on their examples.
- The Taller 2 reviewers, whose feedback shaped the Sprint 1 backlog
  for this final delivery.

---

## License

This repository is provided for academic evaluation. Re-use of the code
or documentation outside the IngeSoft V course requires written
permission from the author.
