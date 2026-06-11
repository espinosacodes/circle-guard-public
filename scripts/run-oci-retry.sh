#!/usr/bin/env bash
# =============================================================================
# OCI overnight retry — keep trying to bring up the OKE A1.Flex worker pool
# until Oracle Bogotá frees capacity OR we run out of attempts.
#
# Behaviour:
#   * waits 15 min between attempts
#   * stops on first success
#   * stops after MAX_ATTEMPTS (default 48 = 12h)
#   * logs every attempt with timestamp + exit code
#   * does NOT delete anything on failure (the existing 19/20 stays intact)
#
# Run:
#   nohup bash scripts/run-oci-retry.sh > scripts/oci-retry.log 2>&1 &
#   disown
#
# Inspect:
#   tail -f scripts/oci-retry.log
# =============================================================================
set -uo pipefail

REPO="/Users/santiagoespinosa/Documents/swe5/circle-guard-public"
ENV_DIR="${REPO}/infra/terraform/envs/stage"
INTERVAL="${INTERVAL:-900}"          # 15 min
MAX_ATTEMPTS="${MAX_ATTEMPTS:-48}"    # 12 hours

cd "$ENV_DIR"

# Load OCI env (TF_VAR_* + OCI_CLI_*)
# shellcheck disable=SC1090
source "$HOME/.oci/oci.env"
export TF_VAR_oci_fingerprint="$OCI_CLI_FINGERPRINT"
export TF_VAR_oci_private_key_path="$OCI_CLI_KEY_FILE"
export TF_VAR_oci_region="$OCI_CLI_REGION"

attempt=0
echo "[$(date -u +%FT%TZ)]  OCI retry loop starting (interval=${INTERVAL}s, max=${MAX_ATTEMPTS})"

while (( attempt < MAX_ATTEMPTS )); do
  attempt=$(( attempt + 1 ))
  ts=$(date -u +%FT%TZ)
  echo ""
  echo "[$ts]  attempt ${attempt}/${MAX_ATTEMPTS}"

  # Refresh terraform state (in case another shell touched it).
  if ! terraform plan -input=false -refresh-only -no-color >/dev/null 2>&1; then
    echo "[$ts]  refresh failed — re-init"
    terraform init -input=false -no-color >/dev/null 2>&1 || true
  fi

  # Run apply non-interactively. Targeted at OKE node pool only.
  if terraform apply -input=false -auto-approve -no-color \
       -target=module.oci_oke.oci_containerengine_node_pool.workers 2>&1; then
    echo ""
    echo "[$(date -u +%FT%TZ)]  ✅  SUCCESS on attempt ${attempt}"
    echo "[$(date -u +%FT%TZ)]  Node pool created. Run \`terraform output\` for details."
    exit 0
  fi

  echo "[$(date -u +%FT%TZ)]  attempt ${attempt} failed — sleeping ${INTERVAL}s"
  sleep "$INTERVAL"
done

echo ""
echo "[$(date -u +%FT%TZ)]  💤  MAX_ATTEMPTS reached without success"
echo "[$(date -u +%FT%TZ)]  Oracle Bogotá is still out of capacity. Bonus 1 stays at 4/5."
exit 1
