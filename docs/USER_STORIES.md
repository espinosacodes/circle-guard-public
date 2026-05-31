# CircleGuard — User Story Catalog

This catalog holds every committed and planned user story for the project.
Each story follows the **INVEST** criteria (Independent, Negotiable, Valuable,
Estimable, Small, Testable) and the Connextra template:

> **As a** _role_, **I want** _capability_, **so that** _benefit_.

Stories are organized by ID. The same IDs are used as GitLab issue
`#CG-NNN` references in commits, MRs, and the sprint board (see
[`SPRINTS.md`](SPRINTS.md)).

## Conventions

- **Roles**: `Health Center Officer`, `Student`, `IT Admin`, `DevOps Engineer`,
  `Security Officer`.
- **Acceptance Criteria**: at least three Given/When/Then scenarios per story.
- **Definition of Done (story-level)**: each story closes its own checklist; the
  team-wide DoD lives in [`AGILE_METHODOLOGY.md`](AGILE_METHODOLOGY.md).
- **Story Points**: modified Fibonacci (1, 2, 3, 5, 8, 13).

---

## CG-001 — Terraform modules for EKS + RDS + MSK

> **As a** DevOps Engineer, **I want** Terraform modules that provision an EKS
> cluster, multi-AZ RDS Postgres, and an MSK Kafka cluster, **so that** I can
> spin up identical dev/stage/prod environments in under 30 minutes with no
> manual console clicks.

**Acceptance Criteria**

- *Given* an empty AWS account, *when* I run `terraform apply -var env=dev`,
  *then* a working EKS cluster, RDS, and MSK exist within 30 minutes.
- *Given* an existing dev environment, *when* I run `terraform plan` a second
  time, *then* the plan reports **0 to change**.
- *Given* a different env (`stage`), *when* I apply the same modules with
  `-var env=stage`, *then* the topology matches dev but uses larger instance
  types as parameterized.

**Definition of Done**

- Modules under `infra/terraform/modules/{network,eks,rds,msk}`.
- `infra/terraform/envs/{dev,stage,prod}` example wiring.
- `README.md` with cost estimate per environment.
- Linted with `tflint` + `terraform fmt -check` in CI.

**Story Points**: 8

---

## CG-002 — Migrate Jenkinsfiles to GitLab CI

> **As a** DevOps Engineer, **I want** the same dev/stage/master pipelines
> expressed as GitLab CI YAML, **so that** we run on a single CI platform with
> less infrastructure to maintain.

**Acceptance Criteria**

- *Given* a push to any `feature/*` branch, *when* the MR pipeline runs,
  *then* `build → unit → integration → lint → security-scan` stages all execute.
- *Given* a merge to `develop`, *when* the pipeline finishes green,
  *then* the dev cluster is updated within 10 minutes.
- *Given* a tag `v*` on `main`, *when* the master pipeline runs,
  *then* the prod deploy job is *gated by a manual approval* step.

**Definition of Done**

- `.gitlab-ci.yml` plus `.gitlab/ci/*.yml` includes per concern.
- Old `Jenkinsfile.*` retained for one sprint as fallback.
- Equivalence test: same git SHA produces identical container digests in both pipelines.

**Story Points**: 5

---

## CG-003 — Document GitFlow branching strategy

> **As a** new contributor, **I want** an authoritative branching guide,
> **so that** I never push to the wrong branch or invent a private convention.

**Acceptance Criteria**

- *Given* the `docs/BRANCHING.md` document, *when* I read section 2,
  *then* I see a Mermaid diagram that renders in GitLab.
- *Given* I want to make a hotfix, *when* I follow section 6,
  *then* the example produces a tagged `vX.Y.Z+1` on `main`.
- *Given* I open an MR with a non-Conventional-Commit title, *when* CI runs,
  *then* commitlint blocks the merge with a clear error.

**Definition of Done**

- Reviewed by advisor.
- Linked from root `README.md`.
- Mermaid renders correctly in GitLab preview.

**Story Points**: 2

---

## CG-004 — Set up GitLab Issue / MR templates

> **As an** IT Admin, **I want** standardized issue and MR templates,
> **so that** every change carries the same metadata for change-management
> auditing.

**Acceptance Criteria**

- *Given* I click "New Issue" in GitLab, *when* I pick a template,
  *then* `feature`, `bug`, and `tech_debt` options appear.
- *Given* I open an MR, *when* the editor loads,
  *then* the default template prefills summary, testing, checklist sections.
- *Given* a reviewer opens the MR, *when* they read the checklist,
  *then* CI status, docs, and linked-issue boxes are explicit.

**Definition of Done**

- Files exist under `.gitlab/issue_templates/` and `.gitlab/merge_request_templates/`.
- Verified that GitLab picks them up (advisor screenshot).

**Story Points**: 2

---

## CG-005 — Bootstrap Scrum board with milestones

> **As a** Scrum Master, **I want** a GitLab board with one column per Scrum
> state and a milestone per sprint, **so that** stand-ups can be run from a
> single URL with no spreadsheets.

**Acceptance Criteria**

- *Given* the project board, *when* I open it, *then* columns are
  `Backlog | Ready | In Progress | In Review | Done`.
- *Given* a story labelled `Sprint 1`, *when* I drag it to In Progress,
  *then* the linked GitLab issue gets the same status.
- *Given* the milestone burndown, *when* I refresh it daily,
  *then* the chart reflects closed issues.

**Definition of Done**

- Board labels and columns documented in `docs/AGILE_METHODOLOGY.md`.
- Two milestones created (`Sprint 1`, `Sprint 2`) with dates.

**Story Points**: 2

---

## CG-006 — Sprint 1 planning + retrospective notes

> **As a** Product Owner, **I want** planning and retrospective notes captured
> in version control, **so that** decisions and improvements are auditable.

**Acceptance Criteria**

- *Given* the file `docs/SPRINTS.md`, *when* I open Sprint 1,
  *then* I see goal, capacity, backlog, review, retrospective.
- *Given* the retrospective, *when* I read it,
  *then* there is at least one action item with an owner.
- *Given* Sprint 1 carryover, *when* I read Sprint 2,
  *then* the carried-over story appears in its backlog with a "(carryover)" tag.

**Definition of Done**

- File reviewed by advisor.
- Retrospective actions referenced by story IDs.

**Story Points**: 1

---

## CG-007 — Saga pattern across form → promotion → notification

> **As an** IT Admin, **I want** the cross-service workflow to use the Saga
> pattern with compensating actions, **so that** a partial failure never
> leaves the contact graph inconsistent.

**Acceptance Criteria**

- *Given* a successful survey submission, *when* downstream notification fails,
  *then* the saga emits a compensating `promotion.revert` event and the user
  is not silently fenced.
- *Given* the saga state machine, *when* a step times out (> 30 s),
  *then* the orchestrator retries with exponential backoff up to 3 times.
- *Given* a happy-path run, *when* I inspect the audit log,
  *then* I see a single correlation ID across all three services.

**Definition of Done**

- Saga state diagram in `docs/architecture/sagas.md`.
- Unit tests for compensating steps.
- Integration test reproduces the failure path.

**Story Points**: 5

---

## CG-008 — Circuit-breaker on identity REST calls

> **As an** IT Admin, **I want** the auth-service to short-circuit calls to a
> failing identity-service, **so that** the user-visible login latency does not
> exceed 1 s even when identity is degraded.

**Acceptance Criteria**

- *Given* identity-service returning 5xx, *when* the breaker hits 50% errors in
  10 s, *then* it opens and subsequent calls fail fast (< 50 ms).
- *Given* the breaker is open, *when* the half-open probe succeeds twice,
  *then* the breaker closes again.
- *Given* the breaker is open, *when* a user attempts login, *then* a clear
  503 with `Retry-After` is returned (no stack trace).

**Definition of Done**

- Resilience4j config in `application.yml`.
- Micrometer metrics exposed at `/actuator/metrics`.
- Chaos test (kill identity pod) in `tests/chaos/`.

**Story Points**: 3

---

## CG-009 — OpenTelemetry traces exported to Tempo

> **As a** DevOps Engineer, **I want** distributed traces for every request,
> **so that** I can debug cross-service latency without grepping logs.

**Acceptance Criteria**

- *Given* a survey submission, *when* I open Tempo, *then* a single trace
  spans form → Kafka → promotion → notification.
- *Given* a trace, *when* I click a span, *then* the parent service name,
  duration, and HTTP status are visible.
- *Given* a Kafka consumer span, *when* I inspect attributes,
  *then* `messaging.kafka.partition` and `messaging.kafka.offset` are present.

**Definition of Done**

- All seven services autoinstrumented via OTel agent.
- Sampling at 10% (configurable per env).
- Documented in `docs/observability.md`.

**Story Points**: 5

---

## CG-010 — Prometheus / Grafana dashboards per service

> **As an** IT Admin, **I want** a Grafana dashboard per service,
> **so that** I can answer "is X healthy right now" in under a minute.

**Acceptance Criteria**

- *Given* the dashboards folder, *when* a service is added,
  *then* a templated dashboard is auto-provisioned via `grafana-dashboards/`.
- *Given* the gateway-service dashboard, *when* I open it,
  *then* I see RPS, p50/p95/p99 latency, error %, and JVM heap.
- *Given* a sustained 5xx spike, *when* the dashboard refreshes,
  *then* the error % panel turns red within 15 s.

**Definition of Done**

- Dashboards stored as JSON in `infra/grafana/dashboards/`.
- Provisioned via the `grafana-operator`.

**Story Points**: 3

---

## CG-011 — SLO burn-rate alerts

> **As a** DevOps Engineer, **I want** burn-rate alerts based on the published
> SLOs, **so that** I'm paged before users notice degradation.

**Acceptance Criteria**

- *Given* the SLO `gate-validate p95 < 200 ms`, *when* the 1h burn rate exceeds
  14.4x, *then* a PagerDuty incident is opened (Sev-1).
- *Given* a 6h burn-rate > 6x, *when* the rule fires,
  *then* a Slack message is sent to `#circleguard-ops` (Sev-2).
- *Given* alerts fire, *when* the issue resolves, *then* a PagerDuty resolve
  webhook closes the incident automatically.

**Definition of Done**

- PrometheusRule manifests under `k8s/observability/alerts/`.
- Runbook link in alert annotations.

**Story Points**: 3

---

## CG-012 — Health Center officer promotes Suspect → Confirmed

> **As a** Health Center Officer, **I want** a console where I can promote a
> de-identified Suspect node to Confirmed, **so that** the cascading fences
> reach all contacts within 60 seconds.

**Acceptance Criteria**

- *Given* I am authenticated as Health Center Officer, *when* I open the
  console, *then* I see only de-identified hash IDs and no real names.
- *Given* a Suspect node, *when* I click "Promote to Confirmed",
  *then* the Promotion service receives the event and cascades within 60 s
  (measurable via the SLO dashboard).
- *Given* I am not authorized, *when* I open the console,
  *then* I receive HTTP 403 with no node data leaked.

**Definition of Done**

- UI under `mobile/app/(health-center)/`.
- E2E test in `tests/e2e/test_promote_to_confirmed.py`.
- RBAC enforced at API and UI layers.

**Story Points**: 8

---

## CG-013 — Student daily symptom check-in UX polish

> **As a** Student, **I want** the daily symptom survey to take fewer than
> 30 seconds to complete, **so that** I actually fill it in rather than skipping.

**Acceptance Criteria**

- *Given* I open the app at 7 AM, *when* the survey screen renders,
  *then* it is interactive in under 1.5 s on a low-end Android.
- *Given* I have answered "no symptoms" yesterday, *when* I open it today,
  *then* defaults are pre-selected to "no" and I can submit in 2 taps.
- *Given* I submit, *when* the network is offline, *then* the response is
  queued and synced when connectivity returns.

**Definition of Done**

- Lighthouse mobile performance score ≥ 90.
- Offline queue covered by Detox test.

**Story Points**: 3

---

## CG-014 — k6 + Locust comparative perf suite

> **As a** Security Officer, **I want** load tests run by two independent
> tools, **so that** we don't trust a single framework's numbers when signing
> off on a release.

**Acceptance Criteria**

- *Given* the stage pipeline, *when* it runs,
  *then* both `locust` and `k6` execute the same scenario.
- *Given* both runs complete, *when* I open the comparison report,
  *then* p95 latencies differ by less than 10% between tools.
- *Given* either tool fails the SLO, *when* the master pipeline runs,
  *then* the release is blocked.

**Definition of Done**

- `tests/performance/k6/` parallel to existing `locustfile.py`.
- Comparison report committed to `results/`.

**Story Points**: 3

---

## CG-015 — Pen-test report against identity vault

> **As a** Security Officer, **I want** an annual penetration test against the
> identity vault that verifies the zero-real-name guarantee, **so that** we
> can prove FERPA compliance to the university board.

**Acceptance Criteria**

- *Given* the pen-test scope, *when* the tester probes the contact graph,
  *then* no real student name is recoverable.
- *Given* the report, *when* a Critical or High finding exists,
  *then* a corresponding GitLab issue is opened within 24 h.
- *Given* a Medium finding, *when* it appears in the report,
  *then* it is added to the next sprint's backlog at refinement.

**Definition of Done**

- Signed PDF stored in `docs/security/pentest-<date>.pdf` (encrypted).
- Findings tracked as GitLab issues with `security` label.

**Story Points**: 3

---

## CG-016 — Pre-commit hooks (lint, secret-scan, commitlint)

> **As a** DevOps Engineer, **I want** pre-commit hooks that run lint,
> commitlint and secret-scan, **so that** I never push broken or sensitive
> material to the remote.

**Acceptance Criteria**

- *Given* a commit with a hard-coded AWS key, *when* I run `git commit`,
  *then* the hook blocks with a redacted match.
- *Given* a commit message `wip: stuff`, *when* the hook runs,
  *then* it rejects with "type must be one of feat|fix|…".
- *Given* a clean commit, *when* the hook runs,
  *then* it completes in under 5 s.

**Definition of Done**

- `.pre-commit-config.yaml` checked in.
- Documented in `README.md` quickstart.

**Story Points**: 3

---

## CG-017 — Centralized `gradle-version-catalog.toml`

> **As a** DevOps Engineer, **I want** a single Gradle version catalog,
> **so that** all eight services upgrade dependencies in lockstep.

**Acceptance Criteria**

- *Given* a Spring Boot version bump, *when* I edit the catalog,
  *then* every service picks it up on its next build.
- *Given* a build, *when* it runs, *then* no service declares a version
  string inline.
- *Given* Renovate-bot opens an upgrade MR, *when* CI runs,
  *then* every service builds against the new version.

**Definition of Done**

- File at `gradle/libs.versions.toml`.
- Sub-project `build.gradle.kts` files migrated.

**Story Points**: 3

---

## CG-018 — Container image SBOM + vulnerability scan in CI

> **As a** Security Officer, **I want** every container image to ship with an
> SBOM and a clean vulnerability scan, **so that** we know exactly what's in
> production and that no Critical CVEs are present.

**Acceptance Criteria**

- *Given* a build, *when* it finishes, *then* a CycloneDX SBOM is attached as
  a CI artifact.
- *Given* a scan that finds a Critical CVE, *when* the MR pipeline runs,
  *then* the merge is blocked with a link to the offending package.
- *Given* an accepted-risk CVE, *when* it is added to `.trivyignore`,
  *then* the scan passes again with the exception logged in the MR description.

**Definition of Done**

- `syft` + `trivy` integrated in the `security-scan` CI stage.
- Documented exception process.

**Story Points**: 5

---

## CG-019 — Branch-protection rules on `main` and `develop`

> **As an** IT Admin, **I want** GitLab branch protection enforced on `main`
> and `develop`, **so that** no one accidentally pushes or force-pushes to
> production-impacting branches.

**Acceptance Criteria**

- *Given* a maintainer, *when* they try to `git push origin main`,
  *then* the push is rejected.
- *Given* an MR with a failing pipeline, *when* I click Merge,
  *then* the button is disabled until CI passes.
- *Given* a code-owner-required path, *when* an MR touches it,
  *then* approval from a code owner is mandatory.

**Definition of Done**

- Settings exported as Terraform `gitlab_branch_protection` resource.
- Screenshot captured for the audit folder.

**Story Points**: 1

---

## CG-020 — GraphQL bonus endpoint on dashboard-service

> **As a** Health Center Officer, **I want** a GraphQL endpoint that lets me
> query the analytics graph with arbitrary shapes, **so that** I can prototype
> reports without asking engineering for new REST endpoints.

**Acceptance Criteria**

- *Given* the GraphQL endpoint, *when* I issue an introspection query,
  *then* the full schema is returned.
- *Given* a query for `campusSummary(window: "7d")`, *when* it runs,
  *then* the response matches the REST equivalent within 5%.
- *Given* a query depth > 6, *when* it runs,
  *then* it is rejected with `BadRequest` to prevent DOS.

**Definition of Done**

- spring-graphql wired into dashboard-service.
- Integration test covering depth-limit.

**Story Points**: 3

---

## Backlog (not yet committed)

| ID     | Title                                              | Role               | Points |
|--------|----------------------------------------------------|--------------------|-------:|
| CG-021 | Terraform cost-estimate in module README           | DevOps Engineer    | 2      |
| CG-022 | LMS integration for remote attendance              | Student            | 8      |
| CG-023 | Off-campus BLE peer-to-peer circle detection       | Student            | 13     |
| CG-024 | Right-to-be-forgotten self-service workflow        | Student            | 5      |
| CG-025 | WiFi AP triangulation ingestion service            | IT Admin           | 8      |

These will be groomed in upcoming refinement sessions.
