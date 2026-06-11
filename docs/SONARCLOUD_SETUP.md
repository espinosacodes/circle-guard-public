# SonarCloud setup for CircleGuard

CircleGuard uses **SonarCloud** (https://sonarcloud.io) instead of a
self-hosted SonarQube. SonarCloud is free for public projects, removes
the need to operate the Helm chart in `infra/k8s/sonarqube/`, and is
what the `sonarqube:check` job in `.gitlab/ci/quality.yml` talks to.

This document is the **one-time** onboarding for the project owner.
Once the steps below are done, every pipeline pushes analysis results
to https://sonarcloud.io/project/overview?id=espinosacodes_circle-guard-final.

---

## 1. Create the SonarCloud project

1. Open https://sonarcloud.io.
2. Click **Log in** -> **With GitLab**. Authorise the SonarCloud OAuth
   app against your GitLab account.
3. Click **+ -> Analyze new project**.
4. Pick the GitLab provider, then select
   `espinosacodes/circle-guard-final` from the list. If it does not
   appear, click **Add a GitLab account / organization** and grant
   access to the `espinosacodes` namespace first.
5. SonarCloud will propose an organization slug and project key.
   The repo is already configured (`sonar-project.properties` at root)
   with:

   - `sonar.organization=espinosacodes`
   - `sonar.projectKey=espinosacodes_circle-guard-final`

   **If SonarCloud assigns different values during onboarding,** edit
   `sonar-project.properties` and replace those two lines with the
   values shown in the SonarCloud UI. Everything else stays the same.
6. On the "Set up project for Clean as You Code" screen, pick
   **Previous version** as the new-code definition (matches how the
   GitLab MR pipeline is wired).
7. On "Choose your analysis method", pick **With GitLab CI/CD**.
   SonarCloud will display a `SONAR_TOKEN` — copy it; you'll paste it
   into GitLab in step 3.

## 2. Generate a personal token (only if step 1 did not surface one)

1. Top-right avatar -> **My Account** -> **Security**.
2. Under **Generate Tokens**, name it `circle-guard-final-ci`, leave
   the expiration default, click **Generate**.
3. Copy the token immediately (SonarCloud will not show it again).

## 3. Add the secrets to GitLab

Go to **GitLab project -> Settings -> CI/CD -> Variables** and set the
following. Replace any existing `SONAR_HOST_URL` value that points at
`sonarqube.circleguard.local`.

| Key               | Value                       | Flags                          |
|-------------------|-----------------------------|--------------------------------|
| `SONAR_HOST_URL`  | `https://sonarcloud.io`     | Protect: yes, Mask: no         |
| `SONAR_TOKEN`     | *(token from step 1 or 2)*  | Protect: yes, Mask: yes        |

Scope = "All environments" is fine for both.

## 4. Trigger a pipeline

Push any change to `develop` (or open a merge request). The
`sonarqube:check` job in the `quality` stage will:

- run `sonar-scanner` with the settings in `sonar-project.properties`,
- upload the JaCoCo XML reports produced by `test:unit`,
- wait for the Quality Gate (`-Dsonar.qualitygate.wait=true`).

If the gate fails, the job fails red. Open the SonarCloud project
overview to see the issues:
https://sonarcloud.io/project/overview?id=espinosacodes_circle-guard-final

## 5. Add the badge to the README

Once the first analysis is green, add the SonarCloud badge to the top
of `README.md`:

```markdown
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=espinosacodes_circle-guard-final&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=espinosacodes_circle-guard-final)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=espinosacodes_circle-guard-final&metric=coverage)](https://sonarcloud.io/summary/new_code?id=espinosacodes_circle-guard-final)
[![Maintainability](https://sonarcloud.io/api/project_badges/measure?project=espinosacodes_circle-guard-final&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=espinosacodes_circle-guard-final)
```

(If SonarCloud assigned a different project key in step 1, replace
`espinosacodes_circle-guard-final` in all three URLs.)

## 6. (Optional) Disable the self-hosted Helm chart

`infra/k8s/sonarqube/` is left in the repo for reference, but it is
no longer deployed. Remove its Argo CD `Application` (if it was ever
registered) or simply leave it as documentation — SonarCloud
supersedes it.
