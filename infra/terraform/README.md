# CircleGuard Terraform IaC

Infrastructure-as-Code for the CircleGuard platform. Provisions a GKE-based
primary stack on Google Cloud Platform and (in `stage`/`prod`) an AKS-based
secondary stack on Azure for the multi-cloud bonus.

## Layout

```
infra/terraform/
├── README.md                 # this file
├── backend/                  # one-shot bootstrap of the GCS state bucket
├── docs/
│   └── ARCHITECTURE.md       # mermaid diagrams + failover strategy
├── modules/
│   ├── gcp-network/          # VPC, subnets, Cloud NAT, firewall
│   ├── gcp-gke/              # regional GKE + node pools + workload identity
│   ├── gcp-cloudsql/         # Postgres 16, private IP, backups
│   ├── gcp-artifact-registry/# Docker repo
│   ├── gcp-iam/              # CI/CD SA + workload identity bindings
│   ├── azure-network/        # VNet + subnets
│   ├── azure-aks/            # AKS + system/user node pools, spot opt
│   └── azure-acr/            # Azure Container Registry
└── envs/
    ├── dev/                  # GCP only (cost saving)
    ├── stage/                # GCP + Azure
    └── prod/                 # GCP + Azure, HA defaults
```

## Prerequisites

1. **Terraform** `>= 1.6`.
2. **gcloud CLI** authenticated with a user that has `roles/owner`
   (or at minimum the bundle: `roles/compute.admin`, `roles/container.admin`,
   `roles/iam.serviceAccountAdmin`, `roles/cloudsql.admin`,
   `roles/artifactregistry.admin`, `roles/storage.admin`).

   ```bash
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project <YOUR_GCP_PROJECT_ID>
   ```

3. **Azure CLI** authenticated as a user with `Contributor` on the target
   subscription (only required for `stage`/`prod`).

   ```bash
   az login
   az account set --subscription <YOUR_AZURE_SUBSCRIPTION_ID>
   ```

4. **APIs enabled** in the target GCP project (Terraform will enable
   most, but the bootstrap module needs `storage.googleapis.com` to exist):

   ```bash
   gcloud services enable \
     storage.googleapis.com \
     compute.googleapis.com \
     container.googleapis.com \
     sqladmin.googleapis.com \
     artifactregistry.googleapis.com \
     iam.googleapis.com \
     servicenetworking.googleapis.com
   ```

## Step 0 — Bootstrap the remote state bucket (one time, local backend)

The GCS bucket that backs Terraform state has to exist *before* any env can
use it. The `backend/` module creates the bucket using a **local** Terraform
state file, which you keep on your laptop / in a secrets vault.

```bash
cd infra/terraform/backend
cp terraform.tfvars.example terraform.tfvars   # edit values inside
terraform init
terraform apply
```

Capture the `state_bucket_name` output — you'll paste it into each env's
`backend.tf` (or pass it via `-backend-config="bucket=..."`).

## Step 1 — Provision an environment

```bash
cd infra/terraform/envs/dev   # or stage / prod
cp terraform.tfvars.example terraform.tfvars   # fill in real values
terraform init \
  -backend-config="bucket=<state_bucket_name>" \
  -backend-config="prefix=envs/dev"
terraform plan -out tfplan
terraform apply tfplan
```

The same pattern works for `stage` and `prod`. The only difference is the
backend `prefix` and whether the env wires up the Azure modules.

## Adding a new environment

1. Copy `envs/stage/` to `envs/<new-env>/`.
2. Update `terraform.tfvars.example` with the new env's name, region, CIDRs.
3. Bump the backend prefix (`envs/<new-env>`) in `backend.tf`.
4. `terraform init && terraform plan`.

## Conventions

- Every resource is tagged / labeled with:
  - `env`           — e.g. `dev`, `stage`, `prod`
  - `project`       — always `circleguard`
  - `managed-by`    — always `terraform`
- Naming prefix is `circleguard-<env>-...`.
- `terraform.tfvars` files are **gitignored**; commit only `*.tfvars.example`.

## Cost knobs

- `gke_preemptible = true` / `aks_spot_enabled = true` cut compute by ~70%.
- `cloudsql_tier = "db-f1-micro"` keeps the dev DB under ~$10/mo.
- Set `node_count_min = 1` for dev to allow scale-to-one.
