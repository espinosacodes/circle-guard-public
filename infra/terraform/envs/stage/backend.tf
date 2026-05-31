terraform {
  backend "gcs" {
    # Pass bucket via:
    #   terraform init \
    #     -backend-config="bucket=<state_bucket_name>" \
    #     -backend-config="prefix=envs/stage"
    prefix = "envs/stage"
  }
}
