# CircleGuard self-hosted SonarQube

This directory contains everything required to deploy and operate a
self-hosted SonarQube Community Edition instance that backs the
`sonarqube:check` job defined in `.gitlab/ci/quality.yml`.

The deployment is GKE-friendly: it uses the official
[`sonarqube/sonarqube`](https://artifacthub.io/packages/helm/sonarqube/sonarqube)
Helm chart, pins the embedded H2 off (production deployments must use
PostgreSQL — H2 is unsupported by Sonar for any non-evaluation use),
and reuses the existing `dev` Cloud SQL Postgres instance via a
Kubernetes `Secret`.

## Files

| File | Purpose |
| --- | --- |
| `values.yaml` | Helm values: Community edition, external Postgres, 2 Gi heap, 5 Gi PVC, ingress at `sonarqube.circleguard.local`, admin password from `Secret`. |
| `db-secret-example.yaml` | Skeleton for the `sonarqube-db` `Secret`. Copy + fill in real values; do **not** commit the populated copy. |
| `install.sh` | Idempotent installer (`helm upgrade --install`). Adds the repo, creates the namespace, applies the DB secret, installs the chart. |

## Prerequisites

- `kubectl` context pointed at the target cluster
- `helm` ≥ 3.12 in `$PATH`
- A Postgres instance reachable from the cluster (we point at the same
  Cloud SQL instance used by `circleguard-dev` so we don't pay for a
  second one — see `infra/terraform/cloudsql.tf` in the platform repo).
  Create a `sonarqube` database + role with `ALL PRIVILEGES` before you
  start.
- A `cert-manager` `ClusterIssuer` named `letsencrypt-staging` (optional
  — the chart falls back to plain HTTP if no issuer annotation matches).

## Install

```bash
# 1. Fill in the secret (NEVER commit the result):
cp db-secret-example.yaml /tmp/db-secret.yaml
$EDITOR /tmp/db-secret.yaml
kubectl create namespace sonarqube --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n sonarqube -f /tmp/db-secret.yaml

# 2. Install / upgrade the chart:
./install.sh
```

Expected runtime: ~3 min for the first install (image pull + Sonar
schema bootstrap). Subsequent `helm upgrade` runs finish in <60 s.

## Access

After the pod reports `Ready`, the UI is reachable at:

- `https://sonarqube.circleguard.local` (cluster-internal via ingress)
- `http://localhost:9000` if you `kubectl port-forward svc/sonarqube 9000:9000 -n sonarqube`

First-login credentials are pulled from the `sonarqube-admin` `Secret`
(`username=admin`, `password=<base64-decoded>`). Change them immediately
via **My Account → Security → Change password**.

## Token rotation (every 90 days)

GitLab CI authenticates via a Sonar **User Token**, not the admin
password. Tokens are owned by the `gitlab-ci` user (provision once in
the UI). Rotation procedure:

1. Log in as `admin`, switch to **Administration → Users**, confirm
   `gitlab-ci` exists and is **not** marked as Local Admin.
2. As `gitlab-ci`, go to **My Account → Security → Generate Tokens**:
   - Name: `gitlab-ci-YYYYMMDD`
   - Type: `Global Analysis Token`
   - Expires in: 90 days
3. Copy the token (you only see it once).
4. In GitLab: **Settings → CI/CD → Variables**, update `SONAR_TOKEN`
   (Masked, Protected, scope = all environments). Keep the old token
   active until the next pipeline succeeds, then revoke it in the
   Sonar UI.
5. Record the rotation in `docs/runbooks/secret-rotation.md`.

The `SONAR_HOST_URL` variable should point at the ingress DNS, e.g.
`https://sonarqube.circleguard.local`. For local development point it
at `http://localhost:9000` via the port-forward command above.

## Operational notes

- **Backups**: schema lives in Cloud SQL, so daily Cloud SQL backups
  cover Sonar history. The `/opt/sonarqube/data` PVC is ephemeral
  scratch (Elasticsearch index) and rebuilds automatically on pod
  restart.
- **Disk**: 5 Gi PVC is enough for ~50 projects of analysis history.
  Bump `persistence.size` if Elasticsearch starts evicting.
- **Heap**: 2 Gi (`-Xmx2g`) is the minimum Sonar will start on; bump to
  3 Gi if analyses for >1 M LOC start hitting OOM.
- **Quality Gate**: the bundled `Sonar way` gate is used; the CI job
  passes `-Dsonar.qualitygate.wait=true` so failures fail the pipeline.

## Uninstall

```bash
helm uninstall sonarqube -n sonarqube
kubectl delete namespace sonarqube         # also removes the Secret + PVCs
```

The Cloud SQL `sonarqube` database is **not** deleted — drop it
manually if you really mean to lose history.
