# CircleGuard — Final Demo Video Script (20–30 minutes)

This is the script for the IngeSoft V **final project** demo video. It
supersedes the 8-minute Taller 2 script at [`VIDEO_SCRIPT.md`](VIDEO_SCRIPT.md)
(kept as historical reference).

**Target length:** 28 minutes (gives 2 minutes of headroom below the
30-min ceiling).
**Audience:** course professor + grader, technical, sees the rubric.
**Tone:** demo, not lecture — show the system working, then explain.

---

## 0. Pre-flight checklist (do *before* hitting record)

Have these ready on disk / open in tabs **before** you press record.
Recording from a fresh terminal is fine, but the prerequisites must be
warm.

```bash
# Cluster state — all three contexts authenticated
kubectx; kubectl config get-contexts | grep '\*'

# Forward the observability UIs in the background
kubectl -n observability port-forward svc/grafana            3000:80   &
kubectl -n observability port-forward svc/jaeger-query      16686:16686 &
kubectl -n istio-system  port-forward svc/kiali             20001:20001 &
kubectl -n chaos-mesh    port-forward svc/chaos-dashboard    2333:2333 &

# Tabs open in the browser:
#   1. GitLab repo home (README)
#   2. GitLab Issue Board (filtered to current sprint)
#   3. GitLab Milestones
#   4. GitLab Pipelines (latest run on develop)
#   5. Grafana → CircleGuard / Gateway Service dashboard
#   6. Jaeger UI
#   7. Kiali → Graph view, namespace circleguard-master
#   8. Chaos Mesh dashboard

# Files open in VS Code, split view:
#   - docs/ARCHITECTURE.md (markdown preview rendered)
#   - docs/PROJECT_COMPLETION.md (rubric table visible)
#   - infra/k8s/istio/peer-authentication-strict.yaml
#   - infra/k8s/chaos-mesh/experiments/network-delay-identity.yaml
#   - .gitlab-ci.yml
```

**Tips:**

- Resolution 1080p min, 1440p preferred. macOS QuickTime or OBS Studio.
- Cursor enlarged (System Settings → Accessibility → Display).
- Mic level normalised; do a 10-sec test recording first.
- Speak in English (consistent with the rest of `docs/`).
- Don't read this script verbatim — bullet it on a second monitor and
  improvise the connective tissue.
- If a deploy or pipeline takes >1 min, mention "speeding this up" and
  cut to the result in post.

---

## 1. Timeline overview (28:00 total)

| Block | Time         | Section                                              | Anchor doc                                                    |
|------:|--------------|------------------------------------------------------|---------------------------------------------------------------|
| 1     | 0:00 – 2:00  | Intro + project context                              | [`README.md`](README.md), [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md) |
| 2     | 2:00 – 6:00  | Architecture walkthrough (C4 + multi-cloud)          | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)                |
| 3     | 6:00 – 9:00  | Agile board + sprints + GitFlow                      | [`docs/AGILE_METHODOLOGY.md`](docs/AGILE_METHODOLOGY.md), [`docs/BRANCHING.md`](docs/BRANCHING.md), [`docs/SPRINTS.md`](docs/SPRINTS.md) |
| 4     | 9:00 – 14:00 | Live CI/CD: push → pipeline → dev deploy             | [`docs/CI_CD.md`](docs/CI_CD.md), `.gitlab-ci.yml`            |
| 5     | 14:00 – 18:00| Observability — dashboards, alerts, traces           | [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md)              |
| 6     | 18:00 – 22:00| Resilience patterns — Chaos + Circuit Breaker + Canary| [`docs/CHAOS_EXPERIMENTS.md`](docs/CHAOS_EXPERIMENTS.md), [`docs/PATTERNS.md`](docs/PATTERNS.md) |
| 7     | 22:00 – 26:00| FinOps + multi-cloud DR talk                         | [`docs/COSTS.md`](docs/COSTS.md), [`docs/OPERATIONS.md`](docs/OPERATIONS.md) §6 |
| 8     | 26:00 – 28:00| Conclusion + retrospective                            | [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md)    |

---

## 2. Detailed script

### Block 1 — 0:00 – 2:00 — Intro + context

**On screen:** browser tab on GitLab repo home (rendered README).

**Say:**

> "Hi, I'm Santiago Espinosa. This is the CircleGuard final-project
> demo for IngeSoft V. CircleGuard is a privacy-first campus contact-
> tracing system. The mission statement on the README captures the
> design tension: *containment speed must outpace lab confirmation,
> without compromising student privacy*. The way the architecture
> resolves that tension is what this video walks through."

**Switch to:** VS Code → `docs/PROJECT_COMPLETION.md` rendered preview,
scroll to the rubric coverage table.

**Say:**

> "Before we dive in, here's the scorecard. Nine core requirements at
> 100 % of the grade, four bonuses at 20 % on top. Seven cores are fully
> green, two are mostly green with documented gaps that I'll be honest
> about in the conclusion. Three of four bonuses are fully green; the
> multi-cloud bonus is wired but the DR drill hasn't been rehearsed
> yet. Self-scored 110 out of 120."

---

### Block 2 — 2:00 – 6:00 — Architecture walkthrough

**On screen:** `docs/ARCHITECTURE.md` Markdown preview, top of file.

**Walk through, ~30 s per diagram:**

1. **C4 Level 1 (System Context):** "Three user populations, five
   external integrations, one logical system. Notice LDAP and LMS are
   *read-only* — we never write back to the campus identity system."
2. **C4 Level 2 (Container):** "Eight services, four data stores, one
   message bus. The arrow labels show protocol and, for Kafka, topic
   name. Notice that **only** `gateway-service` is exposed publicly —
   everything else lives behind it." Scroll down to the topic catalogue
   and the service responsibilities table.
3. **C4 Level 3 (`promotion-service`):** "This is the service I'd
   live-debug if I had a problem. Adapters on the outside, application
   layer in the middle with the Saga and Circuit Breaker, pure domain
   at the core. ArchUnit enforces this layering at build time."
4. **Data architecture (§4):** "The four-store pattern. Each store
   exists because a particular *question* is fastest to answer there.
   The most important line on this page is the *Critical privacy
   invariant* under the table: real names live in one Postgres row,
   guarded by `identity-service`. Everything else sees opaque UUIDs."
5. **Multi-cloud topology (§5):** "GKE primary in us-central1, AKS
   secondary in eastus. Multi-cloud is bonus B1. The deliberate
   asymmetry — no AKS HA Postgres, no AKS hot standby — is documented
   in the COSTS doc; we're trading RPO for cost on purpose."
6. **End-to-end request flow (§6):** "The reference flow: student
   submits symptom survey, fence cascades to circle. Synchronous edge
   budget 200 ms p95, async cascade budget 60 s p99. Both wired to
   Prometheus burn-rate alerts."

**Point at:** the cross-cutting concerns diagram (§7) — "Resilience4j,
OTel, Istio, mTLS, RBAC, Feature Toggles — six concerns, six
implementations, all linked to the docs that explain them."

---

### Block 3 — 6:00 – 9:00 — Agile + GitFlow

**On screen:** browser → GitLab Issue Board.

**Say:**

> "Two-week Scrum sprints, GitLab Milestones as sprint containers,
> Issues as stories. The board has the five columns the docs spec —
> Backlog / Ready / In Progress / In Review / Done — with WIP limits.
> Each card is a Connextra story with Given/When/Then acceptance
> criteria, story points, and the DoR/DoD checklists from
> `AGILE_METHODOLOGY.md`."

**Show:**

- Pick one issue, open it, scroll through the body — show the template-
  generated sections.
- Open Milestones — show the burndown for the current sprint.

**Switch to:** terminal.

```bash
# Show the branch structure
git branch -a | head -20
git log --oneline --graph --all --decorate -n 20
```

**Say:**

> "GitFlow: `main` is production, `develop` is integration, `feature/*`
> branches off `develop`, `release/*` for stabilization, `hotfix/*`
> straight off `main`. Every story has a corresponding feature branch
> and an MR. The gitGraph diagram in `docs/BRANCHING.md` formalises
> this."

**Open:** `docs/BRANCHING.md` to the gitGraph Mermaid block — show it
rendered.

---

### Block 4 — 9:00 – 14:00 — Live CI/CD

**On screen:** VS Code with a small file open in a feature branch.

**Type and execute:**

```bash
# Make a trivial change
echo "# trigger pipeline" >> docs/SPRINTS.md
git checkout -b chore/ci-demo
git add docs/SPRINTS.md
git commit -m "chore: trigger demo pipeline"
git push -u origin chore/ci-demo
```

**Switch to:** browser → GitLab Pipelines (auto-opens MR).

**While the pipeline runs, narrate the stages**, pointing at each
stage indicator as it goes green:

> "Stage 1 — `build` — Gradle parallel matrix per service, only the
> changed service rebuilds thanks to `rules:changes`. Stage 2 —
> `test` — unit + integration with JaCoCo coverage uploaded as a GitLab
> artifact. Stage 3 — `quality` — SonarQube with a quality-gate wait.
> Stage 4 — `security` — Trivy fs + image, syft SBOM, SARIF report into
> the GitLab security widget — I'll point at it. Stage 5 — `package` —
> Kaniko builds the image and pushes to GCP Artifact Registry."

**While waiting, switch to:** `.gitlab-ci.yml` and `.gitlab/ci/`
listing — point at the 10 template files.

**Open:** `docs/CI_CD.md` § "Differences vs. the original Jenkinsfiles"
and read the table headlines aloud:

> "Per-service builds with monorepo awareness, Kaniko instead of DinD,
> GKE not Kind, SonarQube quality gate, Trivy scans, OWASP ZAP, JaCoCo
> wired to Sonar, semantic-release for tagging, protected environments,
> Slack on failure. That's the upgrade from Jenkins."

**When pipeline reaches `deploy:dev`:**

```bash
kubectl -n circleguard-dev rollout status deployment/<svc-that-was-touched>
kubectl -n circleguard-dev get pods | head
```

**Say:**

> "Auto-deploy to `circleguard-dev` namespace on every `develop` merge.
> Stage and prod are gated — release branches auto-deploy to stage,
> `main` pauses at a manual `deploy:prod` job that only release-managers
> can play. That's the change-management approval gate in
> `CHANGE_MANAGEMENT.md` §2."

---

### Block 5 — 14:00 – 18:00 — Observability

**On screen:** browser → Grafana `http://localhost:3000`.

**Walk through, ~45 s per panel:**

1. Navigate to **Dashboards → CircleGuard → Gateway Service**. Point at
   the five panels: RPS, latency p50/p95/p99, 5xx %, JVM heap, CB OPEN.
   "These five panels are the template — every service has the same
   set with just the label swapped."
2. Open **Auth Service** dashboard for comparison.
3. Navigate to **Alerting → Rules**. Filter to `circleguard`. Show the
   nine SLO + infra rules from `OBSERVABILITY.md` §3.

**Demo a firing alert:**

```bash
# Generate load against the gateway to provoke the burn alert
kubectl -n circleguard-master run hey --rm -it --image=rcmorano/hey \
  --restart=Never -- -z 60s -c 50 \
  http://circleguard-gateway-service/api/v1/healthcheck
```

(In practice, use a synthetic high-error-rate endpoint or briefly
mis-route an Istio VirtualService to trip the rate.)

**Switch to:** Grafana → Alerting → Firing — show the alert.

**Open:** the runbook URL in the alert annotation →
[`docs/runbooks/gateway-slo-burn.md`](docs/runbooks/gateway-slo-burn.md) renders.

**Switch to:** Jaeger UI `http://localhost:16686`.

**Pick:** a trace for `gateway-service` POST `/api/v1/forms/symptoms`.

**Say:**

> "End-to-end trace through gateway → form → Kafka → promotion →
> identity → Neo4j. The W3C trace ID propagates through Kafka via the
> Spring Cloud Sleuth shim, so the async portion of the saga stitches
> into the same trace as the synchronous edge call."

**Switch to:** Loki Explore. Run:

```logql
{namespace="circleguard-master"} |= "trace_id=<copy from Jaeger>"
```

> "Same trace ID surfaces every log line from every service. That's the
> metrics-logs-traces correlation Grafana gives us for free."

---

### Block 6 — 18:00 – 22:00 — Resilience patterns

**On screen:** Kiali → Graph view, namespace `circleguard-master`. Show
the service mesh topology.

**Say:**

> "Three patterns to demo: circuit breaker via Chaos Mesh, feature
> toggle live flip, Istio canary."

#### 6a. Circuit breaker via Chaos Mesh (~90 s)

**Open:** `infra/k8s/chaos-mesh/experiments/network-delay-identity.yaml`.

> "200 ms delay injected on every egress from `identity-service` for 5
> minutes. Hypothesis: Resilience4j opens the breaker on the calling
> service within 60 seconds, fallback kicks in, no 5xx surge at the
> gateway."

**Apply:**

```bash
kubectl apply -f infra/k8s/chaos-mesh/experiments/network-delay-identity.yaml
```

**Switch to:** Grafana → CircleGuard / Resilience4j dashboard. Wait
~60 s and point at the circuit-breaker state metric flipping to OPEN.

**Stop the experiment:**

```bash
kubectl delete networkchaos network-delay-identity -n circleguard-dev
```

#### 6b. Feature toggle flip (~60 s)

**Open:** the ConfigMap or `application.yaml` that holds
`feature.cascade.depth`.

**Patch:**

```bash
kubectl -n circleguard-master patch configmap promotion-config \
  --type merge -p '{"data":{"feature.cascade.depth":"2"}}'
kubectl -n circleguard-master rollout restart deployment/circleguard-promotion-service
```

> "Cascade depth was 3, now 2. Spring picks up the new value on
> restart; no code change, no redeploy, no new image. Pattern doc:
> `PATTERNS.md` §2.2."

#### 6c. Istio canary (~90 s)

**Open:** `infra/k8s/istio/virtual-services/dashboard-service-canary.yaml`.

> "VirtualService routes 10 % to `canary`, 90 % to `stable`. Let's flip
> that."

**Patch:**

```bash
kubectl -n circleguard-master patch virtualservice dashboard-service-canary \
  --type merge -p '{"spec":{"http":[{"route":[
    {"destination":{"host":"dashboard-service","subset":"canary"},"weight":50},
    {"destination":{"host":"dashboard-service","subset":"stable"},"weight":50}]}]}}'
```

**Switch to:** Kiali graph — point at the traffic split visualisation.

**Revert:** patch back to 10/90. Mention that the full revert procedure
is in `OPERATIONS.md` §3.2.3.

---

### Block 7 — 22:00 – 26:00 — FinOps + multi-cloud

**On screen:** `docs/COSTS.md` rendered, scroll to §2 (cost forecast).

**Say:**

> "Three environments, three price points: dev $30–60, stage $120–180,
> prod $350–500 per month. Spot pools on dev and stage save roughly
> 68 % on compute. Scale-to-zero CronJobs power dev down outside
> business hours for another 37 %. Loki over ELK saves another 67 % on
> log storage. Aggregate effect on dev is ~50 % cheaper than an
> unoptimised baseline."

**Scroll to:** §3 — BigQuery billing export.

> "Detailed billing export to BigQuery with cost-allocation labels
> enabled in the GKE Terraform module. Looker Studio dashboard
> template referenced. The SQL in §3.4 gives us cost-per-namespace
> by month — that's how we attribute spend to environments."

**Switch to:** `infra/k8s/finops/` listing in VS Code.

```bash
ls infra/k8s/finops/
```

> "Five files. `scale-down-dev.yaml` and `scale-up-dev.yaml` are
> CronJobs. `cloudsql-stop-dev.cronjob.yaml` does the same for the dev
> SQL instance. `pdb-stateful.yaml` protects Kafka and Postgres
> stateful sets from spot-reclamation quorum loss. `billing-export-setup.sh`
> is the bootstrap script."

**Switch to:** `docs/ARCHITECTURE.md` §5 (multi-cloud diagram).

**Say:**

> "Multi-cloud is bonus B1. GCP is primary; Azure is warm standby. Cloud
> SQL replicates async to Azure Postgres with RPO ≤ 5 min. ACR
> geo-replicates Artifact Registry on every release. DNS weighted
> records flip to AKS during DR. The DR runbook is in OPERATIONS §6.3.
> Honest gap: the runbook has been written and scripted, but the
> quarterly drill hasn't been performed yet."

---

### Block 8 — 26:00 – 28:00 — Conclusion

**On screen:** `docs/PROJECT_COMPLETION.md` rendered.

**Scroll to:** §3 (Known gaps).

**Say:**

> "Three things worked well:
>
> 1. Forcing every architectural choice to be documented with the
>    *rejected* alternative kept the design defensible.
> 2. The C4 model gave the project three reading depths instead of one
>    overwhelming diagram.
> 3. Building the observability stack *before* the chaos experiments
>    meant the experiments answered real questions instead of just
>    producing data.
>
> Three things I'd do differently next time:
>
> 1. Add Pact contract tests in week 2, not week 6 — by the time E2E
>    tests cover the gap, the contract drift has already happened.
> 2. Schedule the DR drill on day 1 of the sprint, not at the end —
>    drill execution always wants more time than expected.
> 3. Commit the Grafana cost-dashboard JSON during the same MR as the
>    billing-export setup script — splitting them across two MRs left
>    a documentation orphan.
>
> Rubric self-score: 110 out of 120. Everything else lives in the
> repository. Thanks for watching."

**End on:** the README header in a browser tab, with the GitLab URL
visible.

---

## 3. Editing notes (post-production)

- Speed up the pipeline-wait segment to ~1.5× (otherwise viewer is
  bored for ~3 min).
- Cut any "let me look that up" — re-record the lookup if needed.
- Add a one-line title card at the start of each block showing
  "BLOCK N: <topic>". Free overlay templates ship with QuickTime and
  iMovie.
- Burn-in the timestamp at the bottom-left so the grader can jump.
- Closed captions: auto-generate via Descript / YouTube auto-CC and
  proofread.
- Export 1080p H.264, mp4. Upload to YouTube unlisted; paste link into
  [`docs/PROJECT_COMPLETION.md`](docs/PROJECT_COMPLETION.md) §4.

---

## 4. Screenshot list (to capture *during* recording for the report)

Capture these as PNGs in `screenshots/final/` for the final written
report:

1. `pipeline-green.png` — full pipeline view, all stages green.
2. `grafana-gateway.png` — Gateway Service dashboard with traffic.
3. `grafana-alert-firing.png` — Alerting → Firing list.
4. `jaeger-end-to-end.png` — trace view, gateway → identity → Neo4j.
5. `loki-trace-correlation.png` — Loki query with trace ID filter.
6. `kiali-graph.png` — service-mesh graph.
7. `chaos-experiment-running.png` — Chaos Mesh dashboard.
8. `circuit-breaker-open.png` — Grafana, R4J state metric = 1.
9. `kiali-canary-50-50.png` — traffic split after canary flip.
10. `billing-dashboard.png` — Looker Studio cost breakdown.
11. `gitlab-board.png` — sprint board with stories in flight.
12. `release-notes-sample.png` — `RELEASE_NOTES_v1.0.<N>.md` rendered.
