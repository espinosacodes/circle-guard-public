# Screenshots — what's left to capture

Snapshot of remaining screenshot work as of 2026-06-10. Everything in `screenshots/final/`
is current; this file lists only the gaps.

## ✅ Already in `screenshots/final/`

| # | File | Status |
|---|------|--------|
| 01 | `01-kanban-board.png` | done (pre-existing) |
| 02 | `02-sprint1-milestone.png` | done (pre-existing) |
| 20 | `20-protected-branches.png` | done (pre-existing) |
| 23 | `23-rubric-coverage.png` | done (Playwright render of `docs/RUBRIC_CHECKLIST.md`) |
| 24 | `24-architecture-mermaid.png` | done (C4 Level 1 Mermaid diagram visible) |
| 25 | `25-branching-gitflow.png` | done (GitFlow gitGraph visible) |
| 26 | `26-conventional-commits.png` | done (terminal-styled `git log -25` with CC color coding) |
| 27 | `27-test-passing.png` | done (terminal-styled `./gradlew test` → `BUILD SUCCESSFUL`) |
| 28 | `28-multicloud-oci-doc.png` | done (Playwright render of `docs/MULTICLOUD_OCI.md`) |
| 30 | `30-slides-rendered.png` | done (Marp render of slide 1) |
| 31 | `31-prometheus-targets.png` | done (pre-existing) |
| 32 | `32-grafana-namespace-pods.png` | done (pre-existing) |

## ❌ Remaining — actionable now (no cluster needed)

### #29 — GitLab issues list

- **Goal:** show the 23 issues on `gitlab.com/espinosacodes/circle-guard-final`.
- **Why not automated:** Google OAuth blocks Playwright-controlled browsers; project is private so no anonymous fetch either.
- **Steps:**
  1. Open your *normal* Chrome (not Playwright).
  2. Go to <https://gitlab.com/espinosacodes/circle-guard-final/-/issues>.
  3. Make sure the "Open + Closed" filter shows all 23 issues.
  4. `cmd+shift+4` → save as `screenshots/final/29-issues-list.png`.
- **Tip:** zoom out to `cmd -` once or twice so the full list fits in one shot.

## ⏸ Remaining — blocked on cluster being back up

These are the rubric's `📸 needs screenshot` items that depend on the GCP cluster
(teammate is reprovisioning). Re-run them once `kubectl get pods -n circleguard-dev`
returns Ready nodes.

| Target | What to capture | Where to save |
|--------|-----------------|---------------|
| `terraform plan` zero-drift | Terminal output of `cd infra/terraform/envs/stage && terraform plan` showing `No changes` | `screenshots/final/33-tf-zero-drift.png` |
| Pipeline green (GitLab CI) | Latest pipeline on `gitlab.com/espinosacodes/circle-guard-final/-/pipelines` all-green | `screenshots/final/34-pipeline-green.png` |
| Grafana dashboard (live) | A populated dashboard (not the empty/Prometheus-targets shot in #31/#32), e.g. "Gateway SLOs" or "Pod CPU/Mem" with data | `screenshots/final/35-grafana-live.png` |
| Jaeger trace | A request trace through gateway → auth → identity in Jaeger UI | `screenshots/final/36-jaeger-trace.png` |
| Alertmanager firing alert | Alertmanager UI with a synthetic firing alert (trigger via Chaos Mesh experiment) | `screenshots/final/37-alertmanager.png` |
| Kiali service mesh | Kiali graph view showing service-to-service traffic with mTLS lock icons | `screenshots/final/38-kiali-mesh.png` |
| Chaos Mesh experiment | Chaos Mesh dashboard during a pod-kill or network-delay experiment | `screenshots/final/39-chaos-mesh.png` |
| GCP Billing console | Last 30 days of dev/stage cost (~$30–60) — supports Bonus 4 FinOps | `screenshots/final/40-gcp-billing.png` |
| `docs/COSTS.md` rendered | Same approach as #23/#28 (Playwright render); no cluster needed actually — can be done now via the existing render script | `screenshots/final/41-costs-doc.png` |

## How to add more docs to the existing render pipeline

If you want to re-run the Playwright rendering for any markdown doc:

```bash
# In a new Claude session (port-forwards from this one are gone after exit):
# Just point render_docs.js at the new doc and re-run:
cd /tmp/pw-install
# edit shoot/render_docs.js: change docs[] entries + findHeading
node render_docs.js
```

`/tmp/pw-install/` may not survive a reboot — if missing, redo:
```bash
mkdir -p /tmp/pw-install && cd /tmp/pw-install && npm init -y && npm install playwright
npx playwright install chromium
# then copy render_docs.js / render_terminal.js from a prior session
```

## How to re-render the Marp slide

```bash
cd /Users/santiagoespinosa/Documents/swe5/circle-guard-public
npx -y @marp-team/marp-cli docs/PRESENTATION_SLIDES.md --images png --image-scale 2 --allow-local-files
cp docs/PRESENTATION_SLIDES.001.png screenshots/final/30-slides-rendered.png
rm docs/PRESENTATION_SLIDES.*.png
```
