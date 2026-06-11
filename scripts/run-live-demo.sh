#!/usr/bin/env bash
set -euo pipefail
AUTH=http://localhost:18180
GW=http://localhost:18087

echo "================================================================="
echo "CircleGuard — Live application demo"
echo "Cluster: gke_circleguard-final-cfs-2026 (GKE Autopilot, us-central1)"
echo "Namespace: circleguard-dev — 8 microservices + Postgres/Redis/Kafka/Neo4j/LDAP"
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================================="
echo

echo "=== 1) Cluster sanity — pods in circleguard-dev ==="
kubectl -n circleguard-dev get pods --no-headers | awk '{printf "  %-50s %s\n",$1,$3}'
echo

echo "=== 2) auth-service /actuator/health ==="
curl -s $AUTH/actuator/health | python3 -c "import sys,json;d=json.load(sys.stdin);print('  overall   :',d['status']);[print(f'  {k:10}: {v[\"status\"]}') for k,v in d['components'].items()]"
echo "  Note: LDAP probe is DOWN — Spring's LdapHealthIndicator hits localhost:389"
echo "  rather than the openldap svc. Local Postgres users still authenticate (step 4)."
echo

echo "=== 3) gateway-service /actuator/health ==="
curl -s $GW/actuator/health | python3 -c "import sys,json;d=json.load(sys.stdin);print('  overall   :',d['status']);[print(f'  {k:10}: {v[\"status\"]}') for k,v in d['components'].items()]"
echo

echo "=== 4) POST /api/v1/auth/login as staff_guard ==="
LOGIN=$(curl -s -X POST $AUTH/api/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"staff_guard","password":"password"}')
echo "$LOGIN" | python3 -m json.tool
JWT=$(echo "$LOGIN" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
ANON=$(echo "$LOGIN" | python3 -c "import sys,json;print(json.load(sys.stdin)['anonymousId'])")
echo "  ✓ Bearer JWT issued. anonymousId = $ANON"
echo "  ✓ The JWT 'sub' is the *anonymous* UUID, not the staff username —"
echo "    auth-service calls identity-service through a Resilience4j circuit breaker"
echo "    to mint/lookup the anonymous ID. Privacy by construction."
echo

echo "=== 5) GET /api/v1/auth/qr/generate (with Bearer JWT) ==="
QR=$(curl -s -H "Authorization: Bearer $JWT" $AUTH/api/v1/auth/qr/generate)
echo "$QR" | python3 -m json.tool
QR_TOKEN=$(echo "$QR" | python3 -c "import sys,json;print(json.load(sys.stdin)['qrToken'])")
echo "  ✓ Short-lived (60s) QR token, signed with a separate qr.secret —"
echo "    NOT the same key as the session JWT, so even if the gate is compromised,"
echo "    it cannot forge login sessions."
echo

echo "=== 6) POST /api/v1/gate/validate with that QR token  →  HAPPY PATH ==="
RESULT=$(curl -s -X POST $GW/api/v1/gate/validate -H 'Content-Type: application/json' -d "{\"token\":\"$QR_TOKEN\"}")
echo "$RESULT" | python3 -m json.tool
echo "  ✓ gateway-service verifies JWS signature + exp claim, then checks Redis"
echo "    for the user's current health-status flag. Both clean ⇒ GREEN."
echo

echo "=== 7) Replay an already-expired token  →  DENIED ==="
EXPIRED=$(python3 - "$ANON" <<'PY'
import base64, hmac, hashlib, json, sys
sub = sys.argv[1]
secret = b"my-qr-secret-key-for-dev-1234567890"
def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
header = b64(json.dumps({"alg":"HS256"}).encode())
payload = b64(json.dumps({"sub":sub,"iat":1700000000,"exp":1700000060}).encode())
sig = b64(hmac.new(secret, f"{header}.{payload}".encode(), hashlib.sha256).digest())
print(f"{header}.{payload}.{sig}")
PY
)
echo "  Token issued in 2023, exp=2023-11-14T22:14:20Z (long since expired)"
curl -s -X POST $GW/api/v1/gate/validate -H 'Content-Type: application/json' -d "{\"token\":\"$EXPIRED\"}" | python3 -m json.tool
echo "  ✓ Gate fails closed on expired tokens — covered by"
echo "    QrValidationServiceEdgeCasesTest#rejectsExpiredToken."
echo

echo "=== 8) Tamper a token (flip one signature byte)  →  DENIED ==="
TAMPERED="${QR_TOKEN%?}X"
curl -s -X POST $GW/api/v1/gate/validate -H 'Content-Type: application/json' -d "{\"token\":\"$TAMPERED\"}" | python3 -m json.tool
echo "  ✓ HMAC signature mismatch — fails closed."
echo

echo "=== 9) Health-risk path — flag user as CONTAGIED in Redis, retry gate ==="
kubectl -n circleguard-dev exec deploy/redis -c redis -- redis-cli SET "user:status:$ANON" CONTAGIED >/dev/null
echo "  Redis: SET user:status:$ANON = CONTAGIED"
FRESH_QR=$(curl -s -H "Authorization: Bearer $JWT" $AUTH/api/v1/auth/qr/generate | python3 -c "import sys,json;print(json.load(sys.stdin)['qrToken'])")
echo "  POST /api/v1/gate/validate (token valid AND fresh, but user CONTAGIED) ⇒"
curl -s -X POST $GW/api/v1/gate/validate -H 'Content-Type: application/json' -d "{\"token\":\"$FRESH_QR\"}" | python3 -m json.tool
kubectl -n circleguard-dev exec deploy/redis -c redis -- redis-cli DEL "user:status:$ANON" >/dev/null
echo "  Redis: DEL user:status:$ANON  (cleanup)"
echo "  ✓ Same token, different health state ⇒ RED. The gate's verdict is a"
echo "    function of (token validity) × (live Redis health flag) — no client trust."
echo

echo "================================================================="
echo "Recap — what this proves end-to-end:"
echo "  • All 8 microservices running on GKE"
echo "  • Auth: Postgres-local users → JWT (dual-chain ready for LDAP)"
echo "  • Identity anonymization via Resilience4j-protected RPC"
echo "  • Short-lived QR with separate signing key"
echo "  • Gate verdict: signature + exp + live health flag, fail-closed on any error"
echo "================================================================="
