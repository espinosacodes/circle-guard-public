# Istio Service Mesh — CircleGuard

This directory provisions the **Istio** service mesh on top of the CircleGuard
GKE clusters. Istio gives us:

* **Mutual TLS (mTLS) STRICT** between every pod in the mesh — zero-trust
  east-west traffic without changing any application code.
* **Authorization policies** so we can express "only the `auth-service` may
  call `identity-service`" declaratively, layered on top of K8s RBAC.
* **Traffic management**: canary releases, retries, timeouts, circuit
  breakers at the mesh layer, complementing the Resilience4j patterns
  inside the Spring Boot services.
* **Observability**: Kiali topology view, distributed tracing via the
  existing Jaeger install (see below).

This work covers **Bonus 2 — Service Mesh (5 %)** of the final project
and contributes to **Req 8 — Seguridad** (mTLS + AuthorizationPolicy).

---

## Prerequisites

| Tool        | Min version | Notes                                |
|-------------|-------------|--------------------------------------|
| `gcloud`    | 460+        | Authenticated against project        |
| `kubectl`   | 1.28+       | Pointed at the target GKE cluster    |
| `istioctl`  | 1.22+       | The install script will fetch it if missing |
| `helm`      | 3.13+       | Used for Kiali                       |

GCP project: `circleguard-final-92308`. Region: `us-central1`.

> The script labels three namespaces:
> `circleguard-dev`, `circleguard-stage`, `circleguard-master`. See
> [`install.sh`](./install.sh). Note: the prod-equivalent K8s namespace is
> historically named `circleguard-master` (Taller 2 legacy) even though the
> GKE cluster is `circleguard-prod-gke` — see [`docs/NAMESPACES.md`](../../../docs/NAMESPACES.md).

---

## Install

```bash
cd infra/k8s/istio
./install.sh
```

What it does (idempotently):

1. Downloads `istioctl` 1.22.x to `~/.istioctl/bin` if not present and adds
   it to `PATH` for this session.
2. Runs `istioctl install --set profile=default -y` (control plane in
   `istio-system`, ingress gateway as a `LoadBalancer`).
3. Labels each CircleGuard namespace with `istio-injection=enabled` so that
   newly created pods get the Envoy sidecar.
4. Applies the mesh-wide `PeerAuthentication` (STRICT mTLS).
5. Installs **Kiali** via the Istio sample addon manifest.
6. **Does NOT install Jaeger** — the observability stack
   (`infra/k8s/observability/jaeger/`) already provisions Jaeger in the
   `observability` namespace. Istio is configured to ship traces there.
7. Verifies that every pod in `istio-system` is `Ready`.

### Why we reuse the observability stack's Jaeger

Installing two Jaegers (one Istio sample, one Helm chart) would split
trace context, double the resource footprint, and confuse the dashboards.
The Helm-managed Jaeger in `observability` is the single source of truth:

```
Istio sidecars ──OTLP──▶ jaeger-collector.observability:4317
                                │
                                ▼
                       Jaeger UI (observability)
```

If you ever need a stand-alone Jaeger purely for Istio demo purposes, run:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/addons/jaeger.yaml
```

…but please uninstall it before merging to `master`.

---

## Verification

```bash
# control plane
kubectl get pods -n istio-system
istioctl version

# sidecar injection (every pod should now have 2/2 containers)
kubectl get pods -n circleguard-dev

# mTLS is STRICT
kubectl get peerauthentication -A
istioctl authn tls-check $(kubectl get pod -n circleguard-dev -l app=gateway-service -o jsonpath='{.items[0].metadata.name}').circleguard-dev

# Kiali — port-forward and open http://localhost:20001
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

In Kiali, switch the namespace selector to `circleguard-dev` and you should
see the full service graph (gateway → auth, dashboard, form, file,
identity, notification, promotion). Edges decorated with a **padlock** are
mTLS-encrypted.

---

## mTLS STRICT — what it means here

The [`peer-authentication-strict.yaml`](./peer-authentication-strict.yaml)
resource lives in the `istio-system` namespace and applies to the **entire
mesh** (no `selector` block). It forces:

* Every pod-to-pod call must present a valid SPIFFE identity issued by
  Istiod (the control plane is the in-cluster CA).
* Plain HTTP is rejected at the Envoy sidecar — clients without sidecars
  cannot call mesh services.
* Certificate rotation happens every 24 h automatically; no operator
  action required.

Combined with the [AuthorizationPolicies](./authorization-policies/), this
gives us **default-deny** east-west and explicit allow-lists per service —
the foundation of zero-trust networking.

---

## Canary traffic shifting

The [`virtual-services/dashboard-service-canary.yaml`](./virtual-services/dashboard-service-canary.yaml)
file demonstrates a canary release of `dashboard-service`. The mechanism:

1. **DestinationRule** declares two `subsets`: `v1` (label `version: v1`)
   and `v2` (label `version: v2`). Both subsets are backed by independent
   Deployments — see the comments in the file.
2. **VirtualService** routes `dashboard-service.circleguard-master.svc` with
   weight 90 / 10 (v1 / v2 respectively).
3. To bump the canary share, edit the `weight` fields and re-apply. There
   is no rolling restart, no DNS flip, no LB drain.

### Demo commands (also used in the video)

```bash
# 1. Apply the initial canary (90 % v1 / 10 % v2)
kubectl apply -f infra/k8s/istio/virtual-services/dashboard-service-canary.yaml

# 2. Generate load and watch the split in Kiali / Jaeger
kubectl run -n circleguard-dev curl --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s dashboard-service/health | head -c 50; echo; sleep 0.2; done'

# 3. Flip to 50/50 (edit weights then re-apply)
kubectl patch virtualservice dashboard-service -n circleguard-master --type merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"dashboard-service","subset":"v1"},"weight":50},{"destination":{"host":"dashboard-service","subset":"v2"},"weight":50}]}]}}'

# 4. Promote v2 to 100 %
kubectl patch virtualservice dashboard-service -n circleguard-master --type merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"dashboard-service","subset":"v2"},"weight":100}]}]}}'
```

---

## Circuit breakers — mesh + app layers

[`circuit-breaker-destination-rule.yaml`](./circuit-breaker-destination-rule.yaml)
configures **Envoy outlier detection** on `identity-service`:

* `connectionPool` caps concurrent TCP / HTTP/2 streams.
* `outlierDetection` ejects an upstream endpoint for 30 s after 5
  consecutive 5xx errors in a 30 s window.

This complements the application-level **Resilience4j** circuit breaker
inside each service. Why both?

| Layer        | Catches                                                | Reacts in |
|--------------|--------------------------------------------------------|-----------|
| Resilience4j | Slow / failing **downstream** that the caller knows about | ms        |
| Envoy outlier | Bad **upstream pod** (crashloop, hot replica, GC pause) | ms–sec    |

The mesh CB protects every service automatically, even the ones that
forgot a Resilience4j annotation. Resilience4j gives the developer
fine-grained, code-aware fallbacks. Use both.

---

## File index

```
infra/k8s/istio/
├── README.md                                 # this file
├── install.sh                                # idempotent installer
├── peer-authentication-strict.yaml           # mesh-wide mTLS STRICT
├── circuit-breaker-destination-rule.yaml     # identity-service outlier detection
├── authorization-policies/
│   ├── default-deny.yaml                     # deny-all baseline (prod)
│   ├── gateway-to-services.yaml              # allow gateway → backends
│   └── health-center-to-promotion.yaml       # health-center role → promotion-service
├── virtual-services/
│   ├── dashboard-service-canary.yaml         # 90/10 canary
│   └── gateway-service-retry-timeout.yaml    # retry + timeout policy
└── gateway/
    ├── istio-gateway.yaml                    # public Gateway + VirtualService (TLS)
    └── cert-manager-issuer.yaml              # letsencrypt-staging ClusterIssuer
```

---

## Security note (Req 8 — Seguridad)

The PeerAuthentication + AuthorizationPolicies in this directory are part
of the deliverables for **Req 8 (Seguridad)**, not just Bonus 2. Together
with the Chaos Mesh experiments (`infra/k8s/chaos-mesh/`) they demonstrate
defence-in-depth: identity at the network layer, plus controlled
fault-injection to prove failures are contained.
