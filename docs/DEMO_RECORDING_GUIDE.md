# CircleGuard — Demo Recording + Screenshot Guide

**Purpose**: single source of truth for what you record/capture, in what order, with the exact commands. Use this side-by-side with [`VIDEO_SCRIPT_FINAL.md`](../VIDEO_SCRIPT_FINAL.md) (which is the narrative script).

**Estimated total time to record + capture everything**: ~3 hours, including 1 retake budget.

---

## Pre-flight checklist (do this BEFORE you start recording)

Run through this list. If any check fails, fix it before pressing record — re-takes cost more than verification.

- [ ] `gcloud config get-value project` returns `circleguard-final-cfs-2026`
- [ ] `gcloud container clusters list --region us-central1` shows `circleguard-dev-gke RUNNING`
- [ ] `kubectl get nodes` returns ≥1 `Ready` node
- [ ] `kubectl get ns | grep observability` shows the namespace exists
- [ ] `kubectl get pods -n observability` shows Prometheus, Grafana, Loki, Jaeger all `Running`
- [ ] `kubectl get pods -A | grep -v Running | grep -v Completed` is empty
- [ ] GitLab pipeline `https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines` has at least one green run
- [ ] Kanban board: 16 of 23 cards closed, milestones visible
- [ ] OBS / Loom / QuickTime configured at **1920×1080**, 30fps, system audio + mic mixed
- [ ] Browser zoom at 110% (text readable on a phone screen too)
- [ ] Terminal font ≥ 16pt, theme high-contrast
- [ ] All sensitive panels hidden (close Slack, password managers, personal email)
- [ ] Wired internet (avoid wifi drops mid-record)
- [ ] Battery plugged in
- [ ] Phone on Do Not Disturb

---

## Section-by-section shot list (mirrors VIDEO_SCRIPT_FINAL.md timestamps)

For each shot: **what to show**, **commands to type**, **what to point at**.

### 0:00–2:00 — Intro
- Show: this file (PROJECT_COMPLETION.md) open in a browser preview, scroll to §1 executive summary
- Say: project name, course, your name, what CircleGuard does in 30 seconds
- No commands

### 2:00–6:00 — Architecture walkthrough
- Show: `docs/ARCHITECTURE.md` rendered in GitLab (the Mermaid diagrams render natively)
- Open: https://gitlab.com/espinosacodes/circle-guard-final/-/blob/main/docs/ARCHITECTURE.md
- Point at each diagram in order: C4 L1, C4 L2, C4 L3 (promotion-service), Data model, Deployment topology, Request flow
- For the deployment topology, emphasise GCP primary + OCI secondary (multi-cloud bonus, see `docs/MULTICLOUD_OCI.md`)
- No commands

### 6:00–9:00 — Agile + GitFlow + Kanban
- Show 1: GitLab Kanban board — https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311
  - Point at 5 columns, show a card in each
  - Open one Sprint 2 issue, show acceptance criteria + labels (SP::N, type::*, milestone)
- Show 2: Milestones — https://gitlab.com/espinosacodes/circle-guard-final/-/milestones
  - Open Sprint 1 → burndown chart visible
- Show 3: `docs/BRANCHING.md` Mermaid gitGraph
- Show 4: `docs/SPRINTS.md` — Sprint 1 retrospective section (proves you ran a real retro)
- Quick `git log --oneline -10` in terminal to show Conventional Commits

### 9:00–14:00 — CI/CD live demo
- **Pre-record this segment ahead of time** (CI is slow; you don't want 10 min of dead air on camera)
- Show 1: `.gitlab-ci.yml` parent + walk through the 11 includes in `.gitlab/ci/`
- Show 2: Pipeline page — https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines
  - Click into a green pipeline, expand each stage
  - Show SonarQube report, Trivy security report, JaCoCo coverage widget
- Show 3: Push a small change to `develop` live (or play the pre-recorded segment)
- Commands:
  ```bash
  git checkout develop
  echo "# trivial change" >> README.md
  git add README.md
  git commit -m "chore: trigger pipeline for demo"
  git push gitlab develop
  ```
- Cut to the live pipeline run, narrate the stages
- Show 4: Manual approval on prod stage (open the pipeline of a `v*` tag, point at the manual gate)

### 14:00–18:00 — Observability walkthrough
- **Pre-port-forward in a separate terminal before recording:**
  ```bash
  kubectl port-forward -n observability svc/kps-grafana 3000:80 &
  kubectl port-forward -n observability svc/jaeger-query 16686:16686 &
  ```
- Show 1: Grafana — http://localhost:3000 (admin / password from `grafana-admin-credentials` secret)
  - Open **Auth Service** dashboard → point at RPS, p95 latency, 5xx %, JVM heap, circuit-breaker state
  - Open **Gateway Service** dashboard → same panels
  - Switch datasource → Loki → run query `{namespace="circleguard-dev"} |= "ERROR"` to show centralized logs
- Show 2: Jaeger — http://localhost:16686
  - Pick a recent trace, expand the spans, show the cross-service flow (form → kafka → promotion → notification)
- Show 3: Alerts firing — trigger a fake alert:
  ```bash
  # in another terminal:
  kubectl run cb-stress --image=busybox --restart=Never --rm -it -- \
    sh -c "while true; do wget -q -O- http://auth-service.circleguard-dev/api/v1/auth/login --post-data='{}' || true; done"
  ```
  - Show Alertmanager UI: `kubectl port-forward -n observability svc/kps-alertmanager 9093:9093`
  - Point at the firing alert and the runbook link

### 18:00–22:00 — Resilience patterns + Istio canary + Chaos
- Show 1: Circuit breaker open via Chaos Mesh
  ```bash
  kubectl apply -f infra/k8s/chaos-mesh/experiments/network-delay-identity.yaml
  ```
  - In Grafana Auth Service dashboard, point at the circuit-breaker state panel → flips to OPEN
- Show 2: Feature Toggle flip without redeploy
  ```bash
  kubectl -n circleguard-dev edit cm dashboard-service-feature-toggles
  # change FEATURES_GRAPHQL_ENDPOINT_ENABLED to "true"
  kubectl -n circleguard-dev rollout restart deployment dashboard-service
  curl http://<dashboard-svc>/api/v1/dashboard/feature-toggles
  ```
- Show 3: Istio canary traffic shifting
  ```bash
  istioctl dashboard kiali  # opens http://localhost:20001
  ```
  - Show the mesh topology in Kiali, point at v1 vs v2 of dashboard-service
  - Run the 3 canary flip commands from `docs/OPERATIONS.md`
- Show 4: Chaos workflow
  ```bash
  kubectl apply -f infra/k8s/chaos-mesh/workflows/full-resilience-suite.yaml
  kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
  ```
  - Open http://localhost:2333, show the workflow running

### 22:00–26:00 — FinOps + multi-cloud talk
- Show 1: `docs/COSTS.md` cost forecast table
- Show 2: GCP Billing console — https://console.cloud.google.com/billing
- Show 3: Looker Studio cost dashboard (template) — point at the 5 panels
- Show 4: `infra/k8s/finops/scale-down-dev.yaml` — narrate the nightly scale-down
- Show 5 (talk only — no live failover): `docs/ARCHITECTURE.md` §5 multi-cloud diagram, explain RPO/RTO targets

### 26:00–30:00 — Conclusion
- Show: `docs/PROJECT_COMPLETION.md` §2 rubric coverage table — point at the ✅ / ⚙️ status column
- Show: §3 honest gaps
- Say:
  - What worked: end-to-end traceability (issue → branch → MR → pipeline → deploy → trace)
  - What I'd do differently: introduce Pact contract tests earlier, run DR drill in Sprint 2 not later
  - Thank the audience

---

## Screenshot deliverables (separate from video)

These go into the final report as embedded images. **Capture them once, name them per this table**:

| File name | Where to capture | Why it matters |
|---|---|---|
| `screenshots/final/01-kanban-board.png` | https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311 | Proves Req 1 — agile board with real cards |
| `screenshots/final/02-sprint1-burndown.png` | https://gitlab.com/espinosacodes/circle-guard-final/-/milestones/1 | Proves Req 1 — sprint executed |
| `screenshots/final/03-gitlab-pipeline-green.png` | https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines (latest green) | Proves Req 4 — CI/CD all stages |
| `screenshots/final/04-sonarqube-report.png` | SonarQube → CircleGuard project → Issues tab | Proves Req 4 — SonarQube |
| `screenshots/final/05-trivy-report.png` | A pipeline's `security` stage → Trivy artifact | Proves Req 4 + Req 8 — vuln scan |
| `screenshots/final/06-zap-report.png` | A pipeline's `zap` stage → HTML artifact | Proves Req 5 + Req 8 — DAST |
| `screenshots/final/07-grafana-auth-dashboard.png` | Grafana → Auth Service dashboard | Proves Req 7 — dashboards |
| `screenshots/final/08-grafana-gateway-dashboard.png` | Grafana → Gateway Service dashboard | Proves Req 7 |
| `screenshots/final/09-jaeger-trace-cross-service.png` | Jaeger → a trace spanning 3+ services | Proves Req 7 — distributed tracing |
| `screenshots/final/10-alertmanager-firing.png` | Alertmanager UI with at least one firing alert | Proves Req 7 — alerts wired |
| `screenshots/final/11-kiali-mesh-topology.png` | Kiali graph view of `circleguard-dev` namespace | Proves Bonus 2 — service mesh |
| `screenshots/final/12-istio-canary-50-50.png` | Kiali workload graph during 50/50 canary | Proves Bonus 2 — traffic shifting |
| `screenshots/final/13-chaos-mesh-workflow.png` | Chaos dashboard, workflow page mid-run | Proves Bonus 3 |
| `screenshots/final/14-chaos-cb-opens.png` | Grafana CB panel showing OPEN state during chaos | Proves Bonus 3 + Req 3 interplay |
| `screenshots/final/15-gcp-billing.png` | GCP Billing console showing project cost | Proves Bonus 4 |
| `screenshots/final/16-looker-cost-dashboard.png` | Looker Studio cost dashboard | Proves Bonus 4 |
| `screenshots/final/17-gke-clusters.png` | GCP Console → GKE → clusters list (showing dev cluster RUNNING) | Proves Req 2 — Terraform applied |
| `screenshots/final/18-tf-state-bucket.png` | GCP Console → Cloud Storage → `circleguard-final-cfs-2026-tfstate` versioning ON | Proves Req 2 — remote state |
| `screenshots/final/19-terraform-plan-zero-drift.png` | Terminal after `terraform plan` showing 0 to change | Proves Req 2 — idempotent |
| `screenshots/final/20-protected-branches.png` | GitLab Settings → Repository → Protected branches | Proves CG-019 + Req 1 |
| `screenshots/final/21-feature-toggle-flip.png` | curl response before+after toggling `graphql-endpoint-enabled` | Proves Req 3 — configuration pattern |
| `screenshots/final/22-circuit-breaker-test-passing.png` | Terminal showing `./gradlew :services:circleguard-auth-service:test` green | Proves Req 3 + Req 5 |
| `screenshots/final/23-rubric-coverage.png` | docs/PROJECT_COMPLETION.md §2.1 table rendered | The professor's reading-order anchor |

**Naming**: keep the `NN-short-name.png` pattern so the embedded order in the final report is stable.

**Embed in**: `docs/PROJECT_COMPLETION.md` §2 evidence column OR a new `docs/FINAL_REPORT_VISUAL.md` if you want them all in one place.

---

## Recording mechanics

- **Tool**: OBS Studio (free) or Loom (faster post-prod). QuickTime works but no scene transitions.
- **Cut points**: record each section as a separate clip — easier to retake just one section.
- **Subtitles**: enable auto-subtitles in YouTube/Loom; the rubric demo is in Spanish for Icesi, so check the language toggle.
- **Length safety**: target 26 min so you have 4 min headroom under the 30-min ceiling.
- **Export**: 1080p, MP4, H.264, ≤ 2 GB if uploading to GitHub Releases; YouTube unlimited.

## Upload destinations

| Destination | When to use | URL after upload |
|---|---|---|
| YouTube (unlisted) | Default | Update `docs/PROJECT_COMPLETION.md` §4 demo video row |
| Loom | Faster, OK if professor accepts | Same row |
| GitLab Project → Wiki → upload as attachment | If institutional policy bars external video hosting | Same row |

Always **unlisted/private**, never public.

---

## After recording

1. Update `docs/PROJECT_COMPLETION.md` §4 with the real video URL (replace the `<id>` placeholder)
2. Update `README.md` "Live URLs" section with the same URL
3. Commit:
   ```bash
   git add docs/PROJECT_COMPLETION.md README.md
   git commit -m "docs: link final demo video and slides"
   git push gitlab master:main
   ```
4. Tag the release:
   ```bash
   git tag -a v1.0.0 -m "IngeSoft V — final project submission"
   git push gitlab v1.0.0
   ```
5. Hand the professor: the GitLab project URL + `docs/PROJECT_COMPLETION.md` (everything else is reachable from there).
