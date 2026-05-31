<!--
Default Merge Request template.
Title MUST follow Conventional Commits: type(scope): summary
e.g. feat(promotion): cascade suspect -> probable in <60s
See docs/BRANCHING.md § 4.
-->

## Summary

<!-- One paragraph explaining WHY this change exists. The diff explains WHAT. -->

## Linked Issue

Closes #CG-NNN

## Changes

<!-- Bullet the meaningful changes. Group by service if multi-service. -->

- `services/circleguard-<service>/`: …
- `k8s/<env>/`: …
- `docs/`: …
- `tests/`: …

## Screenshots / Recordings

<!-- UI changes? Console output? Grafana panel? Drop them in here. Delete the section if not applicable. -->

## Testing Done

- [ ] `./gradlew :services:<svc>:test`
- [ ] `pytest tests/integration/<file>`
- [ ] `pytest tests/e2e/<file>`
- [ ] Manual smoke against `circleguard-dev`
- [ ] Performance impact verified (Locust / k6) — N/A if no hot path touched

Paste relevant output:

```
<test output, smoke screenshot, etc.>
```

## Rollback Plan

<!-- Required for change-type::normal and ::emergency. -->

<!-- Default to `kubectl rollout undo` — replace with specifics if anything more is needed. -->

```bash
kubectl -n circleguard-master rollout undo deployment/<service>
```

See `docs/CHANGE_MANAGEMENT.md § 3` for the full template.

## Change Type

- [ ] `change-type::standard` — pre-approved, low-risk
- [ ] `change-type::normal` — needs CAB review at Sprint Review
- [ ] `change-type::emergency` — hotfix path

## Pre-merge Checklist

- [ ] MR title follows Conventional Commits (`feat:`, `fix:`, `chore:`, …)
- [ ] CI pipeline is **green** (all stages: build, unit, integration, lint, security-scan)
- [ ] At least one reviewer approval (two for `release/*` / `hotfix/*`)
- [ ] No new Critical/High CVEs introduced (Trivy report attached if non-trivial deps changed)
- [ ] Tests added/updated for new or changed behavior
- [ ] Docs updated (`docs/`, `README.md`, OpenAPI) in this same MR
- [ ] Telemetry added: ≥ 1 metric + ≥ 1 log line for new boundary code paths
- [ ] Linked issue exists and is in the current sprint milestone
- [ ] Rollback plan filled in (above)
- [ ] No commented-out code, no `TODO` without an issue reference

/assign me
