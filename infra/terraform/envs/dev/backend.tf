terraform {
  backend "gcs" {
    # bucket is intentionally omitted — pass via -backend-config:
    #   terraform init \
    #     -backend-config="bucket=<state_bucket_name>" \
    #     -backend-config="prefix=envs/dev"
    prefix = "envs/dev"
  }
}
