# CircleGuard — Operations Handbook

How to bring CircleGuard up from cold, keep it running day-2, and recover
it when something goes wrong. This is the on-call engineer's first stop.

> Companion documents:
> - [`ARCHITECTURE.md`](ARCHITECTURE.md) — what the system looks like.
> - [`SECURITY.md`](SECURITY.md) — how to rotate secrets, who can do what.
> - [`OBSERVABILITY.md`](OBSERVABILITY.md) — dashboards and alerts.
> - [`CI_CD.md`](CI_CD.md) — pipeline mechanics.
> - [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) — approvals and rollback.
> - [`runbooks/`](runbooks/) — individual incident playbooks.

---

## 1. Prerequisites

The toolbox an operator needs locally:

| Tool          | Version (tested)        | Why                                              |
|---------------|-------------------------|--------------------------------------------------|
| `gcloud`      | ≥ 470.0.0               | GKE cluster auth, GCS, Artifact Registry, BQ.    |
| `az`          | ≥ 2.59.0                | AKS cluster auth, ACR.                           |
| `kubectl`     | ≥ 1.30 (matches GKE)    | All cluster ops.                                 |
| `helm`        | ≥ 3.14.0                | Observability stack, Istio, cert-manager, Chaos Mesh. |
| `terraform`   | 1.7.x (pinned)          | Infra changes.                                   |
| `istioctl`    | matches installed Istio | `analyze`, `proxy-config`.                       |
| `kubectx` / `kubens` | latest           | Quality of life when juggling 3 clusters.        |
| `jq`, `yq`    | any                     | Pipeline glue.                                   |

Authenticate once per shell:

```bash
gcloud auth login
gcloud config set project circleguard-prod-92308
az login
gcloud container clusters get-credentials circleguard-prod-gke \
  --region us-central1
az aks get-credentials --resource-group circleguard-prod-rg \
  --name circleguard-prod-aks
```

---

## 2. Cold start from zero

Run-book to bring up the whole platform on a fresh GCP project + Azure
subscription. Budget: ~90 minutes if everything cooperates.

### 2.1 Bootstrap Terraform state

```bash
cd infra/terraform/backend
terraform init
terraform apply -auto-approve   # creates the GCS state bucket + KMS key
```

This is the **one** Terraform run that uses a *local* state file; every
subsequent run uses the GCS backend created here. The bucket name lives
in `backend/outputs.tf` — note it for the env tfvars.

### 2.2 Apply dev environment

```bash
cd ../envs/dev
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

Provisions: GKE Autopilot cluster, Cloud SQL `db-f1-micro`, Artifact
Registry repo, Secret Manager + Workload Identity bindings, VPC,
Cloud NAT. Expect ~10 min for GKE to finish.

### 2.3 Apply stage and prod

```bash
cd ../stage && terraform init && terraform apply
cd ../prod  && terraform init && terraform apply
```

Stage and prod additionally provision the **Azure** side (AKS + ACR +
Azure DB for PostgreSQL replica) — see [`ARCHITECTURE.md`](ARCHITECTURE.md) §5.
Approval for the AKS apply requires the `release-managers` group; the CI
pipeline normally drives this, but a manual operator can run it locally
if they have the right IAM.

### 2.4 Install observability

```bash
cd ../../../  # back to repo root
bash infra/k8s/observability/install.sh prod
```

This script (see `infra/k8s/observability/install.sh`) installs:

1. `kube-prometheus-stack` (Prometheus + Alertmanager + Grafana).
2. Loki single-binary + Promtail DaemonSet.
3. Jaeger all-in-one (memory backend in dev, ES backend in stage/prod).
4. `ServiceMonitor` resources for every CircleGuard service.
5. `PrometheusRule` with the SLO burn-rate alerts.

Verify:

```bash
kubectl -n observability get pods           # all Ready
kubectl -n observability port-forward svc/grafana 3000:80
open http://localhost:3000                  # default admin/admin → rotate (see §3.5)
```

### 2.5 Install Istio + cert-manager

```bash
bash infra/k8s/istio/install.sh prod
```

This applies, in order:

1. cert-manager (Helm).
2. `istioctl install --set profile=default` with sidecar injection on
   the workload namespaces.
3. `PeerAuthentication` `STRICT` mesh-wide.
4. Default-deny `AuthorizationPolicy` + the per-route allow rules.
5. Public ingress `Gateway` + `Certificate` resource for
   `api.circleguard.edu`.

Verify:

```bash
istioctl analyze -A
kubectl get peerauthentication -A
kubectl get certificate -A   # should be Ready=True within ~2 min
```

### 2.6 Install Chaos Mesh

```bash
bash infra/k8s/chaos-mesh/install.sh
```

Installed only in `chaos-mesh` namespace. Experiments target only
`circleguard-dev` by RBAC (see [`CHAOS_EXPERIMENTS.md`](CHAOS_EXPERIMENTS.md)
header).

### 2.7 Deploy services

Three options, in increasing order of automation:

**A. Manual one-shot** (cold start, no CI):

```bash
kubectl apply -f k8s/master/   # for prod
kubectl -n circleguard-master rollout status deployment --all --timeout=10m
```

**B. CI-driven** (normal path):

```bash
git checkout main
git pull
# Open the latest pipeline in GitLab → click Play on deploy:prod
```

**C. Single-service hotfix**:

```bash
kubectl -n circleguard-master set image \
  deployment/circleguard-auth-service \
  auth=us-central1-docker.pkg.dev/circleguard-prod-92308/circleguard/auth:v1.4.1
```

### 2.8 Smoke test

```bash
bash scripts/smoke-test.sh prod
```

The script runs (a) `/actuator/health/readiness` for every service,
(b) one synthetic login, (c) one symptom-submission, (d) checks the
expected Kafka topic offsets advanced. Exits non-zero on any failure
and posts to Slack `#circleguard-ops`.

### 2.9 Enable FinOps CronJobs (dev only)

```bash
kubectl apply -f infra/k8s/finops/scale-down-dev.yaml
kubectl apply -f infra/k8s/finops/scale-up-dev.yaml
kubectl apply -f infra/k8s/finops/cloudsql-stop-dev.cronjob.yaml
kubectl apply -f infra/k8s/finops/pdb-stateful.yaml
bash infra/k8s/finops/billing-export-setup.sh
```

Then finish the BigQuery billing export wiring in the GCP console — see
[`COSTS.md`](COSTS.md) §3.2.

---

## 3. Day-2 operations

### 3.1 Deploy a new service version

**Happy path (CI-driven):**

1. Merge to `develop` → auto deploy to dev.
2. Cut `release/vX.Y.Z` → auto deploy to stage + run E2E + ZAP.
3. Merge release branch to `main` → pipeline pauses at `deploy:prod`.
4. Maintainer with `release-managers` access clicks **Play**.
5. `release:semantic` tags `vX.Y.Z`, generates release notes, posts to Slack.

Full flow in [`CI_CD.md`](CI_CD.md). Approval rules in
[`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) §2.

**Manual override** (CI down, must ship):

```bash
SVC=circleguard-auth-service
TAG=v1.4.2-hotfix

# Build + push directly (assumes local Docker + AR push perms)
docker build -t us-central1-docker.pkg.dev/circleguard-prod-92308/circleguard/auth:$TAG \
  services/$SVC
docker push us-central1-docker.pkg.dev/circleguard-prod-92308/circleguard/auth:$TAG

# Roll the deployment
kubectl -n circleguard-master set image deployment/$SVC auth=…:$TAG
kubectl -n circleguard-master rollout status deployment/$SVC --timeout=5m

# Record the manual change (required by audit)
gh issue create --title "MANUAL DEPLOY: $SVC@$TAG" \
  --label change-type:emergency --body "Reason: …  Authorised-by: …"
```

### 3.2 Roll back

In order of escalation:

**3.2.1 Kubernetes-level rollback (fastest, ~30 s):**

```bash
kubectl -n circleguard-master rollout history deployment/<service>
kubectl -n circleguard-master rollout undo deployment/<service>
kubectl -n circleguard-master rollout status deployment/<service> --timeout=5m
```

**3.2.2 Database-level rollback (if the bad release included a migration):**

Schema migrations are managed by Flyway with paired undo scripts. Full
procedure in [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) §3.2 — the
short version:

```bash
flyway -url=jdbc:postgresql://cloudsql-proxy:5432/circleguard_<svc> \
       -user=$DBUSER -password=$DBPASS info
flyway undo -target=<previous_version>
```

If the change was *backward-incompatible* and Flyway free-tier (no
`undo`), ship a compensating forward migration — never edit history.

**3.2.3 Istio canary revert** (if a canary VirtualService is live):

```bash
# Inspect current weights
kubectl -n circleguard-master get virtualservice dashboard-service-canary -o yaml

# Revert to 100 % stable
kubectl -n circleguard-master patch virtualservice dashboard-service-canary \
  --type merge -p '{"spec":{"http":[{"route":[{"destination":{"host":"dashboard-service","subset":"stable"},"weight":100}]}]}}'
```

The canonical canary manifest lives at
`infra/k8s/istio/virtual-services/dashboard-service-canary.yaml`.

**3.2.4 Communication after any rollback:** post the
`[ROLLBACK] …` template (see [`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md)
§3.4) to `#circleguard-ops`, pin for 24 h, open a post-mortem issue
within 24 h.

### 3.3 Scale a service

**HPA (per-deployment, fast):**

```bash
kubectl -n circleguard-master autoscale deployment/<svc> \
  --min=2 --max=10 --cpu-percent=70

# Or edit the existing HPA
kubectl -n circleguard-master edit hpa <svc>
```

HPA tuning rule of thumb: `scaleUp.stabilizationWindowSeconds: 15` (so
the autoscaler can react to spot reclamations within ~30 s — see
[`COSTS.md`](COSTS.md) §5).

**Cluster autoscaler (per-node-pool, slower):**

```bash
gcloud container clusters update circleguard-prod-gke \
  --region us-central1 \
  --enable-autoscaling --node-pool=app-pool \
  --min-nodes=2 --max-nodes=12
```

For sustained > 70 % node utilisation across both pools, add a new
node-pool of the same family rather than enlarging an existing one —
upsizing in-place would force every pod to be rescheduled.

### 3.4 Drain a node

```bash
kubectl cordon  <node>
kubectl drain   <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=120 \
  --timeout=10m
# When done with maintenance
kubectl uncordon <node>
```

PodDisruptionBudgets (`infra/k8s/finops/pdb-stateful.yaml`) protect
stateful workloads from quorum loss during drain.

### 3.5 Rotate the Grafana admin password

```bash
NEW_PW=$(openssl rand -base64 24)

# Update the secret
kubectl -n observability patch secret kube-prometheus-stack-grafana \
  --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/data/admin-password\",\"value\":\"$(echo -n $NEW_PW | base64)\"}]"

# Restart Grafana so it picks up the new env var
kubectl -n observability rollout restart deployment/kube-prometheus-stack-grafana

# Store in Secret Manager for audit
echo -n "$NEW_PW" | gcloud secrets versions add grafana-admin-pw --data-file=-
```

Cadence: rotate quarterly, or immediately after any admin off-boarding.

### 3.6 Rotate a secret in Secret Manager

```bash
SECRET=cloudsql-password-prod

# Add a new version
echo -n "$(openssl rand -base64 32)" | \
  gcloud secrets versions add $SECRET --data-file=-

# Roll the consuming deployments so they re-read on startup
for d in $(kubectl -n circleguard-master get deploy -o name); do
  kubectl -n circleguard-master rollout restart $d
done

# Disable the previous version after 24 h soak
gcloud secrets versions disable <previous-version-id> --secret=$SECRET
```

Workload Identity means **no** secret value is ever copied into a K8s
Secret — services authenticate to Secret Manager directly via Spring
Cloud GCP. See [`SECURITY.md`](SECURITY.md) §2.

### 3.7 Add a new GitLab CI variable

1. **Settings → CI/CD → Variables → Add variable.**
2. Mark **Mask** and **Protect** (so it only flows to protected branches).
3. Scope to the right environment (e.g. `production`).
4. If it is a credential, store the *truth* in Secret Manager and use the
   CI variable only for the SA-key needed to fetch it.
5. Document the variable in [`CI_CD.md`](CI_CD.md) §"Required GitLab CI/CD variables".

### 3.8 Add a new microservice

End-to-end checklist:

- [ ] Scaffold `services/circleguard-<name>-service/` with `Dockerfile`
      + `build.gradle.kts` (`bootJar` task).
- [ ] Add module to `settings.gradle.kts`.
- [ ] Add Terraform: a new Cloud SQL DB in `infra/terraform/envs/*/main.tf`
      (or extend the per-service DB module).
- [ ] Add K8s `Deployment` + `Service` to `k8s/{dev,stage,master}/services.yml`.
- [ ] Add ServiceMonitor under
      `infra/k8s/observability/servicemonitors/<name>.yaml`.
- [ ] Copy the Grafana dashboard template
      (`infra/k8s/observability/grafana-dashboards/gateway-service.json`),
      replace the service label.
- [ ] Add an Istio `AuthorizationPolicy` allow-rule in
      `infra/k8s/istio/authorization-policies/` (default-deny is already
      in place).
- [ ] Add the service name to the `parallel:matrix:` lists in:
      `.gitlab/ci/build.yml`, `package.yml`, `security.yml`, and the
      `deploy.yml` loop.
- [ ] Append a Sonar module block to `sonar-project.properties`.
- [ ] Update [`ARCHITECTURE.md`](ARCHITECTURE.md) §2 diagram + responsibility table.
- [ ] Open MR `feature/<name>-new-service` → review → merge → deploys.

---

## 4. Incident response

### 4.1 First-pass triage

```bash
# What is on fire?
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Are alerts firing?
open https://grafana.circleguard.edu/alerting/list?queryString=state:Firing

# Anything pod-level?
kubectl -n circleguard-master get pods | grep -vE 'Running|Completed'
```

### 4.2 Runbook index

Linked from every Prometheus alert via the `runbook_url` annotation:

| Alert / symptom                       | Runbook                                                    |
|---------------------------------------|------------------------------------------------------------|
| Gateway p95 latency burning SLO       | [`runbooks/gateway-slo-burn.md`](runbooks/gateway-slo-burn.md) |
| Kafka consumer-group lag > 10k        | [`runbooks/kafka-consumer-lag.md`](runbooks/kafka-consumer-lag.md) |
| Pod CrashLoopBackOff                  | [`runbooks/pod-crashloop.md`](runbooks/pod-crashloop.md)   |
| Circuit breaker stuck OPEN            | [`runbooks/gateway-slo-burn.md`](runbooks/gateway-slo-burn.md) §"Downstream dependency" |
| Cloud SQL CPU > 80 % sustained        | (TODO — open issue CG-099 to author)                        |
| Cert-manager renewal failed           | (TODO — open issue CG-100 to author)                        |

### 4.3 On-call rotation (template)

| Week    | Primary | Secondary | Sev-1 escalation                |
|---------|---------|-----------|----------------------------------|
| 1       | A       | B         | Engineering Lead → CTO          |
| 2       | B       | C         | Engineering Lead → CTO          |
| 3       | C       | A         | Engineering Lead → CTO          |

Hand-off ceremony: every Monday 09:00 UTC, 15 min — incoming primary
reads the open incidents board, the burn-rate dashboard, and the last
release-notes file.

### 4.4 Channels

- **Slack**: `#circleguard-ops` (Sev-1), `#circleguard-warnings` (Sev-2),
  `#circleguard-releases` (informational).
- **PagerDuty**: service "CircleGuard Production", policy
  `eng-oncall-circleguard`. Only `severity=critical` alerts page.
- **Status page**: `https://status.circleguard.edu` (manual update by
  incident commander).

---

## 5. Backups & restore

### 5.1 Cloud SQL backups

- **Automated daily backup**, retention 7 days, configured in the
  `gcp-cloudsql` Terraform module.
- **PITR window**: 7 days.
- **Cross-region replica**: prod Cloud SQL replicates asynchronously to
  Azure DB for PostgreSQL via logical replication (RPO ≤ 5 min).

To restore a point-in-time:

```bash
gcloud sql backups list --instance=circleguard-prod-pg
gcloud sql backups restore <BACKUP_ID> --backup-instance=circleguard-prod-pg \
  --restore-instance=circleguard-prod-pg-restore-$(date +%s)
```

The restore lands in a *new* instance — the runbook then re-points
services via `kubectl set env`. Never restore in-place into the live
instance.

### 5.2 Neo4j backups

Neo4j Aura / self-managed: daily full + hourly incremental, retention 14
days. Restore = create new cluster from snapshot + repoint services. The
graph store is **regenerable** from Kafka `form.submitted` + `audit.events`
replay, so it is the lowest-priority store to restore.

### 5.3 GCS object storage

Versioning enabled on the file-service bucket. Restoring a deleted object
is `gcloud storage cp gs://…/file#<gen> gs://…/file`. Lifecycle rule
purges non-current versions after 30 days.

### 5.4 Terraform state

GCS state bucket has versioning enabled and a 7-day lock TTL. To recover
a previous state version:

```bash
gsutil ls -a gs://circleguard-tf-state/envs/prod/default.tfstate
gsutil cp gs://circleguard-tf-state/envs/prod/default.tfstate#<gen> ./recovered.tfstate
# Inspect — then push back if needed (via terraform state push)
```

---

## 6. Disaster recovery

### 6.1 Targets

| Tier              | RPO     | RTO     |
|-------------------|---------|---------|
| Auth / gateway    | 0       | 5 min   |
| Identity vault    | 0       | 15 min  |
| Promotion + graph | ≤ 5 min | 30 min  |
| Dashboard reads   | ≤ 5 min | 60 min  |
| File storage      | 0       | 30 min  |

### 6.2 Regional GCP failover (us-central1 → us-east1)

The standard GKE / Cloud SQL HA configuration handles single-zone
failures automatically. For region-level loss:

1. Promote the Cloud SQL cross-region replica:
   `gcloud sql instances promote-replica circleguard-prod-pg-east1`.
2. `terraform apply` the prod env with `gke_region = "us-east1"` (the
   modules accept this variable).
3. Cloud DNS weighted record flips automatically when health-checks fail.

### 6.3 Cross-cloud failover (GCP → Azure)

When the entire GCP region is down (or the multi-cloud bonus DR drill):

```bash
# 1. Promote the Azure Postgres replica
az postgres flexible-server replica promote \
  --resource-group circleguard-prod-rg \
  --name circleguard-prod-pg-azure

# 2. Re-point services to the Azure DB
kubectl -n circleguard-master set env deployment --all \
  SPRING_DATASOURCE_URL=jdbc:postgresql://<azure-host>:5432/circleguard

# 3. Verify image pulls work from ACR (cross-cloud)
kubectl -n circleguard-master describe pods | grep -i 'image pull'
# If ImagePullBackOff: re-tag via 'az acr import'

# 4. Flip Cloud DNS weights to 0/100
gcloud dns record-sets update api.circleguard.edu \
  --type=A --zone=circleguard \
  --routing-policy-type=WRG --routing-policy-data='{...100% AKS IP...}'

# 5. Run smoke test against Azure
bash scripts/smoke-test.sh prod-azure
```

Target RTO 30 min. Actual time is measured during the quarterly drill —
see §6.5.

### 6.4 Multi-cloud topology summary

See [`ARCHITECTURE.md`](ARCHITECTURE.md) §5 for the diagram. Cost
trade-offs in [`COSTS.md`](COSTS.md) §1.

### 6.5 Disaster-recovery drill (quarterly)

Schedule: first business day of every quarter, 10:00–13:00 UTC.

| Step | Action                                                         | Owner                |
|------|----------------------------------------------------------------|----------------------|
| 1    | T-7 days: announce in `#circleguard-ops`, file change-ticket   | Incident commander   |
| 2    | T-0: trigger DR — pick one of (region loss / cloud loss / DB loss) | IC                |
| 3    | Execute the relevant §6.2 / §6.3 / §5.1 runbook                | On-call primary      |
| 4    | Measure: RPO (data loss seconds), RTO (downtime seconds)       | IC + observer        |
| 5    | Restore the original primary state                             | On-call primary      |
| 6    | T+1 day: post-mortem with findings, update runbook gaps        | IC                   |

Drill results are tracked in a `docs/dr-drills/` directory (to be
created on first drill). Failing to meet RPO/RTO triggers a follow-up
action item with sprint priority.

---

## 7. Capacity planning

### 7.1 Per-service baseline (steady-state, 100 RPS aggregate)

| Service       | CPU req / lim | Mem req / lim | Replicas (prod) | When to bump replicas         |
|---------------|---------------|---------------|-----------------|-------------------------------|
| gateway       | 250m / 1      | 384Mi / 768Mi | 3               | p95 latency > 400 ms sustained |
| auth          | 200m / 800m   | 384Mi / 768Mi | 2               | login p95 > 300 ms            |
| identity      | 200m / 800m   | 512Mi / 1Gi   | 2               | vault QPS > 100               |
| form          | 200m / 800m   | 384Mi / 768Mi | 2               | submit p95 > 250 ms           |
| promotion     | 500m / 2      | 768Mi / 1.5Gi | 3               | saga p95 > 30 s, lag > 5k     |
| notification  | 200m / 800m   | 384Mi / 768Mi | 2               | DLQ depth > 100               |
| dashboard     | 250m / 1      | 512Mi / 1Gi   | 2               | dashboard p95 > 500 ms        |
| file          | 100m / 500m   | 256Mi / 512Mi | 2               | upload p95 > 2 s              |

Aggregate at 100 RPS: ~5 vCPU + ~7 GiB requested. With 30 % buffer this
fits 2 × `e2-standard-4` (8 vCPU / 32 GiB each) — i.e. one full spare
node remains for spot-reclamation tolerance.

### 7.2 When to add node-pool capacity

| Signal                                                                          | Action                              |
|---------------------------------------------------------------------------------|--------------------------------------|
| Cluster autoscaler `scale_up_request` events appearing > 5×/h sustained 1 h     | Bump `max-nodes` by 25 %             |
| Node CPU > 70 % p95 across the app-pool for > 4 h                                | Add a node-pool of same shape        |
| Memory pressure events (`Evicted`/`OOMKilled`) > 3 in 1 h                        | Investigate per-service `limits` before scaling |
| `kube_node_status_condition{condition="MemoryPressure",status="true"} > 0` for > 5 min | Cordon + drain + investigate     |

### 7.3 Cost-aware capacity changes

Any node-pool resize is a *Normal* change (see
[`CHANGE_MANAGEMENT.md`](CHANGE_MANAGEMENT.md) §1). Forecast deltas
should be cross-referenced with [`COSTS.md`](COSTS.md) §2 before approval.

---

## 8. Cheat sheet

```bash
# Where am I?
kubectx; kubens; kubectl config current-context

# Quickly tail the most recent error logs across a namespace
kubectl -n circleguard-master logs -l app.kubernetes.io/part-of=circleguard \
  --tail=200 --since=15m --max-log-requests=20 | grep -iE 'error|exception|fail'

# Show top pods by CPU/mem
kubectl -n circleguard-master top pod --sort-by=cpu | head

# Forward all observability UIs at once
kubectl -n observability port-forward svc/grafana            3000:80 &
kubectl -n observability port-forward svc/prometheus-server  9090:80 &
kubectl -n observability port-forward svc/jaeger-query      16686:16686 &
kubectl -n chaos-mesh    port-forward svc/chaos-dashboard    2333:2333 &
kubectl -n istio-system  port-forward svc/kiali             20001:20001 &
```
