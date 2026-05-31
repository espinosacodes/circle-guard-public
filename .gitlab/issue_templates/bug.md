<!-- Bug report template. Fill in all sections — empty bugs get closed. -->

## Bug ID

CG-NNN

## Summary

<!-- One sentence: what is broken, where, and for whom. -->

## Environment

- Environment: `circleguard-dev` | `circleguard-stage` | `circleguard-master`
- Service(s): <auth | identity | form | promotion | notification | gateway | dashboard | file>
- Version / git SHA: <vX.Y.Z or short SHA>
- Discovered by: <self | user report | monitoring | CI>

## Steps to Reproduce

1. …
2. …
3. …

## Expected Behavior

<!-- What should have happened. Reference the user story or acceptance criterion. -->

## Actual Behavior

<!-- What happened instead. Include error messages, log lines, screenshots. -->

```
<stack trace, log excerpt, response body, etc.>
```

## Impact

- Severity: `S1 — outage` | `S2 — major degradation` | `S3 — workaround exists` | `S4 — cosmetic`
- Users affected: <count / percentage / personas>
- Data integrity risk: yes / no — <details>

## Hypothesis (optional)

<!-- Where do you think the bug lives? Helps the next engineer. -->

## Acceptance Criteria for Fix

- **Given** <reproduced state>
  **When** the fix is applied
  **Then** the issue no longer reproduces.
- **Given** the regression test suite
  **When** it runs in CI
  **Then** a new test covering this bug passes (and would have failed before the fix).
- **Given** related code paths
  **When** I review the fix
  **Then** no new regressions are introduced.

## Definition of Done

- [ ] Reproduction documented and attached.
- [ ] Regression test added — fails on the broken version, passes on the fix.
- [ ] Root cause documented in the MR description.
- [ ] Telemetry added or improved so a recurrence would be caught earlier.
- [ ] Closes this issue via `Closes #CG-NNN`.

## Estimation

- Story points: <1 | 2 | 3 | 5 | 8>
- Change type: `standard` | `normal` | `emergency` (see `docs/CHANGE_MANAGEMENT.md`)

/label ~"type::bug"
