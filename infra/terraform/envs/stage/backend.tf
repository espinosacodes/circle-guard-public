## =====================================================================
##  Backend — temporarily local while we wait for the new GCS bucket
##  (the previous one, `circleguard-final-92308-tfstate`, was destroyed
##  when the GCP project was deleted on 2026-06-03).
##
##  Once the teammate reprovisions GCP, restore the GCS backend with:
##    terraform init -migrate-state \
##      -backend-config="bucket=<new_bucket>" \
##      -backend-config="prefix=envs/stage"
##
##  Local state is gitignored via infra/terraform/**/terraform.tfstate*.
## =====================================================================
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Original GCS backend kept here for the future restoration step:
#
# terraform {
#   backend "gcs" {
#     # Pass bucket via:
#     #   terraform init \
#     #     -backend-config="bucket=<state_bucket_name>" \
#     #     -backend-config="prefix=envs/stage"
#     prefix = "envs/stage"
#   }
# }
