# Namespaces and environment mapping

This document explains the (slightly odd) naming convention used across the
CircleGuard infrastructure. If you are about to apply a manifest and you are
not sure whether to target `circleguard-master` or `circleguard-prod`, read
this first.

## The short answer

| Terraform env | GKE cluster name      | K8s namespace        | Branch     |
|---------------|-----------------------|----------------------|------------|
| dev           | circleguard-dev-gke   | circleguard-dev      | develop    |
| stage         | circleguard-stage-gke | circleguard-stage    | release/*  |
| prod          | circleguard-prod-gke  | circleguard-master   | main       |

The production K8s namespace is **`circleguard-master`** (not
`circleguard-prod`). The production GKE cluster is **`circleguard-prod-gke`**.
Yes, these two facts contradict each other; the rest of this doc explains why.

## Why the names disagree

In Taller 2 the GitLab pipeline used the branch name as the environment
identifier (`dev` from `develop`, `stage` from `release/*`, `master` from
`main` — which back then was still called `master`). The K8s manifests
under `k8s/dev/`, `k8s/stage/`, `k8s/master/` were generated from that
mapping, so the namespace ended up named after the branch:

  - `k8s/master/namespace.yml` -> `kind: Namespace, name: circleguard-master`

For Taller 3 the Terraform module was added with a saner convention:
`${project_prefix}-${env}-gke`. The tfvars file under
`infra/terraform/envs/prod/terraform.tfvars` sets `env = "prod"`, so the
GKE cluster is provisioned as `circleguard-prod-gke`.

Renaming the **namespace** from `master` to `prod` now would touch:

  - `k8s/master/*.yml` (all four files)
  - Every ServiceMonitor, AuthorizationPolicy, VirtualService, DestinationRule
  - Every CI/CD pipeline that does `kubectl -n circleguard-master ...`
  - Live workloads in the cluster (PVC reattachment, secret migration,
    cert-manager rebind, JWT issuer URLs hard-coded with the FQDN)

…so we keep the legacy name for backward compatibility and document the
mismatch instead. The **cluster** name can stay `circleguard-prod-gke`
because nothing inside Kubernetes references it.

## How to read a manifest

When you see a reference to:

  - `circleguard-dev`     -> dev environment, dev cluster, develop branch
  - `circleguard-stage`   -> stage environment, stage cluster, release/* branches
  - `circleguard-master`  -> **prod environment**, prod cluster, main branch
  - `circleguard-prod-gke` -> the GCP/GKE cluster object (Terraform), not a namespace
  - `env = "prod"`        -> Terraform variable; selects the prod tfvars
  - `tier: prod`          -> a workload-level Pod label (rare); unrelated to namespace

If a newly added manifest hard-codes `circleguard-prod` as a `namespace:`
field, that is almost certainly a bug — it should be `circleguard-master`.

## Migration plan: master -> prod (future)

If a future maintainer decides to rename the K8s namespace to match the
Terraform env, here is the suggested order of operations. Treat each step
as one PR + one change-management ticket.

1. **Inventory.** Run `grep -rn 'circleguard-master' .` and classify each hit
   as: namespace field, FQDN in a URL, FQDN in a JWT issuer, RBAC subject,
   PVC namespace, CronJob namespace, or doc/comment.

2. **Create the new namespace in parallel.** `kubectl create namespace
   circleguard-prod`, label it for Istio injection + PSA. Do NOT delete
   `circleguard-master` yet.

3. **Re-deploy workloads to `circleguard-prod`.** Use a fresh `Deployment`
   in the new namespace, scaled to 0. Migrate Secrets/ConfigMaps. Bring the
   new Deployment up to N replicas; cut traffic over at the Istio
   VirtualService layer (not via DNS — keeps rollback to ~30s).

4. **Migrate stateful sets.** `StatefulSet` + `PersistentVolumeClaim` cannot
   move across namespaces in place. For each one: snapshot the PVC, restore
   into a new PVC in `circleguard-prod`, point the new StatefulSet at it.
   Plan a maintenance window — read-only mode in the app for the cutover.

5. **Rewrite FQDNs.** `*.circleguard-master.svc.cluster.local` -> 
   `*.circleguard-prod.svc.cluster.local`. This includes JWT `iss`/`jwksUri`
   in the Istio RequestAuthentication, every ServiceMonitor namespaceSelector,
   and any hard-coded URL in app config (`application.yml`).

6. **Update CI/CD.** Anywhere a pipeline does `kubectl -n circleguard-master`,
   change to `circleguard-prod`. The deploy job in `k8s/deploy.sh` and any
   GitLab CI job under `.gitlab/ci/` will need a sweep.

7. **Decommission `circleguard-master`.** After 1-2 weeks of stable traffic
   on the new namespace, `kubectl delete namespace circleguard-master`.
   Keep a labeled DB snapshot for 30 days.

### Risks

- **Cross-namespace cert-manager Certificates.** The Istio gateway certificate
  lives in `istio-system`, not in the app namespace, so it is unaffected.
  But if anyone added a `Certificate` in `circleguard-master`, it must be
  re-issued.
- **In-flight Sagas.** The promotion-service uses long-running Sagas with
  state in PostgreSQL. Drain them (wait for `ACTIVE` Sagas to reach a
  terminal state) before the cutover, or replay them on the new side.
- **Kafka consumer group offsets.** They are keyed by group name, not
  namespace, so they survive — but verify with `kafka-consumer-groups.sh`.
- **HPA + PodMonitor.** These reference the namespace explicitly. Recreate
  in the new namespace; the metrics will reset.
- **Blast radius.** Plan for a 30-60 minute window with read-only mode. Do
  it during business hours of an SRE on call — not on a Friday afternoon.

Until that migration happens, the rule is simple: **K8s namespace = master,
cluster = prod, branch = main.**
