# CircleGuard CI/CD (GitLab)

This document describes the GitLab CI/CD pipeline that ports — and extends —
the legacy Jenkinsfiles (`Jenkinsfile.dev`, `Jenkinsfile.stage`,
`Jenkinsfile.master`). The Jenkinsfiles are kept in the repo as reference.

## Pipeline architecture

The pipeline is composed in `.gitlab-ci.yml` and a set of templates under
`.gitlab/ci/`:

```
.gitlab-ci.yml               Parent: stages, includes, global vars, workflow rules
.gitlab/ci/build.yml         gradle build (parallel:matrix per service)
.gitlab/ci/test.yml          unit + integration tests, JaCoCo coverage
.gitlab/ci/quality.yml       SonarQube quality gate
.gitlab/ci/security.yml      Trivy fs + image scan, SARIF artifacts
.gitlab/ci/package.yml       Kaniko -> GCP Artifact Registry
.gitlab/ci/deploy.yml        kubectl apply -> GKE dev / stage / prod
.gitlab/ci/e2e.yml           pytest tests/e2e against stage
.gitlab/ci/zap.yml           OWASP ZAP baseline scan
.gitlab/ci/release.yml       semantic-release + RELEASE_NOTES generator
.gitlab/ci/notify.yml        Slack notifications (failure + prod success)
```

### Stage flow

```
build -> test -> quality -> security -> package
                                          |
                                          +--> deploy-dev   (auto on develop)
                                          |
                                          +--> deploy-stage (auto on release/*)
                                          |       |
                                          |       +--> e2e
                                          |       +--> zap
                                          |
                                          +--> deploy-prod  (manual on main / tag)
                                                  |
                                                  +--> release (semantic-release)
                                                  +--> notify  (Slack)
```

### Monorepo optimisation

`.gitlab/ci/build.yml` declares both a `build:all` job (default branch,
release branches, tags, and any change to shared Gradle files) and a
`build:service` matrix job. The matrix is guarded by `rules:changes` so an MR
that only edits `services/circleguard-auth-service/**` rebuilds **only that
service**. Downstream stages (`package:image`, `security:image`) use
`parallel:matrix:` over the same 8 service names.

## Differences vs. the original Jenkinsfiles

| Capability                         | Jenkins                        | GitLab CI                                                 |
|------------------------------------|--------------------------------|-----------------------------------------------------------|
| Per-service builds                 | Single sequential loop         | `parallel:matrix:` + `rules:changes` (monorepo aware)     |
| Container build                    | `docker build` on the agent    | **Kaniko** (rootless, no DinD needed)                     |
| Registry                           | Local `circleguard/<svc>`      | **GCP Artifact Registry** with SA-key auth                |
| Cluster                            | Local Kind                     | **GKE** dev / stage / prod (`KUBE_CONFIG_*` vars)         |
| Code quality                       | none                           | **SonarQube** with quality-gate wait                      |
| Vulnerability scan                 | none                           | **Trivy** fs + image, SARIF + GitLab reports              |
| OWASP scan                         | none                           | **ZAP baseline** post deploy-stage                        |
| Coverage report                    | Jacoco HTML only               | **JaCoCo XML** -> Sonar + GitLab coverage badge           |
| Release notes                      | `scripts/generate-release-notes.sh` | Same script, **plus** semantic-release auto-tag       |
| Approval gate                      | `input` step                   | **Protected environment** + `when: manual`                |
| Failure notifications              | `echo`                         | **Slack webhook** (`notify:failure` on_failure)           |
| MR / Issue templates               | none                           | `.gitlab/ISSUE_TEMPLATE/`, `.gitlab/MERGE_REQUEST_TEMPLATE/` |

## Required GitLab CI/CD variables

Configure these in **Settings -> CI/CD -> Variables**. Mask + protect every
secret. Use *File* type for the GCP service-account key and *Variable* type
for everything else.

| Name                  | Type     | Scope        | What it contains                                                                                      |
|-----------------------|----------|--------------|-------------------------------------------------------------------------------------------------------|
| `SONAR_HOST_URL`      | Variable | All          | URL of your Sonar instance, e.g. `https://sonarcloud.io`.                                             |
| `SONAR_TOKEN`         | Variable (masked, protected) | All | Sonar user / project token with "Execute Analysis".                                    |
| `SLACK_WEBHOOK_URL`   | Variable (masked, protected) | All | Slack Incoming Webhook URL for `#circleguard-cicd`.                                    |
| `GCP_SA_KEY`          | File (masked, protected)     | All | JSON service-account key with `roles/artifactregistry.writer` + Trivy pull rights.     |
| `GCP_PROJECT`         | Variable                     | All | GCP project ID hosting Artifact Registry (e.g. `circleguard-prod-123456`).             |
| `GCP_AR_REGION`       | Variable                     | All | Artifact Registry region, e.g. `us-central1`.                                          |
| `KUBE_CONFIG_DEV`     | Variable (masked, protected) | dev / develop branches | base64-encoded kubeconfig pointed at GKE dev cluster.                          |
| `KUBE_CONFIG_STAGE`   | Variable (masked, protected) | release/*, main | base64-encoded kubeconfig pointed at GKE stage cluster.                              |
| `KUBE_CONFIG_PROD`    | Variable (masked, protected) | `production` environment only | base64-encoded kubeconfig pointed at GKE prod cluster.                |
| `GITLAB_RELEASE_TOKEN`| Variable (masked, protected) | main / tags | Project Access Token, `api` + `write_repository` scopes; used by semantic-release.        |

To base64-encode a kubeconfig:

```bash
base64 -w0 ~/.kube/config | pbcopy   # macOS: pipe to clipboard
```

## Required GitLab project settings

1. **Protected branches** (`Settings -> Repository -> Protected branches`):
   - `main` — push: *Maintainers*, merge: *Maintainers*, code-owner approval required.
   - `develop` — push: *Maintainers + Developers*, merge: *Developers+*.
   - `release/*` (wildcard) — push: *Maintainers*, merge: *Developers+*.
2. **Protected tags** (`Settings -> Repository -> Protected tags`):
   - `v*` — only *Maintainers* may create. semantic-release uses
     `GITLAB_RELEASE_TOKEN`, which must be issued to a Maintainer-equivalent user.
3. **Protected environment** (`Settings -> CI/CD -> Protected environments`):
   - `production` — only the `release-managers` group may *Deploy*.
     This is what makes `deploy:prod` (`when: manual`) require an authorised approver.
4. **Merge request settings**:
   - Squash on merge: *Encourage* (keeps Conventional-Commit history clean for
     semantic-release).
   - "Pipelines must succeed" + "All threads resolved" — both required.
5. **Default branch**: `main`. Set `develop` as the integration branch.
6. **CI/CD general settings**: enable *Auto-cancel redundant pipelines* and
   *Skip outdated deployment jobs*. Set timeout to 1 h.

## How to add a new service

1. Scaffold under `services/circleguard-<name>-service/` with a `Dockerfile`
   and a `build.gradle.kts` that registers `bootJar`.
2. Add the module to `settings.gradle.kts`.
3. Add the service name to the `parallel:matrix:` lists in:
   - `.gitlab/ci/build.yml` (`build:service`)
   - `.gitlab/ci/package.yml` (`package:image`)
   - `.gitlab/ci/security.yml` (`security:image`)
   - the inline `for svc in ...` loop in `.gitlab/ci/deploy.yml`
4. Append a Sonar module block to `sonar-project.properties`
   (`<name>.sonar.projectName=...`, `<name>.sonar.projectBaseDir=...`,
   and add the module key to `sonar.modules`).
5. Add a `Deployment` + `Service` block in `k8s/{dev,stage,master}/services.yml`.
6. Open an MR — the matrix expansion is automatic.

## How to trigger a production deploy

Production is **always** behind a manual gate.

1. Cut a `release/x.y.z` branch from `develop`. This auto-deploys to stage
   and runs E2E + ZAP.
2. After the release branch is green, open an MR `release/x.y.z -> main`.
3. Merge to `main`. The pipeline runs `build` -> `test` -> `quality`
   -> `security` -> `package` -> `deploy:stage` -> `e2e` -> `zap` -> stops at
   `deploy:prod` waiting for approval.
4. In the *Pipelines* UI, a Maintainer with access to the `production`
   protected environment clicks **Play** on `deploy:prod`.
5. On success, `release:semantic` automatically creates a Git tag (e.g.
   `v1.4.0`), generates `RELEASE_NOTES_v1.4.0.md`, and pushes both back to
   the repo. `notify:prod-success` posts to Slack.

To roll back, run on the prod cluster:

```bash
kubectl -n circleguard-master rollout undo deployment/<service>
```

or re-run a previous tag's pipeline and play `deploy:prod` from there.

## Local pipeline simulation

```bash
# Validate the YAML before pushing
gitlab-ci-local --file .gitlab-ci.yml --list
```

`gitlab-ci-local` (`brew install gitlab-ci-local`) executes individual jobs
in Docker, mirroring how the runner will behave.
