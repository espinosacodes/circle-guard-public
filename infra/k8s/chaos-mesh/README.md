# Chaos Mesh — CircleGuard

This directory installs **Chaos Mesh** and ships five chaos experiments
plus a Workflow that orchestrates them. It covers **Bonus 3 — Chaos
Engineering (5 %)** and contributes evidence for **Req 8 — Seguridad**
(controlled fault injection proves blast radii are bounded).

> **DANGER.** Chaos experiments delete pods and disrupt networks. The
> Workflow and every experiment in this repo target the `circleguard-dev`
> namespace **only**. Do **not** re-label them to `stage`/`prod` without
> explicit approval and a rollback runbook.

---

## Prerequisites

| Tool      | Min version | Why                                                |
|-----------|-------------|----------------------------------------------------|
| `helm`    | 3.13+       | We install Chaos Mesh via the Helm chart           |
| `kubectl` | 1.28+       | Apply experiments & workflows                      |

GKE clusters in `circleguard-final-92308` already have spot pools; nothing
extra is required. Note: Chaos Mesh's `chaos-daemon` runs on every node and
must mount `/var/run/containerd/containerd.sock`. This is fine on GKE
COS_CONTAINERD images (the default) — no PodSecurity tweaks are needed in
the `chaos-mesh` namespace.

---

## Install

```bash
cd infra/k8s/chaos-mesh
./install.sh
```

The script is idempotent: re-running it upgrades the chart in place. It:

1. Adds the `chaos-mesh` helm repo.
2. Creates the `chaos-mesh` namespace.
3. Installs the chart with the GKE-friendly socket path.
4. Waits for the controller-manager + chaos-daemon to be Ready.
5. Prints how to port-forward the dashboard.

After install:

```bash
kubectl -n chaos-mesh port-forward svc/chaos-dashboard 2333:2333
# open http://localhost:2333
```

The dashboard surfaces every experiment by name, the targets it picked,
and a live timeline of injections.

---

## Safety policy

| Setting                                                | Value                |
|--------------------------------------------------------|----------------------|
| Default namespace selector                             | `circleguard-dev`    |
| Forbidden namespaces                                   | `circleguard-stage`, `circleguard-master`, `istio-system`, `kube-system`, `observability`, `chaos-mesh` |
| Pod kill blast radius (per experiment)                 | 1 pod                |
| Max experiment duration                                | 60 minutes           |
| Suspend switch                                         | `kubectl -n chaos-mesh scale deploy chaos-controller-manager --replicas=0` |

A "kill switch" runbook lives in [`docs/CHAOS_EXPERIMENTS.md`](../../../docs/CHAOS_EXPERIMENTS.md#rollback).

---

## Experiments

All five live under [`experiments/`](./experiments/). The
[`workflows/full-resilience-suite.yaml`](./workflows/full-resilience-suite.yaml)
file runs them sequentially with a 5-minute cooldown between, which is
what we wire into the release pipeline.

| File                                  | Kind         | Target              | Hypothesis                                       |
|---------------------------------------|--------------|---------------------|--------------------------------------------------|
| `pod-kill-promotion.yaml`             | PodChaos     | promotion-service   | Saga compensation handles mid-workflow pod loss  |
| `network-delay-identity.yaml`         | NetworkChaos | identity-service    | Resilience4j circuit breaker opens at ≥200ms p95 |
| `cpu-stress-dashboard.yaml`           | StressChaos  | dashboard-service   | HPA scales replicas within 60s                   |
| `http-abort-notification.yaml`        | HTTPChaos    | notification-svc    | Dead-letter queue receives the aborted requests  |
| `dns-fail-kafka.yaml`                 | NetworkChaos | kafka brokers       | Consumers reconnect within 30s of partition heal |

Full hypothesis / steady-state / success-criteria details are in
[`docs/CHAOS_EXPERIMENTS.md`](../../../docs/CHAOS_EXPERIMENTS.md).

---

## Running

### Single experiment

```bash
kubectl apply -f infra/k8s/chaos-mesh/experiments/pod-kill-promotion.yaml
kubectl get podchaos -n circleguard-dev
kubectl describe podchaos pod-kill-promotion -n circleguard-dev
```

### Full resilience suite (release gate)

```bash
kubectl apply -f infra/k8s/chaos-mesh/workflows/full-resilience-suite.yaml
kubectl get workflow -n circleguard-dev
```

Watch progression in the dashboard at `http://localhost:2333/workflows`.

### Cleanup

```bash
kubectl delete -f infra/k8s/chaos-mesh/workflows/full-resilience-suite.yaml
kubectl delete -f infra/k8s/chaos-mesh/experiments/
```

---

## How to read results

1. Open Grafana (`http://localhost:3000` via port-forward from the
   observability stack).
2. Pick the **CircleGuard – Chaos Drill** dashboard (see
   `docs/CHAOS_EXPERIMENTS.md` for which panels matter per experiment).
3. For latency / circuit-breaker effects, also check Jaeger:
   `http://localhost:16686` — filter by service and time window.
4. Record findings in the results table at the bottom of
   `docs/CHAOS_EXPERIMENTS.md`.

---

## File index

```
infra/k8s/chaos-mesh/
├── README.md
├── install.sh
├── experiments/
│   ├── pod-kill-promotion.yaml
│   ├── network-delay-identity.yaml
│   ├── cpu-stress-dashboard.yaml
│   ├── http-abort-notification.yaml
│   └── dns-fail-kafka.yaml
└── workflows/
    └── full-resilience-suite.yaml
```
