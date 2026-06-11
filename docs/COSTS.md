# CircleGuard — FinOps & Cost Optimisation

This is the deliverable for **Bonus 4 — FinOps (5 %)**. It documents the
cost-conscious choices baked into the infrastructure, the forecast per
environment, the billing-export pipeline, the scale-to-zero policies, and
the dashboard the team uses to track spend week-over-week.

Cross-references:

* Terraform: `infra/terraform/README.md`
* Scale-to-zero CronJobs: `infra/k8s/finops/`
* Billing-export bootstrap: `infra/k8s/finops/billing-export-setup.sh`

---

## 1. Cost-optimised choices already in the infrastructure

| Choice                                       | Where                                                       | Why it saves money |
|----------------------------------------------|-------------------------------------------------------------|--------------------|
| GKE spot / preemptible node pools (dev+stage)| `infra/terraform/envs/dev/terraform.tfvars`, `envs/stage/terraform.tfvars` (`gke_preemptible = true`) | Spot VMs are 60–91 % cheaper than on-demand. Best fit for dev/stage where 24 h max lifetime is fine. |
| Prod GKE on-demand                            | `infra/terraform/envs/prod/terraform.tfvars` (`gke_preemptible = false`) | Trade ~3× cost for SLO predictability. |
| OCI Always-Free Ampere ARM (stage+prod)       | `node_shape = "VM.Standard.A1.Flex"` in `oci-oke` module    | $0/month forever for 4 OCPU + 24 GB. Carries the multi-cloud bonus instead of Azure (AKS no longer in the active narrative). See [`MULTICLOUD_OCI.md`](MULTICLOUD_OCI.md). |
| Cloud SQL `db-f1-micro` in dev                | `cloudsql_tier = "db-f1-micro"` in dev tfvars               | Cheapest shared-core tier (~$8/mo) — fine for a single developer. |
| Single-region (`us-central1`) non-prod        | All tfvars                                                  | Avoids inter-region egress (~$0.01/GiB), keeps storage class to a single region. |
| Loki over ELK for log storage                 | `infra/k8s/observability/loki/`                             | Loki indexes labels only (not full text), so its object-store backend (`gs://…`) costs roughly **3× less** than running Elasticsearch hot-storage SSDs. |
| GCS Standard for state + logs                 | `infra/terraform/backend/`                                  | Cheaper than Nearline if accessed weekly, no early-deletion penalty. |
| GKE control-plane free tier                   | one zonal cluster per billing acct is free                  | Saves ~$73/mo on dev clusters. |
| Workload Identity (no SA keys)                | `infra/terraform/modules/gcp-iam/`                          | Indirect saving: removes the long-tail cost of secret rotation incidents. |

---

## 2. Monthly cost forecast

Numbers are **rough estimates** derived from the [GCP pricing calculator](https://cloud.google.com/products/calculator)
and the values in `infra/terraform/envs/*/terraform.tfvars`. They assume
us-central1, no egress to other clouds, and **one** GCS state bucket
amortised across all envs.

### Dev — **$30 – $60 / month**

| Component                | Spec                                              | Est. /mo |
|--------------------------|---------------------------------------------------|----------|
| GKE control plane        | zonal, **free tier**                              | $0       |
| GKE nodes                | 1–3 × `e2-standard-2` **spot** ($0.0073/vCPU·h)   | $7–22    |
| Cloud SQL Postgres       | `db-f1-micro`                                     | $8       |
| Artifact Registry        | 5 GiB                                             | $0.50    |
| Cloud NAT + egress       | < 50 GiB egress                                   | $5       |
| Logs/metrics (Loki+Prom) | GCS Standard, retention 14 d                      | $3       |
| **Total**                |                                                   | **$30–60** |

### Stage — **$110 – $150 / month**

| Component                | Spec                                              | Est. /mo |
|--------------------------|---------------------------------------------------|----------|
| GKE control plane        | regional, billed                                  | $73      |
| GKE nodes                | 1–4 × `e2-standard-2` **spot**                    | $7–30    |
| Cloud SQL Postgres       | `db-custom-1-3840`                                | $30      |
| OKE (OCI) BASIC + 1 × A1.Flex worker | Always-Free quota (2 OCPU + 12 GB Ampere) | **$0**   |
| Egress + NAT             | ~150 GiB                                          | $15      |
| Logs/metrics             | 30 d retention                                    | $6       |
| **Total**                |                                                   | **$110–150** |

### Prod — **$325 – $420 / month**

| Component                | Spec                                              | Est. /mo |
|--------------------------|---------------------------------------------------|----------|
| GKE control plane        | regional                                          | $73      |
| GKE nodes                | 2–6 × `e2-standard-4` **on-demand**               | $135–400 |
| Cloud SQL Postgres       | `db-custom-2-7680` REGIONAL HA                    | $120     |
| OKE (OCI) BASIC + 2 × A1.Flex workers | Always-Free quota (4 OCPU + 24 GB Ampere) | **$0**   |
| OCI Flexible LB          | 10 Mbps Always-Free                               | **$0**   |
| Egress + NAT             | ~500 GiB                                          | $40      |
| Logs/metrics             | 90 d retention                                    | $20      |
| **Total**                |                                                   | **$325–420** |

> **OCI cost forecast.** As long as the worker pool stays inside
> 4 OCPU / 24 GB Ampere (the Always-Free monthly quota), the entire
> secondary cloud is **$0/month**. If a future override pushes us off
> Always-Free — e.g. switching to `VM.Standard.E4.Flex` for AMD/x86
> workloads or doubling node count — the next-cheapest configuration is
> a paid OKE `BASIC_CLUSTER` (control plane still $0) plus one
> `E4.Flex` 2-OCPU node at $0.013/OCPU·h ≈ **$8/mo on a 24×7 schedule**,
> with the budget alert at $1 tripping on day 4. The detailed
> Always-Free quota and pinned shapes live in
> [`MULTICLOUD_OCI.md`](MULTICLOUD_OCI.md) §6.

> If you need a defensible single number, use the midpoints: $45 / $130 / $370.

---

## 3. Billing export → BigQuery → Looker Studio

The goal is a daily-refreshed table we can slice by GCP project, service,
and Kubernetes namespace.

### 3.1 Bootstrap (run once)

```bash
# Variables
PROJECT_ID="circleguard-final-92308"
DATASET="billing_export"
LOCATION="US"

# Create dataset
bq --location=${LOCATION} mk \
  --dataset \
  --description "GCP billing export for CircleGuard" \
  ${PROJECT_ID}:${DATASET}

# Grant the billing service the role to write into the dataset
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
bq add-iam-policy-binding \
  --member="serviceAccount:cloud-billing-export@system.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor" \
  ${PROJECT_ID}:${DATASET}
```

A turn-key version of the above lives in
[`infra/k8s/finops/billing-export-setup.sh`](../infra/k8s/finops/billing-export-setup.sh).

### 3.2 Enable the export

The detailed billing export must be enabled at the **billing account**
level. The `gcloud beta billing accounts update` flow exists but is not
fully GA — in practice you finish the wiring in the console:

> **Billing → Billing export → BigQuery export** → enable
> *Standard usage cost data* + *Detailed usage cost data*, pointing both
> at `${PROJECT_ID}:${DATASET}`.

The script prints this exact instruction at the end. After ~24 hours the
tables `gcp_billing_export_v1_<billing_account>` and
`gcp_billing_export_resource_v1_<billing_account>` appear.

### 3.3 GKE cost-allocation labels

In the Terraform GKE module (`infra/terraform/modules/gcp-gke/`) enable:

```hcl
cost_management_config {
  enabled = true
}
```

Once enabled, the resource-level export carries the labels
`goog-k8s-cluster-name`, `goog-k8s-cluster-location`, and — critically —
`goog-k8s-namespace`.

### 3.4 SQL — monthly cost per K8s namespace

```sql
SELECT
  FORMAT_TIMESTAMP('%Y-%m', usage_start_time)             AS month,
  (SELECT value FROM UNNEST(labels)
     WHERE key = 'goog-k8s-namespace')                    AS namespace,
  service.description                                     AS service,
  ROUND(SUM(cost), 2)                                     AS cost_usd
FROM   `circleguard-final-92308.billing_export.gcp_billing_export_resource_v1_*`
WHERE  _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND  EXISTS (SELECT 1 FROM UNNEST(labels) WHERE key = 'goog-k8s-namespace')
GROUP  BY month, namespace, service
ORDER  BY month DESC, cost_usd DESC;
```

### 3.5 Looker Studio

Use the public template **"GCP Billing Report Demo"**
(`https://lookerstudio.google.com/c/u/0/reporting/9012a8d2-78e7-4900-b385-95a6dabd6e51`).

Replace the data source with the BigQuery dataset above. The required
panels are listed in section **6 — Cost dashboard mockup**.

---

## 4. Scale-to-zero policies (dev only)

Dev clusters are idle from 22:00 UTC to 07:00 UTC (most of the team is in
COT, UTC-5). Scaling node pools to 0 outside business hours typically saves
~37 % of dev compute spend.

### 4.1 GKE node pool: scale down at 22:00 UTC

CronJob `infra/k8s/finops/scale-down-dev.yaml` runs `gcloud container
clusters resize` to 0 nodes on the `default-pool` of the dev cluster.

### 4.2 GKE node pool: scale up at 07:00 UTC

Counterpart `infra/k8s/finops/scale-up-dev.yaml` resizes back to 1.

### 4.3 Cloud SQL stop/start

CronJob `infra/k8s/finops/cloudsql-stop-dev.cronjob.yaml` toggles
`--activation-policy NEVER` (stop) at 22:00 UTC and `ALWAYS` (start) at
07:00 UTC for the dev instance. Stopped SQL instances bill for storage
only — roughly **$2/mo** vs $8 running.

> All three CronJobs assume a `gcloud-runner` ServiceAccount bound to a
> Google ServiceAccount with `roles/container.clusterAdmin` and
> `roles/cloudsql.admin` via Workload Identity. The annotation is shown
> inline in each manifest.

---

## 5. Spot-instance risk mitigation

Spot VMs can be reclaimed with 30 s notice. We use three controls:

1. **Pod Disruption Budgets** for stateful workloads
   (`infra/k8s/finops/pdb-stateful.yaml`): `maxUnavailable: 1` for Kafka,
   Postgres-proxy, and Redis ensures no quorum loss during spot churn.
2. **HPA + cluster-autoscaler tuned for churn**: HPA uses
   `behavior.scaleUp.policies` with a `15s` stabilization window so the
   autoscaler reacts to spot reclamations within ~30 s.
3. **`schedulerName: default-scheduler` + topology-spread constraints**
   (already on the existing `services.yml`) ensures spot reclamations
   never take out more than one replica of any given service.

Don't run **stateful prod** workloads on spot. The prod tfvars already
disables it (`gke_preemptible = false`).

---

## 6. Cost dashboard mockup (Grafana)

Data source: BigQuery dataset `billing_export`, via the official
[Grafana BigQuery plugin](https://grafana.com/grafana/plugins/grafana-bigquery-datasource/).

Recommended dashboard layout (4-5 panels — these are the screenshots the
student should capture for the report):

| Panel                                | Type              | Query gist                                           |
|--------------------------------------|-------------------|------------------------------------------------------|
| **Cost per service** (last 30 d)     | Bar chart         | `SUM(cost)` group by `service.description`           |
| **Cost per environment**             | Stacked area      | `SUM(cost)` group by `goog-k8s-namespace` over time  |
| **Cost per team / developer**        | Pie chart         | `SUM(cost)` group by label `team`                    |
| **Week-over-week trend**             | Time series       | `SUM(cost)` group by `DATE_TRUNC(week, usage_start_time)` |
| **Top 10 SKUs by cost**              | Table             | `SUM(cost) DESC LIMIT 10`                            |

A starter JSON dashboard sketch can be placed at
`infra/k8s/observability/grafana-dashboards/cost-overview.json` (out of
scope for this PR — see `Section 6` of the cost task).

---

## 7. Estimated savings table

Rough numbers, cited from official calculators. Treat as planning aids,
not guarantees.

| Lever                                    | Baseline (no opt) | With opt | Savings | Source |
|------------------------------------------|-------------------|----------|---------|--------|
| GKE spot pools (dev+stage)               | $80/mo            | $25/mo   | **~68 %** | GCP pricing calculator, e2-standard-2, us-central1 |
| OCI Ampere ARM Always-Free (stage+prod)  | $100/mo           | $0/mo    | **100 %** | OCI Always-Free tier (4 OCPU + 24 GB Ampere indefinite) |
| Scale-to-zero dev (22:00–07:00 UTC)      | $30/mo            | $19/mo   | **~37 %** | 9 h × 365 / (24 h × 365) = 0.375 |
| Loki over ELK (logs)                     | $30/mo            | $10/mo   | **~67 %** | Grafana Labs Loki vs Elasticsearch storage benchmark |
| Cloud SQL stop overnight (dev)           | $8/mo             | $2/mo    | **~75 %** | GCP Cloud SQL pricing (storage only when stopped) |
| Single-region non-prod (vs multi-region) | egress + storage  | n/a      | **~15 %** | Internal estimate from past projects |

**Aggregate effect** on the *dev* environment is ~50 % vs an unoptimised
baseline. On *prod*, with no spot and HA SQL, it's ~10 % — the rest is
SLO insurance the business pays for on purpose.

---

## Cross-references

* **Req 8 — Seguridad**: the Istio mTLS PeerAuthentication and Authorization
  Policies, plus the chaos experiments, together harden the platform.
  Cost docs are not a security control by themselves, but the BigQuery
  billing export + IAM bindings in section 3 are reviewed by the security
  team during release sign-off.
* **Terraform**: actual tfvars in `infra/terraform/envs/{dev,stage,prod}/`.
* **Observability**: dashboard JSON lives under
  `infra/k8s/observability/grafana-dashboards/`.
