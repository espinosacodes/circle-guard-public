#!/usr/bin/env bash
# =============================================================================
# Bootstrap GCP Billing Export -> BigQuery for CircleGuard.
#
# What this does (idempotent):
#   1. Creates the BigQuery dataset `billing_export` in US multi-region.
#   2. Grants the GCP billing service account write access to the dataset.
#   3. Prints the exact console step the operator MUST do manually
#      (enabling the billing export at the billing-account level is not
#      fully scriptable via gcloud as of 2026-05).
#
# Usage:
#   ./billing-export-setup.sh
#   PROJECT_ID=other DATASET=other ./billing-export-setup.sh
#
# Prereqs: gcloud + bq CLIs authenticated as a user with
#   - roles/bigquery.admin on the project
#   - roles/billing.admin or billing.viewer on the billing account
# =============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-circleguard-final-92308}"
DATASET="${DATASET:-billing_export}"
LOCATION="${LOCATION:-US}"
BILLING_SA="cloud-billing-export@system.iam.gserviceaccount.com"

log()  { printf "\033[1;34m[billing-export]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[billing-export][warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[billing-export][err]\033[0m %s\n" "$*" >&2; exit 1; }

command -v gcloud >/dev/null 2>&1 || die "gcloud is required"
command -v bq     >/dev/null 2>&1 || die "bq is required (bundled with gcloud)"

log "Project: ${PROJECT_ID}"
log "Dataset: ${DATASET} (location=${LOCATION})"

# -----------------------------------------------------------------------------
# 1. Create dataset
# -----------------------------------------------------------------------------
if bq --project_id="${PROJECT_ID}" show --dataset "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  log "Dataset ${PROJECT_ID}:${DATASET} already exists — skipping create"
else
  log "Creating BigQuery dataset"
  bq --location="${LOCATION}" mk \
    --project_id="${PROJECT_ID}" \
    --dataset \
    --description "GCP billing export for CircleGuard FinOps" \
    "${PROJECT_ID}:${DATASET}"
fi

# -----------------------------------------------------------------------------
# 2. Grant the billing system SA write access to the dataset
# -----------------------------------------------------------------------------
log "Granting ${BILLING_SA} the BigQuery dataEditor role on ${DATASET}"
bq add-iam-policy-binding \
  --member="serviceAccount:${BILLING_SA}" \
  --role="roles/bigquery.dataEditor" \
  "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1 || \
  warn "IAM binding already present (this is fine)"

# -----------------------------------------------------------------------------
# 3. Discover billing account (best-effort) and print final step
# -----------------------------------------------------------------------------
BILLING_ACCOUNT="$(gcloud beta billing projects describe "${PROJECT_ID}" \
  --format='value(billingAccountName)' 2>/dev/null | sed 's|.*/||' || true)"

cat <<EOM

============================================================================
  ALMOST DONE.

  The "enable detailed billing export to BigQuery" toggle currently has
  to be flipped in the Cloud Console (the gcloud command is in beta and
  often partial). Open this URL:

    https://console.cloud.google.com/billing/${BILLING_ACCOUNT:-<BILLING_ACCOUNT_ID>}/export/bigquery?project=${PROJECT_ID}

  Then:
    1. Click **EDIT SETTINGS** under "Detailed usage cost".
    2. Project        = ${PROJECT_ID}
    3. Dataset name   = ${DATASET}
    4. Save. Repeat for "Standard usage cost".

  After ~24 h the following tables will appear:

    ${PROJECT_ID}.${DATASET}.gcp_billing_export_v1_<billing_account>
    ${PROJECT_ID}.${DATASET}.gcp_billing_export_resource_v1_<billing_account>

  Then run the namespace-cost query from docs/COSTS.md section 3.4.
============================================================================
EOM
