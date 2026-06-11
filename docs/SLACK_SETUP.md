# Slack notifications setup for CircleGuard

`.gitlab/ci/notify.yml` posts pipeline-failure and production-deploy
messages to Slack via an Incoming Webhook. This document is the
one-time setup the project owner runs to provision that webhook.

---

## 1. Create the Slack app

1. Open https://api.slack.com/apps -> **Create New App**.
2. Pick **From scratch**.
3. Name it `circleguard-ci` (or similar) and pick the workspace where
   the `#circleguard-ci` channel lives. Click **Create App**.

## 2. Enable Incoming Webhooks

1. From the app's settings page, in the left sidebar choose
   **Features -> Incoming Webhooks**.
2. Toggle **Activate Incoming Webhooks** to **On**.
3. Scroll down and click **Add New Webhook to Workspace**.
4. Choose the channel that should receive pipeline notifications
   (recommended: `#circleguard-ci`; create it first if it does not
   exist). Click **Allow**.
5. Slack returns to the Incoming Webhooks page and shows the new
   webhook URL of the form
   `https://hooks.slack.com/services/T000.../B000.../xxxx`. Copy it.

## 3. Store the webhook in GitLab

Go to **GitLab project -> Settings -> CI/CD -> Variables -> Add
variable** and configure:

| Key                  | Value                          | Flags                   |
|----------------------|--------------------------------|-------------------------|
| `SLACK_WEBHOOK_URL`  | *(URL from step 2)*            | Protect: yes, Mask: yes |

Scope = "All environments".

The `.notify_slack` template in `.gitlab/ci/notify.yml` gracefully
no-ops if `SLACK_WEBHOOK_URL` is empty, so existing pipelines keep
running while the variable is being configured.

## 4. Verify

Trigger a pipeline that is expected to fail (e.g. push a branch with
a deliberately broken unit test), or run the existing
`notify:failure` job manually from a failed pipeline. Within a few
seconds Slack should show:

> :x: *Pipeline FAILED* on `espinosacodes/circle-guard-final` -
> branch `feature/test-slack` (abc1234). [view pipeline]

For the prod-success path, the message that arrives after a green
`deploy:prod` looks like:

> :rocket: *Production deploy SUCCEEDED* on
> `espinosacodes/circle-guard-final` - `main` (abc1234).
> [view pipeline]

## 5. Channel hygiene

- Pin the message that explains what the bot is for so new joiners
  understand why the channel is noisy on red days.
- Consider muting `#circleguard-ci` for everyone but the on-call
  rotation; failures already page the same engineers via the
  PagerDuty integration documented in `docs/OBSERVABILITY.md`.
- If you ever rotate the webhook (Slack lets you regenerate it from
  the same app page), repeat step 3 with the new URL. No code change
  required.
