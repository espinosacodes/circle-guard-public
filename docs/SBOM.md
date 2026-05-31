# Software Bill of Materials (SBOM)

This document explains how CircleGuard produces, stores, queries, and
operationalises SBOMs. Closes CG-018.

## Why we generate SBOMs

A Software Bill of Materials is a machine-readable inventory of every
component (OS package, JAR, npm module, license, hash) baked into a
container image. We need them for three concrete reasons:

1. **Zero-day response.** When a Log4Shell-class vulnerability lands at
   2 AM on a Saturday, the on-call engineer must answer
   *"which of our 8 services bundles `log4j-core` ≤ 2.16.0?"* in under
   five minutes. Without SBOMs they have to rebuild each image, install
   `mvn dependency:tree`, and grep — that's an hour-plus per service.
2. **Supply-chain transparency.** The institutional security review
   board asks for a per-release SBOM at promotion time. Generating it
   automatically removes the human bottleneck.
3. **Licence compliance.** Some campus-IT contracts forbid AGPL code
   in production images. The SPDX SBOM lets us run a one-line `jq`
   filter to flag any incoming dependency under a banned licence.

## How they're generated

The `sbom` job in `.gitlab/ci/security.yml` runs `anchore/syft` against
every pushed container image, in a parallel matrix (one shard per
service). For each image we emit three artifacts:

| File | Format | Used for |
| --- | --- | --- |
| `sbom/<svc>-<sha>.cdx.json` | CycloneDX JSON | GitLab Dependency List + automation |
| `sbom/<svc>-<sha>.spdx.json` | SPDX JSON | Licence audits |
| `sbom/<svc>-<sha>.txt` | Human table | Quick visual inspection in pipeline UI |

The CycloneDX file is also published as a `reports:cyclonedx` artifact,
which feeds the GitLab Vulnerability Report and Dependency List pages
out of the box — no extra wiring needed.

## Retention

| Tier | Location | Retention | Owner |
| --- | --- | --- | --- |
| Hot   | GitLab CI artifacts             | 90 days  | Platform team |
| Warm  | `gs://circleguard-sbom/` bucket | 2 years  | Platform team (sync via `gsutil cp` cron) |
| Cold  | Glacier-class GCS               | 7 years  | Compliance team |

The 90-day GitLab tier covers the typical incident-response window.
The 2-year warm tier covers the institutional contract requirement.
The 7-year cold tier covers HIPAA-aligned audit obligations.

## Querying SBOMs

### "Which images contain log4j ≤ 2.16.0?"

```bash
# All SBOMs of the latest release tag, locally:
gsutil -m cp 'gs://circleguard-sbom/v1.*/*.cdx.json' /tmp/sboms/

# Then ask jq for any component named log4j-core with a vulnerable version:
for f in /tmp/sboms/*.cdx.json; do
  jq -r --arg f "$f" '
    .components[]
    | select(.name == "log4j-core")
    | select(.version | test("^(1\\.|2\\.[0-9](\\.|$)|2\\.1[0-6](\\.|$))"))
    | "\($f)\t\(.name)@\(.version)"
  ' "$f"
done
```

### "What licences ship in promotion-service?"

```bash
jq -r '
  .components[]
  | [.name, .version, (.licenses[]?.license.id // "UNKNOWN")]
  | @tsv
' sbom/promotion-service-${SHA}.cdx.json \
| sort -u
```

### "Diff dependencies between two releases."

```bash
diff \
  <(jq -r '.components[] | "\(.name)@\(.version)"' sbom/gateway-${OLD}.cdx.json | sort) \
  <(jq -r '.components[] | "\(.name)@\(.version)"' sbom/gateway-${NEW}.cdx.json | sort)
```

## Incident-response playbook (the Log4Shell drill)

When the next CVSS 9.x dependency drops:

1. **Identify** the vulnerable coordinates from the CVE (e.g.
   `org.apache.logging.log4j:log4j-core` versions `< 2.17.0`).
2. **Search** all SBOMs from the last 2 years (warm tier) using the
   `jq` query above. Output is a list of `<service>@<sha>` pairs.
3. **Cross-reference** with the deployed-images TSV
   (`results/deployed-stage-images.tsv` + `results/deployed-master-*.tsv`)
   to see which of those SHAs are currently live in stage / prod.
4. **Patch + redeploy** only the affected services (typically 1-2 out
   of 8, not all 8). This turns a multi-hour all-services rebuild into
   a 20-minute targeted rebuild.
5. **Verify** the post-patch SBOM no longer lists the bad version.
6. **Record** the incident timeline in `docs/runbooks/incidents/<date>-<cve>.md`.

## Adoption status

- Generated: every CI pipeline since merging CG-018
- Consumed by GitLab Dependency List: yes (CycloneDX report)
- Cron-synced to GCS warm tier: pending (TODO: add `infra/k8s/sbom-syncer.yaml`)
- Indexed for cross-image search: pending (Grype is the candidate)

The pending items are tracked in CG-018-followups and don't block this
ticket.
