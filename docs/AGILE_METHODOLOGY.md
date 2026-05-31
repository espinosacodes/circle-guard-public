# CircleGuard — Agile Methodology

This document is the authoritative description of how the CircleGuard team
practices agile. Sprint plans live in [`SPRINTS.md`](SPRINTS.md), branching
rules in [`BRANCHING.md`](BRANCHING.md), and change/release procedure in
[`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md).

---

## 1. Framework Choice: Scrum (with Kanban-style flow inside the sprint)

We use **Scrum** as the primary framework, with two-week sprints. Kanban was
considered and rejected as the primary framework for the following reasons:

| Decision factor                              | Scrum                                  | Kanban                              |
|----------------------------------------------|----------------------------------------|-------------------------------------|
| Course requires *at least two sprints*       | Native concept                         | Would need to be retro-fitted       |
| Hard external deadline (final delivery date) | Aligns: each sprint moves toward it    | Continuous flow has no goal cadence |
| Demoable increment expected every two weeks  | Sprint Review built-in                 | No equivalent ceremony              |
| Velocity needs to be measured for the report | First-class metric                     | Throughput-based, less commonly taught |
| Solo developer with many concurrent concerns | Time-boxed planning forces focus       | Easy to chase shiny things          |

That said, *within* a sprint we apply Kanban principles: a column-based board
with explicit WIP limits and pull semantics, because the team is small enough
that strict story-by-story handoffs would create artificial idle time.

---

## 2. Roles

| Scrum role         | Real person                                 | Responsibilities (CircleGuard scope)                         |
|--------------------|---------------------------------------------|--------------------------------------------------------------|
| **Product Owner**  | Santiago (student)                          | Owns `USER_STORIES.md` order, accepts/rejects stories at Review. |
| **Scrum Master**   | Santiago (student)                          | Schedules ceremonies, removes impediments, owns retrospectives. |
| **Development Team** | Santiago (student)                        | Implements stories, writes tests, deploys.                   |
| **Stakeholder**    | Course advisor                              | Receives the sprint demo, gives directional feedback.        |
| **Users (proxy)**  | Health Center Officer / Student / IT Admin / DevOps Engineer / Security Officer personas | Embedded in user stories. |

The solo-developer reality is acknowledged honestly. Concretely, we *time-box*
ceremonies and *role-switch explicitly* (e.g., "the next 30 minutes I am wearing
the PO hat"), because skipping ceremonies because "I am the only person here"
would defeat the purpose of practicing the framework.

---

## 3. Ceremonies

All ceremonies are time-boxed; running over is treated as a process failure and
discussed at retrospective.

| Ceremony              | Cadence            | Duration  | Who                          | Artifact                                |
|-----------------------|--------------------|-----------|------------------------------|-----------------------------------------|
| **Backlog Refinement**| Wed of week 1, ad-hoc | 60 min  | PO + Dev                     | Updated story estimates                 |
| **Sprint Planning**   | Mon of week 1      | 90 min    | PO + SM + Dev (+ stakeholder optional) | Sprint Goal + committed backlog in `SPRINTS.md` |
| **Daily Standup**     | Every working day, 09:00 | 15 min| Dev (async Slack thread)      | Pinned `Sprint N — Standups` issue      |
| **Sprint Review**     | Fri of week 2, 14:00 | 60 min  | PO + Dev + stakeholder        | Demo + acceptance decisions             |
| **Sprint Retrospective** | Fri of week 2, 15:30 | 45 min | SM + Dev                    | Retro section in `SPRINTS.md` with actions |

Async standups are written, not videoed, so they double as an auditable record.

---

## 4. Definition of Ready (DoR)

A story is *ready to be pulled into a sprint* only if **all** of the following
are true:

- [ ] Has a Connextra-format user story (`As a … I want … so that …`).
- [ ] Has ≥ 3 Given/When/Then acceptance criteria.
- [ ] Has been estimated (story points), with no estimate > 8 (split if larger).
- [ ] External dependencies are identified and unblocked.
- [ ] No open clarifying questions on the issue.
- [ ] Test approach is sketched at least at one-liner level.

Stories failing DoR are sent back to refinement; they never make it into the
sprint plan.

## 5. Definition of Done (team-wide DoD)

A story is *Done* only if **all** of the following are true:

- [ ] Code merged to `develop` via MR, with at least one approval.
- [ ] All CI stages green (`build`, `unit`, `integration`, `lint`, `security-scan`).
- [ ] New code paths covered by unit and (where I/O is involved) integration tests; coverage does not decrease.
- [ ] Documentation updated in the same MR (README, OpenAPI, `docs/`, runbooks).
- [ ] Acceptance criteria demonstrated against the dev environment.
- [ ] Telemetry added: at least one metric and one log line for any new code path that touches an external boundary.
- [ ] Security checklist: no new secret in source, no new dependency with Critical/High CVE.
- [ ] Linked GitLab issue closed via the MR.

This DoD is **separate** from per-story Acceptance Criteria; both must be
satisfied.

---

## 6. Tooling

| Concern              | Tool                                              | Notes                                       |
|----------------------|---------------------------------------------------|---------------------------------------------|
| Backlog              | GitLab Issues                                     | One issue per user story, ID = `CG-NNN`.    |
| Sprint container     | GitLab Milestones                                 | One per sprint, dates as in `SPRINTS.md`.   |
| Visual board         | GitLab Boards (scoped by milestone label)         | Columns: Backlog / Ready / In Progress / In Review / Done. |
| Story templates      | `.gitlab/issue_templates/`                        | `feature.md`, `bug.md`, `tech_debt.md`.     |
| MR template          | `.gitlab/merge_request_templates/default.md`      | Auto-loaded by GitLab.                      |
| Burndown / velocity  | GitLab Milestone burndown chart                   | No external tool.                           |
| CI / CD              | GitLab CI (migrating from Jenkins per `CG-002`)   | See `.gitlab-ci.yml`.                       |
| Code coverage        | Jacoco → GitLab coverage badge                    | Visible on project front page.              |
| Chat                 | Project Slack channel `#circleguard`              | Standup thread pinned per sprint.           |

Concept reference (do not depend on a specific URL during grading):
- GitLab Issues — `https://docs.gitlab.com/ee/user/project/issues/`
- GitLab Boards — `https://docs.gitlab.com/ee/user/project/issue_board.html`
- GitLab Milestones — `https://docs.gitlab.com/ee/user/project/milestones/`

---

## 7. Velocity Tracking

We measure velocity in **story points completed per sprint**. Specifically:

- Only stories that meet the team-wide Definition of Done count.
- Partial credit is **not** awarded — a 5-point story that is "80% done" counts
  as 0 in the sprint that closes and 5 in the sprint where it actually finishes.
- The forecast for the next sprint uses the **3-sprint rolling average**, or
  the latest sprint's value when fewer than three sprints exist.
- Velocity is reported in the Sprint Review and in the *Cross-Sprint Metrics*
  table at the bottom of `SPRINTS.md`.

Velocity is a planning aid, not a performance target. It is never used to
compare team members.

---

## 8. CI/CD Integration with the Sprint

Branch lifecycle, environment promotion, and the sprint share the same rhythm.

| Sprint event                              | Git event             | Pipeline outcome                         | Environment    |
|-------------------------------------------|-----------------------|------------------------------------------|----------------|
| Story moves to In Progress                | `feature/*` branch created | Pipeline runs `build`, `unit`, `lint`       | none           |
| MR opened                                 | MR targeting `develop`    | Full MR pipeline (incl. integration + security-scan) | none |
| Story moves to Done                       | MR merged to `develop`    | Pipeline deploys to dev                  | `circleguard-dev` |
| Sprint feature-freeze (Wed of week 2)     | `release/v<x.y.z>` cut from `develop` | Pipeline deploys to stage + tags `vX.Y.Z-rc.1` | `circleguard-stage` |
| Sprint Review accepts release             | `release/v*` merged into `main`, tagged `vX.Y.Z` | Master pipeline deploys to prod with approval gate; emits release notes | `circleguard-master` |
| Hotfix during sprint                      | `hotfix/*` from `main`    | Out-of-band master pipeline run          | stage → prod   |

The principle: **branches encode lifecycle state; pipelines automate promotion;
sprints decide *what* gets promoted, not *how*.**

---

## 9. References

- Scrum Guide 2020 — `https://scrumguides.org/`
- INVEST criteria — Bill Wake, 2003.
- Conventional Commits 1.0 — `https://www.conventionalcommits.org/`
- Internal: [`SPRINTS.md`](SPRINTS.md), [`USER_STORIES.md`](USER_STORIES.md),
  [`BRANCHING.md`](BRANCHING.md), [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md).
