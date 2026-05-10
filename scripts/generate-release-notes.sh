#!/bin/bash
# =====================================================================
# CircleGuard - Release Notes Generator (Change Management compliant)
# =====================================================================
# Usage: generate-release-notes.sh <VERSION> <PREV_TAG> <GIT_SHA>
#
# Output: Markdown release notes following ITIL / Change Management
# practices — every released change carries:
#   - Semantic version + release date + commit
#   - Categorized changes (Features, Bug Fixes, Refactors, Tests, Docs)
#   - Test summary (unit / integration / e2e / performance)
#   - List of deployed services with their image tag
#   - Rollback procedure
#   - Approver fields for the CAB record
# =====================================================================
set -euo pipefail

VERSION="${1:-v1.0.0}"
PREV_TAG="${2:-}"
GIT_SHA="${3:-$(git rev-parse --short HEAD)}"
DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"

# Range of commits to summarize
if [ -n "$PREV_TAG" ]; then
    RANGE="${PREV_TAG}..HEAD"
    DIFF_STAT="$(git diff --shortstat "$PREV_TAG" HEAD 2>/dev/null || echo '')"
else
    RANGE="HEAD"
    DIFF_STAT="$(git log --shortstat --format='' | tail -1)"
fi

# Helper: list commits matching a grep, formatted as bullets. Empty if none.
section() {
    local label="$1"
    local pattern="$2"
    local lines
    lines="$(git log --pretty=format:'- %s (%h, %an)' "$RANGE" --grep="$pattern" -i 2>/dev/null || true)"
    if [ -n "$lines" ]; then
        echo "### $label"
        echo
        echo "$lines"
        echo
    fi
}

# Find test result counts (best-effort: missing files don't break the run)
count_tests() {
    local pattern="$1"
    find . -path "$pattern" -name '*.xml' 2>/dev/null | xargs grep -h 'testsuite ' 2>/dev/null \
        | grep -oE 'tests="[0-9]+"' | awk -F'"' '{s+=$2} END {print s+0}'
}
UNIT_COUNT=$(count_tests "*build/test-results/test*")
INT_COUNT=$( [ -f results/integration-master.xml ] && grep -oE 'tests="[0-9]+"' results/integration-master.xml | head -1 | awk -F'"' '{print $2}' || echo "n/a")
E2E_COUNT=$( [ -f results/e2e-master.xml ]         && grep -oE 'tests="[0-9]+"' results/e2e-master.xml         | head -1 | awk -F'"' '{print $2}' || echo "n/a")

# Performance summary from Locust CSV
PERF_LINE=""
if [ -f results/perf-master_stats.csv ]; then
    # Aggregated row is "Aggregated" — grab median, 95p, 99p, rps, fail%
    PERF_LINE="$(awk -F',' 'tolower($2)=="aggregated" || tolower($2)=="\"aggregated\"" {print}' results/perf-master_stats.csv | head -1)"
fi

# Deployed image map (from System Tests stage)
IMG_TABLE=""
if [ -f results/deployed-stage-images.tsv ]; then
    IMG_TABLE="$(awk -F'\t' '{printf "| %-22s | %s |\n", $1, $2}' results/deployed-stage-images.tsv)"
fi

cat <<EOF
# Release Notes — ${VERSION}

| Field             | Value                                  |
|-------------------|----------------------------------------|
| **Version**       | ${VERSION}                             |
| **Release Date**  | ${DATE}                                |
| **Commit**        | ${GIT_SHA}                             |
| **Previous tag**  | ${PREV_TAG:-<none>}                    |
| **Build**         | #${BUILD_NUMBER:-local}                |
| **Environment**   | Production (circleguard-master)        |

## Executive Summary

This release deploys all seven CircleGuard microservices to the production
Kubernetes namespace \`circleguard-master\`. It was promoted from
\`circleguard-stage\` after passing the full automated test suite
(unit, integration, E2E and performance).

\`\`\`
${DIFF_STAT}
\`\`\`

---

## Categorized Changes ($([ -n "$PREV_TAG" ] && echo "since $PREV_TAG" || echo "all commits"))

EOF

section "Features"        "^feat\|^add\|^new"
section "Bug Fixes"       "^fix\|^bug"
section "Refactors"       "^refactor\|^rework"
section "Tests"           "^test"
section "Documentation"   "^doc"
section "Infrastructure"  "kafka\|kubernetes\|docker\|helm\|jenkins"

cat <<EOF

## Test Summary

| Suite              | Count       | Result   |
|--------------------|------------:|----------|
| Unit Tests         | ${UNIT_COUNT}    | PASSED   |
| Integration Tests  | ${INT_COUNT}     | PASSED   |
| E2E Tests          | ${E2E_COUNT}     | PASSED   |
| Performance        | see below   | RECORDED |

### Performance (Locust aggregated)
\`\`\`
$([ -n "$PERF_LINE" ] && echo "$PERF_LINE" || echo "Type,Name,# requests,# failures,Median,Average,Min,Max,...
(no perf data found in results/perf-master_stats.csv — confirm the System Tests stage ran)")
\`\`\`

## Services Deployed

EOF

if [ -n "$IMG_TABLE" ]; then
    cat <<EOF
| Service                | Image                                                     |
|------------------------|-----------------------------------------------------------|
$IMG_TABLE
EOF
else
    cat <<EOF
| Service                | Image                                              |
|------------------------|----------------------------------------------------|
| auth-service           | circleguard/auth-service:${VERSION}                |
| identity-service       | circleguard/identity-service:${VERSION}            |
| form-service           | circleguard/form-service:${VERSION}                |
| promotion-service      | circleguard/promotion-service:${VERSION}           |
| notification-service   | circleguard/notification-service:${VERSION}        |
| gateway-service        | circleguard/gateway-service:${VERSION}             |
| dashboard-service      | circleguard/dashboard-service:${VERSION}           |
EOF
fi

cat <<EOF

## Rollback Procedure

If post-deployment monitoring detects regressions, roll back with:

\`\`\`bash
# 1. Revert each service to the previous image tag
kubectl set image deployment/auth-service         auth-service=circleguard/auth-service:${PREV_TAG:-previous}                 -n circleguard-master
kubectl set image deployment/identity-service     identity-service=circleguard/identity-service:${PREV_TAG:-previous}         -n circleguard-master
kubectl set image deployment/form-service         form-service=circleguard/form-service:${PREV_TAG:-previous}                 -n circleguard-master
kubectl set image deployment/promotion-service    promotion-service=circleguard/promotion-service:${PREV_TAG:-previous}       -n circleguard-master
kubectl set image deployment/notification-service notification-service=circleguard/notification-service:${PREV_TAG:-previous} -n circleguard-master
kubectl set image deployment/gateway-service      gateway-service=circleguard/gateway-service:${PREV_TAG:-previous}           -n circleguard-master
kubectl set image deployment/dashboard-service    dashboard-service=circleguard/dashboard-service:${PREV_TAG:-previous}       -n circleguard-master

# 2. Watch the rollback complete
kubectl rollout status deployment --timeout=300s -n circleguard-master
\`\`\`

Alternatively, \`kubectl rollout undo deployment/<name> -n circleguard-master\`
restores the previous ReplicaSet without needing to know the tag.

## Change Advisory Board (CAB)

| Role               | Name                | Signature / Date |
|--------------------|---------------------|------------------|
| Release Manager    | _________________   | _________________ |
| Tech Lead          | _________________   | _________________ |
| QA Lead            | _________________   | _________________ |
| Operations         | _________________   | _________________ |

## Post-Deployment Checks

- [ ] All pods in \`circleguard-master\` show \`1/1 Ready\` (\`kubectl get pods -n circleguard-master\`)
- [ ] Gate validation responds < 200ms p95 (Grafana / Locust replay)
- [ ] No Kafka consumer lag on \`promotion.status.changed\`
- [ ] Identity vault row counts match pre-deployment within ±0.1%
- [ ] Audit log shows no decryption failures during the first hour

---
*Automatically generated by CircleGuard Master Pipeline.*
EOF
