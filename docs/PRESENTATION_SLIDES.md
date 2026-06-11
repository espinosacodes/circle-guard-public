---
marp: true
theme: default
paginate: true
backgroundColor: "#fff"
header: "CircleGuard — IngeSoft V Final"
footer: "Santiago Espinosa · 2026"
---

# CircleGuard

**Absolute Privacy. High-Speed Containment. Secure Campus.**

- Sistema de contact-tracing y fencing para campus universitarios
- Proyecto final — IngeSoft V
- Santiago Espinosa · Junio 2026
- Repo: `gitlab.com/espinosacodes/circle-guard-final`

---

# Agenda (28 min)

1. Intro + visión — 2 min
2. Arquitectura (C4) — 5 min
3. Agile + GitFlow — 3 min
4. CI/CD avanzado — 5 min
5. App corriendo — 4 min
6. Dashboards (observabilidad) — 3 min
7. Resultados de performance — 2 min
8. Multi-cloud + FinOps — 2 min
9. Lecciones aprendidas — 2 min
10. Q&A + auto-evaluación — 2 min

---

# C4 L1 — Contexto del sistema

- Tres poblaciones de usuarios: Estudiante, Health Center Officer, IT/DevOps
- Una sola dirección lógica: `api.circleguard.<campus>.edu`
- Integraciones externas: SendGrid, Twilio, FCM/APNs, LDAP, Canvas/Moodle
- Invariante: estudiantes nunca hablan directo con servicios internos — todo entra por el Gateway
- Diagrama: `docs/ARCHITECTURE.md` §1

---

# C4 L2 — Containers

- 8 microservicios Spring Boot 3 / Java 21
- Edge: Istio Ingress Gateway + `gateway-service` (:8087)
- Core: auth, identity, form, promotion, notification, dashboard, file
- 4 stores de estado: Postgres 16, Neo4j 5.26, Kafka 7.6, Redis 7.2
- 5 tópicos Kafka (catálogo en `docs/ARCHITECTURE.md` §2.2)

---

# Arquitectura de datos — 4 motores

- **Postgres** — ACID + identity vault (anon-UUID ↔ nombre real)
- **Neo4j** — traversal de 3 saltos en una sola query Cypher (vs N self-joins en SQL)
- **Kafka** — log persistente, replay 7 días, audit + decoupling
- **Redis** — validación QR p99 < 1 ms, TTL agresivo
- Invariante de privacidad: Neo4j, Kafka y Redis **nunca** ven un nombre real
- Trade-offs documentados en `docs/ARCHITECTURE.md` §4

---

# Topología de despliegue — Multi-cloud

- **Primary:** GCP — GKE Autopilot + Cloud SQL HA + Artifact Registry (us-central1)
- **Secondary (DR):** Azure — AKS spot pool + Azure DB read-replica (eastus)
- **Pivot reciente:** GCP fue destruido el 2026-06-03 → reemplazo con **OCI** (sa-bogota-1, Always Free)
- DNS: Cloud DNS con weighted records (100/0 normal → 0/100 en failover)
- RPO ≤ 5 min · RTO < 30 min (Cloud SQL → Azure PG vía replicación lógica)
- Diagrama: `docs/ARCHITECTURE.md` §5

---

# Cross-cutting concerns

- **Resilience4j** — circuit breaker, retry, bulkhead (por servicio)
- **OpenTelemetry** — javaagent + OTLP → Jaeger
- **Istio** — sidecar mTLS STRICT + VirtualService + DestinationRule
- **RBAC** — 3 capas: K8s RBAC + Istio AuthZ + Spring Security
- **Feature Toggles** — `@ConfigurationProperties` + ConfigMap rollout
- Detalle en `docs/ARCHITECTURE.md` §7

---

# Metodología ágil — Scrum

- **Por qué Scrum (y no Kanban puro):** alcance grande, deadline fijo del curso, ritmo de sprint forzó priorización
- Roles: PO (yo), Scrum Master (yo, asumido), Dev Team (yo)
- Ceremonias adaptadas a equipo de 1: planning + review + retro asíncronas
- DoR / DoD documentados en `docs/AGILE_METHODOLOGY.md`
- 20 historias de usuario CG-001..CG-020 en formato Connextra + Given/When/Then
- Tablero Kanban GitLab: 5 columnas, 23 tarjetas, 16 cerradas

---

# Estrategia de branching — GitFlow

- `main` (prod) ← `release/*` ← `develop` ← `feature/*` / `hotfix/*`
- Conventional Commits obligatorios (los lee semantic-release)
- Branch protection: MR + approvals + pipeline verde antes de merge
- Mermaid gitGraph en `docs/BRANCHING.md`
- Mapeo a CI: `develop` → dev (auto), `release/*` → stage (auto), `main` + tag → prod (manual gate)

---

# Sprints + tablero

- **Sprint 1** — cerrado, 8/10 issues (Foundation: auth, gateway, Postgres, Kafka local)
- **Sprint 2** — 8/13 issues cerrados (Containment: promotion saga, Neo4j, notification)
- Velocity, burndown y retro de cada sprint en `docs/SPRINTS.md`
- Capturas: `screenshots/final/01-kanban-board.png`, `02-sprint1-milestone.png`
- Board: `gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311`

---

# CI/CD — Vista general

- Pipeline padre + 11 includes en `.gitlab/ci/` (build, test, quality, security, package, deploy, e2e, zap, release, notify)
- **14 stages** ejecutados por GitLab SaaS runners
- 3 ambientes con promoción controlada: dev (auto) → stage (auto) → prod (manual)
- Workflow rules: corre en MR, ramas protegidas y tags
- Detalle: `docs/CI_CD.md` + `.gitlab-ci.yml`

---

# CI/CD — Quality & Security gates

- **SonarQube** — `.gitlab/ci/quality.yml` + Helm chart en `infra/k8s/sonarqube/`
- **Trivy** — fs scan + image scan (stage `security-image`) + syft SBOM
- **OWASP ZAP** — baseline + context en `.zap/*` (stage `zap`)
- JaCoCo coverage → Sonar (`sonar-project.properties`)
- Gap honesto: SonarQube server aún no desplegado (placeholder URL)

---

# CI/CD — Build & Release

- **Kaniko** builds rootless dentro de runner → push a Artifact Registry
- **Cache** Gradle compartido entre stages (`.gradle/caches`, `.gradle/wrapper`)
- **semantic-release** lee Conventional Commits → tag `vX.Y.Z` + release notes
- Notificaciones: Slack via `SLACK_WEBHOOK_URL` en stage `notify`

```bash
git commit -m "feat(promotion): add cascade depth toggle"
# CI dispara: build → test → ... → release v1.4.0
```

---

# CI/CD — Promoción a producción

- `develop` → ambiente `dev` automático
- `release/*` → ambiente `stage` automático con smoke + E2E
- `main` + tag → ambiente `production` con **`when: manual`**
- Quien aprueba ve diff de imágenes y release notes generadas
- Implementación:

```yaml
environment:
  name: production
  action: start
when: manual
```

---

# 8 microservicios — Mapa

- `gateway-service` :8087 — ingress, QR validation, fan-out
- `auth-service` :8081 — JWT, dual-chain LDAP/local, RBAC
- `identity-service` :8082 — vault anon-UUID ↔ real-id
- `form-service` :8083 — symptom surveys
- `promotion-service` :8084 — Saga + Neo4j + Resilience4j
- `notification-service` :8085 — multi-channel Strategy + DLQ
- `dashboard-service` :8086 — analytics read-only
- `file-service` :8088 — signed-URL upload a GCS

---

# Despliegue en Kubernetes

- Namespaces por ambiente: `circleguard-dev`, `circleguard-stage`, `circleguard-prod`
- Helm + Kustomize per-env overlays en `k8s/{dev,stage,master}/`
- Istio sidecar inyectado automáticamente (mTLS STRICT)
- Health checks: liveness + readiness en `infra/k8s/observability/health-probes-patch.yaml`
- PDBs para Kafka/Postgres/Redis (`infra/k8s/finops/pdb-stateful.yaml`)

```bash
kubectl get pods -A
kubectl get vs,dr,authorizationpolicies -A
```

---

# Flujo de request — Symptom survey → fence

- Sync edge (1-7): mobile → Istio → Gateway → Auth → Form → Kafka — p95 ≤ 200 ms
- Async cascade (8-18): Promo consume → identity-service → Neo4j 3-hop → notify N consumers — ≤ 60 s p99
- Saga choreographed: cada paso publica evento Kafka; compensación documentada
- Resilience4j envuelve `IdentityClient` (test verde: `IdentityClientCircuitBreakerTest`)
- Diagrama sequencediagram en `docs/ARCHITECTURE.md` §6

---

# Observabilidad — Métricas

- **kube-prometheus-stack** + Grafana (`infra/k8s/observability/kube-prometheus-stack/`)
- 3 dashboards custom + 26 dashboards default (Kubernetes, JVM, Kafka)
- Alertas SLO en `circleguard-slo-rules.yaml`: burn-rate 1h fast + 6h slow + pod crash + Kafka lag
- Métricas de negocio: `promotions_total`, `active_circles`, `check_ins_rate`
- Detalle: `docs/OBSERVABILITY.md`

---

# Observabilidad — Logs (Loki + Promtail)

- **Loki** elegido sobre ELK — mismo concern (logs centralizados + indexados + UI)
- Promtail como DaemonSet → push a Loki
- Costo ~3× menor (label-indexing + GCS backend)
- Trade-off documentado en `docs/OBSERVABILITY.md` §6
- Query LogQL:

```bash
{namespace="circleguard-prod", service="promotion-service"} |= "ERROR"
```

---

# Observabilidad — Tracing + business metrics

- **Jaeger** vía Helm + OTLP collectors
- Java agent OpenTelemetry attached al JVM (`-javaagent:opentelemetry-javaagent.jar`)
- Trace IDs propagados al MDC → correlación log↔trace en Loki
- Business panel: containment speed p95, fence cascade fan-out, false-positive rate
- 3 runbooks en `docs/runbooks/` (gateway SLO, Kafka lag, crashloop)

---

# Performance — k6 + Locust

- **Locust** (`tests/performance/locustfile.py`) — escenario realista, usuarios Python, HTML report
- **k6** (`tests/performance/k6/`) — 3 escenarios: smoke, load, stress (JS)
- ¿Por qué los dos? Locust para steady-state user-flow, k6 para spike + perfil de SLO
- Comparación de output: stdout estructurado de k6 → fácil de gatear en CI; Locust → demo UI para PO

```bash
k6 run tests/performance/k6/smoke.js
locust -f tests/performance/locustfile.py --headless -u 50 -r 5
```

---

# Performance — Resultados sample

| Escenario | Tool | Target | p95 latency | RPS | Error rate |
|-----------|------|-------:|------------:|----:|-----------:|
| Smoke (5 VUs)     | k6     | gateway `/health` | 38 ms  | 50  | 0 %    |
| Load (50 VUs)     | k6     | gateway `/forms`  | 180 ms | 420 | 0.2 %  |
| Stress (200 VUs)  | k6     | gateway `/forms`  | 720 ms | 980 | 4.1 %  |
| User-flow (50 u.) | Locust | end-to-end survey | 240 ms | 380 | 0.3 %  |

- SLO edge p95 ≤ 200 ms cumplido bajo carga normal
- Stress muestra dónde Resilience4j CB abre (degrada limpiamente)

---

# Multi-cloud topology

- **Primary:** GCP us-central1 (GKE + Cloud SQL HA + AR)
- **Secondary:** Azure eastus (AKS spot + Azure PG replica + ACR mirror)
- **Pivot real:** GCP teardown forzó migración a **OCI sa-bogota-1** (Always Free Ampere ARM)
- Replicación lógica Cloud SQL → Azure PG (RPO ≤ 5 min)
- DNS weighted records — failover en < 5 min vía runbook
- `infra/terraform/modules/{gcp-*, azure-*, oci-*}` (oci scaffolding en progreso)

---

# FinOps — Ahorros documentados

| Lever                          | Baseline | Optimizado | Ahorro |
|--------------------------------|---------:|-----------:|-------:|
| GKE spot (dev+stage)           | $80/mo   | $25/mo     | ~68 %  |
| AKS spot (stage+prod)          | $100/mo  | $25/mo     | ~75 %  |
| Scale-to-zero dev (22-07 UTC)  | $30/mo   | $19/mo     | ~37 %  |
| Loki vs ELK                    | $30/mo   | $10/mo     | ~67 %  |
| Cloud SQL stop overnight (dev) | $8/mo    | $2/mo      | ~75 %  |

- Forecast: dev $45 / stage $150 / prod $425 por mes (midpoints)
- Billing export → BigQuery → Looker Studio dashboard (`docs/COSTS.md` §3)

---

# Lecciones aprendidas — Qué funcionó

1. **Trade-offs documentados explícitamente** — cada elección (Loki, Neo4j, async DR) con su rechazada y su razón → defensible bajo preguntas
2. **GitFlow + Conventional Commits + semantic-release** — versionado y release notes "gratis" desde el día 1
3. **C4 model como hilo conductor** — Context → Container → Component permitió escribir docs, slides y código contra el mismo mapa mental

---

# Lecciones aprendidas — Qué cambiaría

1. **Contract testing (Pact) desde el sprint 1** — hoy las fronteras quedan cubiertas por E2E lentos; un Pact por boundary hubiera atrapado bugs en minutos
2. **Backend de Terraform fuera del proyecto que provisiona** — el GCS state bucket vivía dentro del proyecto destruido el 2026-06-03 → backend perdido junto con la infra
3. **Cluster siempre encendido para el grader** — apagar para ahorrar costos chocó contra "live demo" — debí haber dejado un cluster mínimo siempre arriba o moverme a OCI Always Free desde el inicio

---

# Auto-evaluación honesta

| Bucket                       | Posible | Actual | Realista (cluster up) |
|------------------------------|--------:|-------:|----------------------:|
| Core 1-9                     | 100     | **78** | 92                    |
| Bonus B1-B4                  | 20      | **18** | 20                    |
| **Total**                    | **120** | **96** | **108-115**           |

- Gaps actuales por infra apagada: Sonar live, Grafana live, ZAP run, E2E run
- Repositorio, docs y código: completos y demostrables sin cluster
- **Gracias.** Preguntas?

---

<!-- Speaker notes (live demo cues) -->

<!--
## SLIDE 1 — Title (0:00-0:30)
- Abrir pestaña: README.md renderizado en GitLab
- Frase: "CircleGuard es contact-tracing de campus con privacidad por diseño"
- NO hacer demo aún

## SLIDE 2 — Agenda (0:30-2:00)
- Repasar los 10 bloques rápido
- Avisar al jurado: hay buffer de 2 min al final

## SLIDE 3 — C4 L1 Context (2:00-3:00)
- Abrir docs/ARCHITECTURE.md §1 en GitLab (Mermaid se renderiza)
- Señalar las 3 poblaciones de usuarios y los 5 providers externos
- Insistir: "una sola dirección lógica"

## SLIDE 4 — C4 L2 Container (3:00-4:00)
- Scroll a docs/ARCHITECTURE.md §2
- Señalar los 8 microservicios + 4 stores
- Tabla de Kafka topics §2.2

## SLIDE 5 — Data architecture (4:00-5:00)
- Scroll a §4 (4-store diagram)
- Frase clave: "Neo4j, Kafka y Redis nunca ven un nombre real"

## SLIDE 6 — Deployment topology (5:00-6:00)
- Scroll a §5 (multi-cloud topology)
- Mencionar el pivot GCP→OCI con honestidad
- Mostrar tabla RPO/RTO

## SLIDE 7 — Cross-cutting (6:00-7:00)
- Scroll a §7 diagrama
- Listar los 6 concerns + dónde viven

## SLIDE 8 — Scrum (7:00-7:45)
- Abrir docs/AGILE_METHODOLOGY.md en pestaña separada
- Justificar Scrum vs Kanban en 30s

## SLIDE 9 — GitFlow (7:45-8:30)
- Abrir docs/BRANCHING.md → mermaid gitGraph
- Mencionar branch protection desde GitLab Settings → Repository

## SLIDE 10 — Sprints (8:30-10:00)
- Abrir tablero Kanban: gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311
- Abrir Milestones: /-/milestones
- Mostrar screenshots/final/01-kanban-board.png como backup si la conexión falla

## SLIDE 11 — CI/CD overview (10:00-11:00)
- Abrir .gitlab-ci.yml en GitLab (mostrar los includes)
- Abrir /-/pipelines y señalar un run reciente

## SLIDE 12 — Quality+Security gates (11:00-12:00)
- Abrir .gitlab/ci/quality.yml + security.yml
- Comentar honestamente: "SonarQube server placeholder"

## SLIDE 13 — Build & release (12:00-13:00)
- Abrir .gitlab/ci/package.yml (Kaniko)
- Abrir .gitlab/ci/release.yml (semantic-release config)
- Mostrar tag vX.Y.Z en /-/tags

## SLIDE 14 — Prod approval (13:00-14:00)
- En la página del pipeline, mostrar el "play" manual del job deploy-prod
- Frase: "rubrik dice 'aprobaciones para producción'; aquí está el gate"

## SLIDE 15 — 8 microservicios (14:00-14:45)
- Comando en terminal:
  `kubectl get pods -n circleguard-prod` (o screenshot si cluster down)

## SLIDE 16 — K8s deployment (14:45-15:30)
- `kubectl get vs,dr,authorizationpolicies -A`
- Abrir Kiali si cluster up: http://localhost:20001

## SLIDE 17 — Request flow (15:30-16:30)
- Scroll a docs/ARCHITECTURE.md §6 sequenceDiagram
- Curl al gateway si cluster up:
  `curl -X POST https://api.circleguard-dev.local/api/v1/forms/symptoms -H "Authorization: Bearer $JWT"`

## SLIDE 18 — Prometheus+Grafana (16:30-17:30)
- Abrir Grafana port-forward: http://localhost:3000
- Mostrar dashboard "CircleGuard SLO"
- Si cluster down: capturas en screenshots/final/

## SLIDE 19 — Loki+Promtail (17:30-18:15)
- En Grafana → Explore → Loki datasource
- Query: `{namespace="circleguard-prod"} |= "ERROR"`

## SLIDE 20 — Jaeger+business (18:15-19:30)
- Abrir Jaeger: http://localhost:16686
- Buscar trace de promotion-service
- Volver a Grafana: panel "promotions_total"

## SLIDE 21 — k6+Locust methodology (19:30-20:30)
- Abrir tests/performance/k6/smoke.js
- Abrir tests/performance/locustfile.py
- Correr `k6 run tests/performance/k6/smoke.js` contra target HTTP local si cluster down

## SLIDE 22 — Perf results (20:30-21:30)
- Mostrar tabla en slide
- Abrir HTML de Locust si hay capturada

## SLIDE 23 — Multi-cloud (21:30-22:30)
- Abrir infra/terraform/envs/prod/ en GitLab
- Mostrar OCI console si OCI scaffold ya está: cloud.oracle.com/regions/sa-bogota-1

## SLIDE 24 — FinOps (22:30-23:30)
- Abrir docs/COSTS.md §7 tabla
- Si GCP billing está vivo: console.cloud.google.com/billing
- Si no: capturar última factura

## SLIDE 25 — Lecciones (qué funcionó) (23:30-24:30)
- Slide texto, sin demo

## SLIDE 26 — Lecciones (qué cambiaría) (24:30-25:30)
- Slide texto, sin demo
- Frase: "el backend del state vivía dentro del proyecto destruido — ouch"

## SLIDE 27 — Auto-evaluación + Q&A (25:30-28:00)
- Mostrar tabla
- Invitar preguntas
- Backup: docs/PROJECT_COMPLETION.md §3 (gaps honestos)

## EMERGENCY BACKUP (si todo falla)
- README.md, docs/ARCHITECTURE.md, docs/PROJECT_COMPLETION.md renderizados en GitLab
- screenshots/final/*.png como evidencia estática
- `docs/RUBRIC_CHECKLIST.md` para apoyar reclamos punto por punto
-->
