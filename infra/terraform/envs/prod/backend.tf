terraform {
  backend "gcs" {
    # Pass bucket via:
    #   terraform init \
    #     -backend-config="bucket=<state_bucket_name>" \
    #     -backend-config="prefix=envs/prod"
    prefix = "envs/prod"
  }
}
