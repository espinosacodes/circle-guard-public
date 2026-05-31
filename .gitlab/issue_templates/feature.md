<!-- Feature / User Story template — see docs/USER_STORIES.md for guidance. -->

## Story ID

CG-NNN  <!-- assign the next free number from docs/USER_STORIES.md -->

## User Story

**As a** <role: Health Center Officer | Student | IT Admin | DevOps Engineer | Security Officer>
**I want** <capability>
**so that** <benefit>.

## Background / Context

<!-- Why now? What does this unblock? Link related issues or design docs. -->

## Acceptance Criteria

- **Given** <context>
  **When** <action>
  **Then** <observable outcome>
- **Given** <…>
  **When** <…>
  **Then** <…>
- **Given** <…>
  **When** <…>
  **Then** <…>

<!-- Add more as needed; minimum 3. -->

## Out of Scope

- <list explicit non-goals to avoid scope creep>

## Test Approach (one-liner)

<!-- e.g. "unit on the mapper + one integration test exercising Kafka round-trip". -->

## Definition of Done (story-level)

- [ ] All acceptance criteria demonstrated against `circleguard-dev`.
- [ ] Tests added (unit + integration where I/O is involved).
- [ ] Docs updated (`docs/`, OpenAPI, README as applicable).
- [ ] Telemetry added (≥ 1 metric + ≥ 1 log on new boundary paths).
- [ ] MR merged into `develop` with required approvals.
- [ ] Closes this issue via `Closes #CG-NNN` in the merge commit.

## Estimation

- Story points: <1 | 2 | 3 | 5 | 8>
- Sprint candidate: <Sprint 2 | Sprint 3 | Backlog>

## Labels to apply

`type::feature` `change-type::normal` `sprint::N` `role::<role>`

/label ~"type::feature"
