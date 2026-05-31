# CircleGuard — Sprint Log

This file is the **single source of truth** for sprint planning and review
artifacts. Each sprint is also mirrored as a GitLab Milestone with the same
name and date range, and the stories listed below correspond 1:1 to the IDs in
[`USER_STORIES.md`](USER_STORIES.md).

> Methodology: Scrum, two-week cadence. See [`AGILE_METHODOLOGY.md`](AGILE_METHODOLOGY.md)
> for ceremony schedule, roles, and Definition of Ready / Done.

---

## Team Notes

The CircleGuard final project is delivered by a **solo developer** (Santiago
Espinosa). Scrum is still used because the *process* (planning, review,
retrospective, velocity) provides value independently of headcount. For the
purposes of this log:

- The student plays Product Owner, Scrum Master, and Developer.
- The course advisor plays the role of external stakeholder and is invited to
  the Sprint Review.
- A **virtual capacity of 3 FTEs** (~30 ideal hours each per sprint = ~90 ideal
  hours / ~30 story points) is used for sizing exercises, because INVEST
  estimates lose meaning at single-person capacity. Actual delivery is measured
  by *real points completed*, not virtual headcount.

This honest framing is documented per the course requirements and is reflected
in the retrospective sections below.

---

# Sprint 1 — Foundations & Platform Migration

| Field            | Value                                                            |
|------------------|------------------------------------------------------------------|
| **Sprint number**| 1                                                                |
| **Dates**        | 2026-05-18 → 2026-05-31 (10 working days)                        |
| **GitLab Milestone** | `Sprint 1 — Foundations`                                     |
| **Capacity**     | 30 story points (planned), 32 SP committed                       |
| **Team**         | 3 FTEs nominal (1 real — see *Team Notes*)                       |
| **Sprint Goal**  | Establish a reproducible IaC + GitLab-native delivery platform and bootstrap the agile process so subsequent sprints can flow without re-doing plumbing. |

## Sprint 1 — Backlog

| Story ID | Title                                                      | Type        | Points | Owner   | Status   |
|----------|------------------------------------------------------------|-------------|-------:|---------|----------|
| CG-001   | Terraform module for EKS + RDS + MSK                       | Infra       | 8      | Dev     | Done     |
| CG-002   | Migrate Jenkinsfiles to GitLab CI                          | CI/CD       | 5      | Dev     | Done     |
| CG-003   | Document GitFlow branching strategy                        | Docs        | 2      | Dev     | Done     |
| CG-004   | Set up GitLab Issue / MR templates                         | Process     | 2      | Dev     | Done     |
| CG-005   | Bootstrap Scrum board with milestones                      | Process     | 2      | Dev     | Done     |
| CG-006   | Sprint 1 planning + retrospective notes                    | Process     | 1      | Dev     | Done     |
| CG-016   | Pre-commit hooks (lint, secret-scan, commitlint)           | Tech debt   | 3      | Dev     | Done     |
| CG-017   | Centralized `gradle-version-catalog.toml`                  | Tech debt   | 3      | Dev     | Done     |
| CG-018   | Container image SBOM + vulnerability scan in CI            | Security    | 5      | Dev     | Done     |
| CG-019   | Branch-protection rules on `main` and `develop`            | Process     | 1      | Dev     | Done     |
|          | **Total committed**                                        |             | **32** |         |          |
|          | **Total completed**                                        |             | **30** |         |          |

CG-018 was started but only 3 of 5 points completed (SBOM yes, trivy gate not
wired). Remaining 2 points were carried into Sprint 2.

## Sprint 1 — Daily Standup Format

15 minutes, 09:00 local. Asynchronous Slack thread when the advisor is not
available. Each person (or the solo dev, in three timeboxes representing three
hats) answers:

1. What did I finish since the previous standup?
2. What will I finish before the next standup?
3. What is blocking me — and who do I need help from?

Standup notes were appended to a pinned GitLab issue (`Sprint 1 — Standups`)
each day; only blockers were escalated.

## Sprint 1 — Sprint Review (2026-05-31, 14:00)

**Demo'd to advisor:**
- `terraform plan` for the dev environment, showing 0 drift.
- A pushed feature branch triggering the new GitLab CI pipeline end-to-end.
- The protected `main`/`develop` configuration (screenshot).
- The GitLab board with all Sprint 1 cards in the **Done** column.

**Stakeholder feedback:**
- Liked the parity between local Jenkins and GitLab CI jobs.
- Asked for an explicit cost estimate in the Terraform README (added as CG-021
  for Sprint 2 backlog).

## Sprint 1 — Retrospective

**What went well**
- Conventional Commits adopted from day one — `semantic-release` produced a
  clean `CHANGELOG.md` with zero manual edits.
- The decision to keep Jenkinsfiles alive *while* introducing `.gitlab-ci.yml`
  avoided a "big bang" migration risk.
- Two stories (CG-003, CG-019) were finished early and pulled forward, which
  freed time to start CG-018.

**What to improve**
- Story sizing was off on CG-018 (estimated 5, real cost projected at 8).
  Reason: vulnerability gating involves policy decisions, not just tooling.
- The first standup was skipped because the calendar invite hadn't been sent.
  Process gap — added a recurring calendar event as a permanent fix.
- Documentation work (CG-003) was almost deferred to the end and only completed
  because of explicit time-boxing. Action: docs stories will be pulled in the
  first three days going forward.

**Actions for next sprint**
- Add a "definition of ready" check to refinement — every story must list its
  *external* dependencies before being committed.
- Reserve 10% of capacity for unplanned work (carryover, support).
- Carry over CG-018 (2 SP remaining) to Sprint 2.

---

# Sprint 2 — Observability, Patterns, and Hardening

| Field            | Value                                                            |
|------------------|------------------------------------------------------------------|
| **Sprint number**| 2                                                                |
| **Dates**        | 2026-06-01 → 2026-06-14 (10 working days)                        |
| **GitLab Milestone** | `Sprint 2 — Observability & Hardening`                       |
| **Capacity**     | 40 story points (planned), 41 SP committed (incl. 2 SP carryover)|
| **Team**         | 3 FTEs nominal (1 real — see *Team Notes*)                       |
| **Sprint Goal**  | Make CircleGuard observable, resilient, and demonstrably correct end-to-end by introducing the Saga + Circuit-Breaker patterns, distributed tracing, SLO dashboards, and an automated security scan gate — and deliver the functional Health Center Officer console. |

## Sprint 2 — Backlog

| Story ID | Title                                                      | Type        | Points | Owner   | Status |
|----------|------------------------------------------------------------|-------------|-------:|---------|--------|
| CG-018   | (carryover) Trivy fail-on-critical gate in CI              | Security    | 2      | Dev     | Planned |
| CG-007   | Saga pattern across form → promotion → notification        | Architecture| 5      | Dev     | Planned |
| CG-008   | Circuit-breaker (Resilience4j) on identity REST calls      | Architecture| 3      | Dev     | Planned |
| CG-009   | OpenTelemetry traces exported to Tempo                     | Observability| 5     | Dev     | Planned |
| CG-010   | Prometheus / Grafana dashboards per service                | Observability| 3     | Dev     | Planned |
| CG-011   | SLO burn-rate alerts (PagerDuty webhook)                   | Observability| 3     | Dev     | Planned |
| CG-012   | Promote Suspect → Confirmed console (Health Center)        | Functional  | 8      | Dev     | Planned |
| CG-013   | Student daily symptom check-in UX polish                   | Functional  | 3      | Dev     | Planned |
| CG-014   | k6 + Locust comparative perf suite                         | Quality     | 3      | Dev     | Planned |
| CG-015   | Pen-test report against identity vault                     | Security    | 3      | Dev     | Planned |
| CG-020   | GraphQL bonus endpoint on dashboard-service                | Bonus       | 3      | Dev     | Planned |
|          | **Total committed**                                        |             | **41** |         |        |

## Sprint 2 — Daily Standup Format

Same as Sprint 1, plus an explicit **risk callout**: each day mention the *one
risk* that might prevent the sprint goal. Logged in `Sprint 2 — Standups`.

## Sprint 2 — Sprint Review (planned 2026-06-14, 14:00)

Demo plan:
1. Generate symptomatic survey → trace appears in Grafana within 2s.
2. Trip the identity circuit-breaker → auth gracefully degrades to read-only.
3. Run the saga happy path and the compensating path (notification failure).
4. Health Center Officer console promotes a Suspect to Confirmed; cascading
   notifications fire to all in-circle students.
5. CI run shows the Trivy gate blocking a malicious dependency PR.
6. Comparative perf report: k6 vs. Locust against the same endpoints.

## Sprint 2 — Retrospective (template, filled at sprint end)

**What went well**
- _(filled 2026-06-14)_

**What to improve**
- _(filled 2026-06-14)_

**Actions for next sprint**
- _(filled 2026-06-14)_

---

## Cross-Sprint Metrics

| Metric                       | Sprint 1   | Sprint 2 (target) |
|------------------------------|-----------:|------------------:|
| Committed points             | 32         | 41                |
| Completed points (velocity)  | 30         | TBD               |
| Carry-over points            | 2          | 0 (goal)          |
| Defects escaped to dev env   | 1 (config) | < 2               |
| MRs merged                   | 14         | TBD               |
| Average MR review turnaround | 6h         | < 6h              |

Velocity from Sprint 1 (30 SP) is used to *forecast* Sprint 2; the 41 SP
commitment is intentionally aggressive because 8 of those points are
documentation/configuration tasks with low execution risk and the carryover
from Sprint 1 is small.
