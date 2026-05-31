<!-- Tech debt template — use this for refactors, infra cleanups, test debt, doc debt. -->

## Item ID

CG-NNN

## Title

<short imperative description, e.g. "Replace custom retry loop with Resilience4j">

## User Story (internal)

**As a** DevOps Engineer | Developer | Security Officer
**I want** <code/infra/process change>
**so that** <forward-looking benefit: speed, safety, clarity, cost>.

## Current State

<!-- Describe the code or system as it is today. Link files/lines if helpful. -->

## Desired State

<!-- Describe what it should look like. -->

## Why Now?

<!-- What recently changed that makes this worth doing now (incident, sprint goal, dep upgrade)? -->

## Acceptance Criteria

- **Given** the current code path,
  **When** the refactor is merged,
  **Then** all existing tests still pass with no behavior change.
- **Given** the new code path,
  **When** I read the diff,
  **Then** it removes the documented duplication / antipattern listed above.
- **Given** the metric `<name>`,
  **When** I check it post-merge,
  **Then** it improves (or stays flat — never regresses).

## Risk

- Risk level: low | medium | high
- Mitigation: <feature flag | gradual rollout | dark launch | none needed>

## Definition of Done

- [ ] No behavior change (or behavior change explicitly documented and approved).
- [ ] All tests green; coverage does not decrease.
- [ ] Docs updated where the old behavior was documented.
- [ ] Closes this issue via `Closes #CG-NNN`.

## Estimation

- Story points: <1 | 2 | 3 | 5 | 8>
- Change type: typically `standard` or `normal`.

/label ~"type::tech-debt"
