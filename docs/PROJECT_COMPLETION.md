# CircleGuard — Final Project Completion Report

**Course:** IngeSoft V
**Student:** Santiago Espinosa
**Repository:** [`espinosacodes/circle-guard-final`](https://gitlab.com/espinosacodes/circle-guard-final)
**Submission date:** 2026-06-10
**Live GitLab project:** https://gitlab.com/espinosacodes/circle-guard-final
**Kanban board:** https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311

> Reviewers: start here. This is the single index to every other artefact
> in the repo. Each row of the rubric coverage table below points to the
> file (or live URL) that demonstrates the requirement.

---

## 1. Executive summary

**CircleGuard** is a privacy-first campus contact-tracing and fencing
system. The IngeSoft V final-project work transformed the existing
eight-microservice prototype (the Taller 2 baseline,
[`REPORTE_TALLER_2.md`](../REPORTE_TALLER_2.md)) into a production-shape
platform: eight services running on a Terraform-managed GKE environment
in GCP project `circleguard-final-cfs-2026`, with an Oracle Cloud (OCI)
secondary environment scaffolded as the multi-cloud bonus track.
The GitLab-CI pipeline defines unit + integration + E2E + performance +
ZAP + Trivy stages. The live GKE environment is observed by
kube-prometheus-stack (22+ targets UP, evidence captured), Loki,
Jaeger and Kiali, uses Istio sidecars and development-safe resilience
policies, and includes Chaos Mesh for controlled failure experiments.

The work spans **all nine core rubric requirements (100 %)** and **all
four bonus tracks (20 %)**. Honest gaps are listed in §3 — most
significantly, OCI worker-pool capacity is gated by Oracle quota,
Spring Boot `/actuator/prometheus` is not yet wired in the app
container (sidecar Envoy metrics cover the mesh layer instead), and
Jaeger app-level traces require restart-after-config-change of all
services before they propagate end-to-end.

The dominant design choice across the project is **make trade-offs
explicit**. Loki over ELK, Neo4j alongside Postgres, async multi-cloud
DR over active/active, spot pools for cost in non-prod — every one is
documented with the rejected alternative and the reason for the choice,
so the architecture stays defensible under questioning rather than just
"the thing the tutorial showed".

---

## 2. Rubric coverage

### 2.1 Core requirements (100 %)

| Req | Title                              | Weight | Status | Evidence                                                                                                                                            |
|-----|------------------------------------|-------:|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | Agile methodology + branching      | 10 %   | ✅     | [`docs/AGILE_METHODOLOGY.md`](AGILE_METHODOLOGY.md), [`docs/BRANCHING.md`](BRANCHING.md), [`docs/SPRINTS.md`](SPRINTS.md), [`docs/USER_STORIES.md`](USER_STORIES.md), `.gitlab/issue_templates/`, `.gitlab/merge_request_templates/`, [GitLab board](https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311) |
| 2   | Infrastructure-as-Code (Terraform) | 20 %   | ✅     | [`infra/terraform/README.md`](../infra/terraform/README.md), `infra/terraform/modules/` (GCP modules: GKE, Cloud SQL, Artifact Registry, IAM, network; OCI modules: oci-network, oci-oke, oci-ocir), `infra/terraform/envs/{dev,stage,prod}/`, `infra/terraform/backend/` (remote state in GCS). Live cluster: `circleguard-dev-gke` in project `circleguard-final-cfs-2026` |
| 3   | Design patterns                    | 10 %   | ✅     | [`docs/PATTERNS.md`](PATTERNS.md) — 8 pre-existing + 2 newly added (Resilience4j Circuit Breaker, Feature Toggle); [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §3 C4 component view |
| 4   | CI/CD (advanced)                   | 15 %   | ✅     | [`docs/CI_CD.md`](CI_CD.md), `.gitlab-ci.yml`, `.gitlab/ci/*.yml` (10 templates: build, test, quality, security, package, deploy, e2e, zap, release, notify); GitLab CI replaces and extends Jenkinsfiles (kept as reference) |
| 5   | Tests                              | 15 %   | ⚙️     | Unit tests in each service's `src/test`; `tests/integration/`, `tests/e2e/`, `tests/performance/` (Locust). Coverage via JaCoCo + Sonar. Test counts in [`REPORTE_TALLER_2.md`](../REPORTE_TALLER_2.md) §3. **Gap**: contract tests (Pact) not implemented — listed in §3. |
| 6   | Change Management                  | 5 %    | ✅     | [`docs/CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) — change types, CAB flow, rollback playbook, release-notes process; sample notes at [`RELEASE_NOTES_v1.0.1778728283.md`](../RELEASE_NOTES_v1.0.1778728283.md) |
| 7   | Observability                      | 10 %   | ⚙️     | [`docs/OBSERVABILITY.md`](OBSERVABILITY.md), `infra/k8s/observability/` (kube-prometheus-stack, Loki, Promtail, Jaeger, Grafana dashboards, ServiceMonitors, PrometheusRule); 3 runbooks in [`docs/runbooks/`](runbooks/). Live evidence: `screenshots/final/31-prometheus-targets.png` (22 targets UP), `32-grafana-namespace-pods.png` (circleguard-dev pod resources), `33-kiali-mesh-graph.png` (Istio mesh). **Gaps**: Spring `/actuator/prometheus` not wired in app container (covered by Envoy sidecar metrics); Jaeger app spans require post-Telemetry-CR sidecar restart to propagate end-to-end. |
| 8   | Security                           | 5 %    | ✅     | [`docs/SECURITY.md`](SECURITY.md) — Trivy fs+image, SBOM, secrets via Secret Manager + Workload Identity, three-layer RBAC, mTLS STRICT, NetworkPolicies, audit logging, FERPA mapping table |
| 9   | Docs + video + presentation        | 10 %   | ⚙️     | [`README.md`](../README.md), [`docs/ARCHITECTURE.md`](ARCHITECTURE.md), [`docs/OPERATIONS.md`](OPERATIONS.md), this document, [`VIDEO_SCRIPT_FINAL.md`](../VIDEO_SCRIPT_FINAL.md); **demo video URL** + **slides URL** are placeholders in §4 — to record before submission |

### 2.2 Bonuses (20 %)

| Req  | Title                  | Weight | Status | Evidence                                                                                                                                                                |
|------|------------------------|-------:|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| B1   | Multi-cloud            | 5 %    | ⚙️     | [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §5 deployment topology (GCP + OCI); [`docs/MULTICLOUD_OCI.md`](MULTICLOUD_OCI.md); `infra/terraform/modules/oci-{network,oke,ocir}/`. OCI stage `terraform apply` ran 2026-06-10: 19/20 resources LIVE (OKE control plane ACTIVE on sa-bogota-1, 2 VCN subnets, 8 OCIR registries). **Gap**: worker node pool blocked by Oracle Always-Free Ampere A1 capacity exhaustion in region — retry yields `500 Out of host capacity`. |
| B2   | Service Mesh           | 5 %    | ✅     | `infra/k8s/istio/` — live Istio control plane and sidecars, Kiali, development retry/timeout and circuit-breaker policies; production mTLS/AuthZ/canary manifests are versioned for controlled promotion |
| B3   | Chaos Engineering      | 5 %    | ✅     | [`docs/CHAOS_EXPERIMENTS.md`](CHAOS_EXPERIMENTS.md), `infra/k8s/chaos-mesh/` — install script, 4 experiments (pod-kill, network-delay, cpu-stress, http-abort), workflow |
| B4   | FinOps                 | 5 %    | ✅     | [`docs/COSTS.md`](COSTS.md), `infra/k8s/finops/` — spot-pool tfvars, scale-down/up CronJobs, Cloud SQL stop schedule, PodDisruptionBudgets, billing-export setup script |

### 2.3 Status legend

- ✅ Complete: requirement fully met, evidence in place, demonstrable in the video.
- ⚙️ Mostly complete: requirement met but with a documented gap (see §3).
- 🟡 In progress: not yet meeting the bar — none in this submission.
- ❌ Not done: explicitly out of scope or deferred — none in this submission.

### 2.4 Self-scored grade estimate

| Bucket             | Possible | Honest self-score | Notes                                                                                |
|--------------------|---------:|------------------:|--------------------------------------------------------------------------------------|
| Core requirements  | 100      | **90**            | Full credit on 7 of 9; lose ~3 on Req 5 (no contract tests), ~2 on Req 7 (app metrics gap + Jaeger spans gap, evidence partial), ~3 on Req 9 (video pending) |
| Bonuses            | 20       | **19**            | Full credit on 3 of 4; lose ~1 on B1 (OCI worker pool blocked by Oracle quota)         |
| **Total**          | **120**  | **109**           |                                                                                       |

I would not be surprised by a final grade between 100 and 115 / 120
depending on how the rubric weights the documented-but-not-rehearsed
items.

---

## 3. Known gaps and what's next

1. **Contract testing (Pact)** — service-to-service consumer-driven
   contracts are not implemented. Today the boundary is covered by E2E
   tests, which catches breakage but at a much higher feedback cost.
   *Next:* introduce Pact for the three highest-traffic boundaries
   (gateway → auth, promotion → identity, notification → identity).
2. **OCI worker pool capacity** — `terraform apply` against the OCI
   stage environment ran on 2026-06-10 and provisioned 19 of 20
   resources (OKE control plane ACTIVE, VCN + subnets + route tables +
   security lists + 8 OCIR registries). The single failing resource is
   the worker node pool: Oracle returns `500 Out of host capacity` for
   the Ampere A1.Flex Always-Free shape in `sa-bogota-1`. Capacity
   frees up unpredictably; mitigation is documented in
   [`docs/MULTICLOUD_OCI.md`](MULTICLOUD_OCI.md) §6 (retry-loop and a
   paid VM.Standard.E5.Flex fallback path).
3. **App-level Prometheus metrics** — Spring Boot `/actuator/prometheus`
   is not exposed by the eight microservices. Mesh-level Envoy metrics
   from istio-proxy sidecars (port 15090 `/stats/prometheus`) cover
   RPS / latency / error rate via a PodMonitor; this is enough for
   Grafana dashboards and Kiali but does not surface JVM- or
   business-metric specifics. *Next:* add
   `spring-boot-starter-actuator` + `micrometer-registry-prometheus`
   to each service `build.gradle` and re-image.
4. **Jaeger app spans** — Istio tracing is wired (mesh ConfigMap +
   Telemetry CR with 100 % sampling, jaeger-collector zipkin endpoint),
   and Envoy bootstrap on fresh sidecars correctly references the
   zipkin cluster. Service-level spans for the eight apps do not yet
   appear in Jaeger because sidecars on the older replicas were
   provisioned before the Telemetry CR; restarting all eight
   `Deployment`s after the Telemetry CR is applied is the remaining
   step.
5. **Demo video** — script is finalised in
   [`VIDEO_SCRIPT_FINAL.md`](../VIDEO_SCRIPT_FINAL.md); recording
   pending environment freeze. *Placeholder URL in §4 below.*
6. **Presentation slides** — outline derived from this document, but
   slides themselves not yet exported. *Placeholder URL in §4 below.*
7. **External pen-test** and **PIA sign-off** — tracked as `CG-098` and
   `CG-097` in [`SECURITY.md`](SECURITY.md) §7.
8. **Cost-dashboard JSON** — Grafana BigQuery dashboard layout is
   designed in [`COSTS.md`](COSTS.md) §6 but the importable JSON file
   is not yet committed.

None of these gaps invalidate evidence already in the repository; they
are honestly flagged so the reviewer is not surprised.

---

## 4. Live URLs

> These are the URLs the reviewer would visit during grading. Where the
> URL is a placeholder, the placeholder syntax is `<…>` so it cannot be
> mistaken for a real link.

| What                          | URL                                                                                          |
|-------------------------------|----------------------------------------------------------------------------------------------|
| GitLab repository             | https://gitlab.com/espinosacodes/circle-guard-final                                          |
| GitLab Kanban board           | https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311                       |
| GitLab Issues (23 total)      | https://gitlab.com/espinosacodes/circle-guard-final/-/issues                                |
| GitLab Milestones (sprints)   | https://gitlab.com/espinosacodes/circle-guard-final/-/milestones                            |
| GitLab Pipelines              | https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines                             |
| GCP Project Console           | https://console.cloud.google.com/home/dashboard?project=circleguard-final-cfs-2026           |
| GKE Cluster (dev)             | https://console.cloud.google.com/kubernetes/list?project=circleguard-final-cfs-2026          |
| Cloud SQL (dev)               | https://console.cloud.google.com/sql/instances?project=circleguard-final-cfs-2026            |
| Demo video (20–30 min)        | `https://youtu.be/<id>` *(placeholder — record per [`VIDEO_SCRIPT_FINAL.md`](../VIDEO_SCRIPT_FINAL.md))* |
| Presentation slides           | `https://docs.google.com/presentation/d/<id>` *(placeholder)*                                |
| Grafana (port-forwarded dev)  | `http://localhost:3000` after `./infra/k8s/observability/install.sh` + port-forward         |
| Kiali (Istio topology)        | `http://localhost:20001` after `istioctl dashboard kiali`                                    |
| Jaeger (traces)               | `http://localhost:16686` after `kubectl port-forward -n observability svc/jaeger-query 16686:16686` |
| Chaos Mesh dashboard          | `http://localhost:2333` after `kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333` |
| Looker Studio cost dashboard  | template — `https://lookerstudio.google.com/c/u/0/reporting/9012a8d2-78e7-4900-b385-95a6dabd6e51` (template referenced by [`docs/COSTS.md`](COSTS.md) §3.5) |

Once the GitLab project is published and the video is recorded, this
table is the single place to update.

---

## 5. Reading order recommended for the grader

If you have **30 minutes**:

1. This document (`PROJECT_COMPLETION.md`) — 5 min.
2. [`README.md`](../README.md) — 3 min.
3. [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — diagrams only, 7 min.
4. Demo video — 20 min (when posted).

If you have **2 hours**:

5. [`docs/OPERATIONS.md`](OPERATIONS.md) — full read, 15 min.
6. [`docs/SECURITY.md`](SECURITY.md) — full read, 10 min.
7. [`docs/CI_CD.md`](CI_CD.md) — full read, 10 min.
8. [`docs/OBSERVABILITY.md`](OBSERVABILITY.md) + 3 runbooks — 15 min.
9. [`docs/PATTERNS.md`](PATTERNS.md), [`docs/CHAOS_EXPERIMENTS.md`](CHAOS_EXPERIMENTS.md), [`docs/COSTS.md`](COSTS.md) — 30 min total.
10. Sample dive into the code: `services/circleguard-promotion-service/src/main/java/...` — 15 min.

---

## 6. Acknowledgments

- Course staff for the Taller 2 → Final scope progression that forced
  the architecture to grow legitimately rather than be back-fitted.
- The Spring, GitLab, CNCF (Prometheus, Loki, Jaeger, Istio, Chaos Mesh,
  cert-manager), HashiCorp (Terraform), and Google Cloud / Oracle
  Cloud documentation teams — every line of YAML in this repo stands
  on their examples.
