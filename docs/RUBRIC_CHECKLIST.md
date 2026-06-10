# CircleGuard — Rubric Checklist (Live)

**Course:** IngeSoft V Final Project · **Repo:** https://gitlab.com/espinosacodes/circle-guard-final
**Last updated:** 2026-06-03 · **Format:** live presentation (NOT video)
**Self-scored cap:** 110 / 120 (92 core + 18 bonus)

Legend: ✅ done · 🟡 partial / evidence captured before infra teardown · ⏳ in progress · ❌ not started · 📸 needs screenshot

---

## 1. Metodología Ágil y Estrategia de Branching (10%)  —  ✅ 10/10

- [x] Metodología ágil documentada — Scrum chosen, ceremonies/roles in `docs/AGILE_METHODOLOGY.md`
- [x] Estrategia de branching documentada — GitFlow with Mermaid gitGraph in `docs/BRANCHING.md`
- [x] Sistema de gestión ágil — GitLab Kanban [board](https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311) with 5 columns, 23 cards, 16 closed
- [x] Sprints documentados — `docs/SPRINTS.md` (2 sprints, retro+review per sprint)
- [x] Historias de usuario + criterios de aceptación — 20 stories CG-001..CG-020 in `docs/USER_STORIES.md` (Connextra + Given/When/Then)
- [x] ≥ 2 iteraciones completas — Sprint 1 closed (8/10 issues), Sprint 2 mostly closed (8/13)

**Evidence to capture for presentation:** kanban screenshot ✅ done (`screenshots/final/01-kanban-board.png`), sprint 1 burndown ✅ done (`02-sprint1-milestone.png`)

---

## 2. Infraestructura como Código con Terraform (20%)  —  🟡 17/20

- [x] Toda la infra en Terraform — `infra/terraform/` (8 modules + 3 envs + backend)
- [x] Estructura modular — `modules/{gcp-network,gcp-gke,gcp-cloudsql,gcp-artifact-registry,gcp-iam,azure-network,azure-aks,azure-acr}`
- [x] Multi-ambiente — `envs/{dev,stage,prod}/` with non-overlapping CIDRs
- [x] Diagrama arquitectura infra — `docs/ARCHITECTURE.md` §5 deployment topology (Mermaid)
- [x] Backend remoto Terraform — was on GCS (`gs://circleguard-final-92308-tfstate`); **GCP teardown on 2026-06-03 destroyed bucket too**
- [ ] 📸 `terraform plan` zero-drift screenshot — taken before teardown; otherwise re-run after teammate reprovisions

**Gap (-3 pts):** Live `terraform apply` requires teammate's new GCP project OR my new OCI scaffold. Backend bucket recreate needed.

**What's left:**
- [ ] Add `infra/terraform/modules/oci-{network,oke,ocir}/` for the multi-cloud bonus path (reuses same modular pattern)
- [ ] Re-create remote backend (GCS on teammate's project, OR an OCI Object Storage bucket)

---

## 3. Patrones de Diseño (10%)  —  ✅ 10/10

- [x] Patrones existentes identificados — 8 listed in `docs/PATTERNS.md` §1 (API Gateway, DB-per-Service, Event-Driven, Repository, Strategy, Filter Chain, Anti-Corruption, choreographed Saga)
- [x] Patrón de resiliencia — **Resilience4j Circuit Breaker** wraps `IdentityClient` in auth-service (`services/circleguard-auth-service/src/main/java/com/circleguard/auth/client/IdentityClient.java`)
  - Test: `IdentityClientCircuitBreakerTest` — passes locally
  - Mesh-level: Istio DestinationRule on identity-service (`infra/k8s/istio/circuit-breaker-destination-rule.yaml`)
- [x] Patrón de configuración — **Feature Toggle** in dashboard-service (`@ConfigurationProperties("features")` + `FeatureGatedController` + K8s ConfigMap override per env)
  - Test: `FeatureToggleIT` — passes locally (after JdbcTemplate mock fix)
- [x] Documentación de patrones — `docs/PATTERNS.md` (4 sections, trade-offs, Mermaid diagram)

**Evidence to demo live:** `./gradlew :services:circleguard-auth-service:test` showing CB test green; show `docs/PATTERNS.md` rendered in GitLab

---

## 4. CI/CD Avanzado (15%)  —  🟡 12/15

- [x] Pipeline completo en GitLab CI — `.gitlab-ci.yml` parent + 11 includes in `.gitlab/ci/`
- [x] Ambientes separados con promoción controlada — develop→dev (auto), release/*→stage (auto), main+tag→prod (manual gate)
- [x] SonarQube integrado en pipeline — `.gitlab/ci/quality.yml` + Helm chart in `infra/k8s/sonarqube/`
  - **Gap:** Live SonarQube server not deployed; `SONAR_HOST_URL` is a placeholder
- [x] Trivy escaneo de contenedores — `.gitlab/ci/security.yml` with fs scan + image scan in `security-image` stage
- [x] Versionado semántico automático — semantic-release in `.gitlab/ci/release.yml` reads Conventional Commits
- [x] Notificaciones para fallos — Slack via `SLACK_WEBHOOK_URL` (placeholder set; needs real webhook for live)
- [x] Aprobaciones para producción — `environment: production` with `action: start` + `when: manual`
- [x] Pipeline runs visible — multiple green/red pipelines at https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines

**Gap (-3 pts):** SonarQube + Slack webhook are configured but not running against real backends. Pipeline structure is complete; runtime needs ~30min of post-cluster setup.

**What's left:**
- [ ] 📸 Pipeline-green screenshot (run pipeline once build/test green on stable infra)
- [ ] Either deploy SonarQube (Helm) or document it as "deferred to operations setup"

---

## 5. Pruebas Completas (15%)  —  🟡 11/15

- [x] Pruebas unitarias — Java/JUnit5 in every `services/*/src/test/java/`. Coverage report via JaCoCo
- [x] Pruebas de integración — `tests/integration/`, plus per-service IT (FeatureToggleIT, HealthCenterPromotionIT)
- [x] Pruebas E2E — `tests/e2e/test_promote_to_confirmed.py` (3 tests against staging URL)
- [x] Pruebas de rendimiento — **Locust** in `tests/performance/locustfile.py` + **k6** in `tests/performance/k6/` (3 scenarios)
- [x] Pruebas de seguridad — OWASP ZAP configured in `.gitlab/ci/zap.yml` + `.zap/{baseline.conf,context.xml,rules.tsv}`
- [x] Cobertura — JaCoCo + Sonar wiring in `sonar-project.properties`
- [x] Ejecución automatizada — all wired into GitLab pipeline stages

**Gap (-4 pts):** Performance/ZAP/E2E runs need live URLs (`CG_GATEWAY_URL` etc); no successful end-to-end run on GitLab yet.

**What's left:**
- [ ] 📸 Show `./gradlew test` BUILD SUCCESSFUL across all 8 services
- [ ] Run k6 smoke locally against any HTTP target to capture an output sample
- [ ] Document the test pyramid in `docs/PROJECT_COMPLETION.md` if missing

---

## 6. Change Management y Release Notes (5%)  —  ✅ 5/5

- [x] Proceso formal de Change Management — `docs/CHANGE_MANAGEMENT.md` (Standard / Normal / Emergency types + CAB Mermaid sequence)
- [x] Generación automática de Release Notes — `RELEASE_NOTES_v1.0.1778451707.md` + `RELEASE_NOTES_v1.0.1778728283.md` already in repo (Taller 2); semantic-release adds more
- [x] Planes de rollback — `docs/CHANGE_MANAGEMENT.md` §rollback (kubectl rollout undo + Flyway + Istio canary revert)
- [x] Etiquetado de releases — Conventional Commits + semantic-release tags `vX.Y.Z` per `docs/BRANCHING.md`

---

## 7. Observabilidad y Monitoreo (10%)  —  🟡 8/10

- [x] Prometheus + Grafana — `kube-prometheus-stack` Helm values in `infra/k8s/observability/kube-prometheus-stack/` (deployed before GCP teardown)
- [x] Log management — Loki + Promtail (chose over ELK; justification in `docs/OBSERVABILITY.md` §6 — same architectural concern: centralized + indexed + UI)
- [x] Dashboards por servicio — 3 Grafana JSONs in `infra/k8s/observability/grafana-dashboards/` + 26 default kps dashboards
- [x] Alertas críticas — `infra/k8s/observability/alerts/circleguard-slo-rules.yaml` (burn-rate 1h fast + 6h slow + pod crash + Kafka lag)
- [x] Tracing distribuido — Jaeger via Helm + OTLP collectors (deployed)
- [x] Health checks (liveness/readiness) — patch template in `infra/k8s/observability/health-probes-patch.yaml`
- [x] Métricas de negocio — documented in `docs/OBSERVABILITY.md` §business metrics (promotions_total, active_circles, check_ins_rate)

**Gap (-2 pts):** Live demo of Grafana + Jaeger requires re-deployed cluster.

**What's left:**
- [ ] 📸 Grafana dashboard screenshot — needs cluster up
- [ ] 📸 Jaeger trace screenshot — needs cluster up
- [ ] 📸 Alertmanager firing alert screenshot — needs cluster up

---

## 8. Seguridad (5%)  —  ✅ 5/5

- [x] Escaneo continuo de vulnerabilidades — Trivy fs + image + syft SBOM in `.gitlab/ci/security.yml`
- [x] Gestión segura de secretos — `docs/SECURITY.md` §secrets (GCP Secret Manager + Workload Identity, no plaintext in K8s manifests, CI vars masked+protected)
- [x] RBAC — `docs/SECURITY.md` §RBAC (K8s RBAC + Istio AuthorizationPolicies + Spring Security `@PreAuthorize` defense-in-depth)
- [x] TLS — cert-manager + Let's Encrypt cluster issuer + Istio mTLS STRICT (`infra/k8s/istio/peer-authentication-strict.yaml`)
- [x] Bonus: NetworkPolicies + audit logging + FERPA mapping table all in `docs/SECURITY.md`

---

## 9. Documentación y Presentación (10%)  —  🟡 7/10

- [x] Documentación completa — 14 docs in `docs/` covering all rubric reqs
- [x] Repositorio Git organizado — `docs/REPOSITORY_MAP` section in `README.md`
- [x] Costos de infraestructura — `docs/COSTS.md` per-env forecast + FinOps strategies
- [x] Manual de operaciones — `docs/OPERATIONS.md` (cold start + day-2 + DR drill procedures)
- [x] Presentación 20-30 min — **LIVE format** (not video). Script in `VIDEO_SCRIPT_FINAL.md` (re-use timeline)

**What's left for the live presentation:**
- [ ] Slides deck (Keynote/PowerPoint/Google Slides) derived from `docs/PROJECT_COMPLETION.md` rubric table
- [ ] Pre-flight: cluster up, port-forwards ready, browser tabs prepped
- [ ] Dry run with `docs/DEMO_RECORDING_GUIDE.md` as the shot list

**Gap (-3 pts):** Slides not yet built. ~1h work.

---

## Bonus 1 — Multi-Cloud (5%)  —  🟡 3/5

**Pivot:** GCP (deleted 2026-06-03) → **OCI** (sa-bogota-1, Always Free tier active)

- [x] Multi-cloud designed — `docs/ARCHITECTURE.md` §5 has 2-cloud topology (currently labeled GCP+Azure; needs label swap to GCP+OCI)
- [x] Backup strategy designed — `docs/OPERATIONS.md` §backups + §DR
- [ ] **Despliegue real en 2 clouds** — teammate's GCP redo + your OCI deployment (use Always Free Ampere ARM VM with Docker, OR OKE cluster within free quota)
- [ ] Load balancing entre clouds — designed via external-DNS; not deployed
- [ ] Comparativas de rendimiento — needs both clouds running

**What's left for full credit:**
- [ ] Scaffold `infra/terraform/modules/oci-{network,oke,ocir}/` (mirror Azure modules)
- [ ] Deploy 1 service (gateway-service) to OCI as proof-of-cloud
- [ ] Update `docs/ARCHITECTURE.md` to show GCP+OCI instead of GCP+Azure

---

## Bonus 2 — Service Mesh (5%)  —  ✅ 5/5

- [x] Istio installed — `infra/k8s/istio/install.sh` (was deployed on GCP cluster)
- [x] mTLS entre servicios — STRICT `PeerAuthentication` (`infra/k8s/istio/peer-authentication-strict.yaml`)
- [x] Traffic shifting para canary — `infra/k8s/istio/virtual-services/dashboard-service-canary.yaml` (90/10 → flip docs in comments)
- [x] Visualización del mesh — Kiali installed via `install.sh`
- [x] Circuit breakers + retry policies — `infra/k8s/istio/circuit-breaker-destination-rule.yaml` + `gateway-service-retry-timeout.yaml`

**For live demo:** needs cluster up. Show `kubectl get authorizationpolicies,virtualservices,destinationrules -A` + Kiali topology.

---

## Bonus 3 — Chaos Engineering (5%)  —  ✅ 5/5

- [x] Chaos Mesh installed — `infra/k8s/chaos-mesh/install.sh`
- [x] Experiments designed/documented — 5 experiments in `infra/k8s/chaos-mesh/experiments/` (pod-kill, network-delay, cpu-stress, http-abort, dns-fail) + workflow CR
- [x] Documentados en `docs/CHAOS_EXPERIMENTS.md` — hypothesis + steady-state + observation + success criteria per experiment
- [x] Integrado en arquitectura — network-delay experiment intentionally trips Resilience4j CB (pattern interplay proven by design)

**For live demo:** needs cluster up. Apply `network-delay-identity.yaml` and show CB state flip in Grafana.

---

## Bonus 4 — FinOps (5%)  —  ✅ 5/5

- [x] Monitoreo de costos — `docs/COSTS.md` §3 GCP Billing → BigQuery → Looker Studio recipe + sample SQL
- [x] Políticas de ahorro — spot pools (`gke_preemptible: true` in dev+stage), scale-to-zero CronJobs (`infra/k8s/finops/scale-down-dev.yaml`), Cloud SQL nightly stop (`cloudsql-stop-dev.cronjob.yaml`)
- [x] Dashboards de costos — designed in `docs/COSTS.md` §6 (cost per service/env/team/WoW/top-SKU panels)
- [x] Análisis de optimización — `docs/COSTS.md` §7 savings table
- [x] Estrategias documentadas — Loki-over-ELK (~3× cheaper), spot pools (~70% off), scale-to-zero off-hours

**For live demo:** show `docs/COSTS.md` rendered + GCP Billing console screenshot (last month's burn = $30-60 for dev).

---

## Live Presentation Outline (20–30 min)

| Block | Time | What to show on screen | Comes from |
|---|---|---|---|
| Intro + vision | 2 min | `README.md` + project summary | repo |
| Architecture (C4) | 5 min | `docs/ARCHITECTURE.md` Mermaid diagrams | repo |
| Agile + GitFlow | 3 min | Kanban board live + `docs/SPRINTS.md` | GitLab |
| CI/CD walkthrough | 5 min | Pipeline page + a green run + manual prod gate | GitLab |
| App running | 4 min | `kubectl get pods -A` + curl gateway + Kiali mesh | live cluster |
| Dashboards | 3 min | Grafana 2 dashboards + Loki query + Jaeger trace | live cluster |
| Perf results | 2 min | k6 output + Locust HTML + comparison report | repo or live |
| Multi-cloud + FinOps | 2 min | `docs/COSTS.md` + GCP Billing + OCI tenancy console | GCP + OCI |
| Lessons learned | 2 min | `docs/PROJECT_COMPLETION.md` §3 honest gaps | repo |
| Q&A | 2 min | — | — |

**Total: 28 min** with 2 min buffer.

---

## What to do RIGHT NOW (priority order for fastest finish)

1. **Run `/circleguard-checklist update`** after each artifact lands — keeps this file fresh
2. **Slides:** I can generate `docs/PRESENTATION_SLIDES.md` (markdown deck — paste into Marp / Slides) — 30 min work
3. **OCI multi-cloud:** I scaffold 3 OCI Terraform modules + deploy a single VM/OKE → multi-cloud bonus jumps from 3/5 → 5/5
4. **Re-take ALL screenshots** once teammate's cluster is back up:
   - 3 already captured: kanban, sprint 1, protected branches
   - 20+ pending in `docs/DEMO_RECORDING_GUIDE.md`
5. **Pre-flight rehearsal:** dry-run the live demo end-to-end at least once

## Current self-score (honest)

| Section | Possible | Current | Gap |
|---|---:|---:|---|
| Core 1-9 | 100 | **78** | -22 from non-running infra (cluster down) |
| Bonuses B1-B4 | 20 | **18** | -2 from multi-cloud not actually deployed |
| **Total** | **120** | **96** | — |

**If teammate's cluster + your OCI deploy come back online:** + 22 pts → realistic **108–115 / 120**.
