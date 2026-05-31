# Bootstrap — Terraform state bucket

This module is **run once, locally**, and creates the GCS bucket that backs
the remote state for every environment.

It intentionally uses a **local** backend (no `backend.tf`) — chicken-and-egg:
you can't store state remotely until the bucket exists.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your GCP project ID

terraform init
terraform plan
terraform apply
```

Record the `state_bucket_name` output. You will need it when running
`terraform init` in every env directory:

```bash
terraform init \
  -backend-config="bucket=$(terraform -chdir=../../backend output -raw state_bucket_name)" \
  -backend-config="prefix=envs/dev"
```

## What it provisions

- One GCS bucket, uniform bucket-level access, versioning ON, `force_destroy=false`.
- Lifecycle rules:
  - Keep only the 10 most recent versions of each state object.
  - Move objects older than 90 days to NEARLINE storage class.

## Safety

The local state file produced here (`terraform.tfstate`) is gitignored.
Back it up somewhere safe (encrypted drive / 1Password / vault) — losing it
would orphan the state bucket from Terraform's perspective.
